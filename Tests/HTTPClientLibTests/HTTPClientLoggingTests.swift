import Testing
import Foundation
@testable import HTTPClientLib

@Suite("HTTPClient Logging") struct HTTPClientLoggingTests {

    private let url = URL(string: "https://example.com")!

    private final class CapturingLogger: DefaultHTTPClient.Logger, @unchecked Sendable {
        let includeHeaders: Bool
        let includeBody: Bool
        private let lock = NSLock()
        private(set) var requestMessages: [String] = []
        private(set) var responseMessages: [String] = []

        init(includeHeaders: Bool = false, includeBody: Bool = false) {
            self.includeHeaders = includeHeaders
            self.includeBody = includeBody
        }

        func log(request: String) {
            lock.withLock {
                requestMessages.append(request)
            }
        }

        func log(response: String) {
            lock.withLock {
                responseMessages.append(response)
            }
        }
    }

    private func makeEngine(
        logger: CapturingLogger
    ) -> (DefaultHTTPClient, MockURLProtocol.MockContext, CapturingLogger) {
        let (session, mock) = MockURLProtocol.makePair()
        return (DefaultHTTPClient(session: session, logger: logger), mock, logger)
    }

    @Test func logsMethodAndURLByDefault() async throws {
        let logger = CapturingLogger()
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url)

        #expect(capturingLogger.requestMessages == ["[GET ] https://example.com"])
        #expect(capturingLogger.responseMessages == ["[GET ] 200 https://example.com"])
    }

    @Test func includesHeadersWhenRequested() async throws {
        let logger = CapturingLogger(includeHeaders: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url, headers: ["B": "2", "A": "1"])

        #expect(capturingLogger.requestMessages == [
            "[GET ] https://example.com\nA: 1\nB: 2"
        ])
    }

    @Test func includesTextBodyAndMarksBinaryBodiesAsBinaryData() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.post(url, body: .text("hello"))

        #expect(capturingLogger.requestMessages == [
            "[POST] https://example.com\nBody: hello"
        ])

        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, body: .binary(Data([0xFF, 0xFE]), contentType: "application/octet-stream"))

        #expect(capturingLogger.requestMessages == [
            "[POST] https://example.com\nBody: hello",
            "[POST] https://example.com\nBody: [binary data]"
        ])
    }

    @Test func logsResponseWithStatusCode() async throws {
        let logger = CapturingLogger()
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 404), Data())

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages == ["[GET ] 404 https://example.com"])
    }

    @Test func logsResponseBodyAsText() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        
        let responseData = "Hello, World!".data(using: .utf8)!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/plain"])!
        mock.stub = (response, responseData)

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages == ["[GET ] 200 https://example.com\nBody: Hello, World!"])
    }

    @Test func logsResponseBodyAsBinaryData() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        
        let responseData = Data([0xFF, 0xFE])
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/octet-stream"])!
        mock.stub = (response, responseData)

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages == ["[GET ] 200 https://example.com\nBody: [binary data]"])
    }

    @Test func logsResponseWithHeadersWhenRequested() async throws {
        let logger = CapturingLogger(includeHeaders: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [
            "Content-Type": "application/json",
            "Accept-Language": "en-US"
        ])!
        mock.stub = (response, Data())

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages == [
            "[GET ] 200 https://example.com\nAccept-Language: en-US\nContent-Type: application/json"
        ])
    }

    @Test func logsResponseWithJSONBodyAsText() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        
        let jsonData = """
        {"name": "Test", "value": 123}
        """.data(using: .utf8)!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        mock.stub = (response, jsonData)

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages == [
            "[GET ] 200 https://example.com\nBody: {\"name\": \"Test\", \"value\": 123}"
        ])
    }

    @Test func logsResponseWithNoBodyWhenIncludeBodyIsTrue() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        
        let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
        mock.stub = (response, Data())

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages == ["[GET ] 204 https://example.com\nBody: [no data]"])
    }
}
