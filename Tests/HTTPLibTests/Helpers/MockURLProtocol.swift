import Foundation
import Testing
@testable import HTTPLib

final class MockURLProtocol: URLProtocol {

    // The header key used to identify which session a request belongs to.
    // Embedded in URLSessionConfiguration.httpAdditionalHeaders by makePair().
    static let sessionIDHeaderKey = "X-MockURLProtocol-SessionID"

    // Protects per-session state from concurrent access (test threads + URLSession callbacks)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _stubs: [String: (response: HTTPURLResponse, data: Data)] = [:]
    nonisolated(unsafe) private static var _capturedRequests: [String: URLRequest] = [:]

    // Thread-safe accessors
    private static func stub(for sessionID: String) -> (response: HTTPURLResponse, data: Data)? {
        lock.withLock { _stubs[sessionID] }
    }

    fileprivate static func setStub(_ stub: (HTTPURLResponse, Data)?, for sessionID: String) {
        lock.withLock {
            if let s = stub { _stubs[sessionID] = s } else { _stubs.removeValue(forKey: sessionID) }
        }
    }

    private static func setCapturedRequest(_ request: URLRequest, for sessionID: String) {
        lock.withLock { _capturedRequests[sessionID] = request }
    }

    fileprivate static func capturedRequest(for sessionID: String) -> URLRequest? {
        lock.withLock { _capturedRequests[sessionID] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let sessionID = request.value(forHTTPHeaderField: MockURLProtocol.sessionIDHeaderKey) ?? ""

        // URLSession converts httpBody to httpBodyStream before invoking URLProtocol.
        // Reconstruct httpBody from the stream so tests can assert on httpBody directly.
        var capturedReq = request
        if capturedReq.httpBody == nil, let stream = capturedReq.httpBodyStream {
            var bodyData = Data()
            stream.open()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate(); stream.close() }
            while stream.hasBytesAvailable {
                let bytesRead = stream.read(buffer, maxLength: bufferSize)
                guard bytesRead > 0 else { break }
                bodyData.append(buffer, count: bytesRead)
            }
            capturedReq.httpBody = bodyData.isEmpty ? nil : bodyData
        }
        MockURLProtocol.setCapturedRequest(capturedReq, for: sessionID)

        if let stub = MockURLProtocol.stub(for: sessionID) {
            client?.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
        }
    }

    override func stopLoading() {}

    // Creates an isolated URLSession + MockContext pair.
    // Each call produces a unique session ID so suites can run concurrently without conflict.
    static func makePair() -> (session: URLSession, mock: MockContext) {
        let id = UUID().uuidString
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.httpAdditionalHeaders = [sessionIDHeaderKey: id]
        let session = URLSession(configuration: config)
        return (session, MockContext(sessionID: id))
    }

    // Convenience builder for stubbed HTTPURLResponse values.
    // Force-unwrap is acceptable in test helpers (never in Sources/).
    static func makeResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    // Clears all per-session state (useful for full reset between test runs).
    static func reset() {
        lock.withLock {
            _stubs.removeAll()
            _capturedRequests.removeAll()
        }
    }

    // MARK: - MockContext

    /// Provides scoped access to stub and captured request for a specific isolated session.
    struct MockContext {
        let sessionID: String

        /// Set before making a request to configure the canned response.
        var stub: (response: HTTPURLResponse, data: Data)? {
            get { MockURLProtocol.stub(for: sessionID) }
            nonmutating set { MockURLProtocol.setStub(newValue.map { ($0.response, $0.data) }, for: sessionID) }
        }

        /// Read after a request to inspect what was captured by the URL loading system.
        var capturedRequest: URLRequest? {
            MockURLProtocol.capturedRequest(for: sessionID)
        }
    }
}


