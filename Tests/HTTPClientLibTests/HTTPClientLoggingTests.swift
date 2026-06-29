import Testing
import Foundation
@testable import HTTPClientLib

@Suite("HTTPClient Logging") struct HTTPClientLoggingTests {

    private let url = URL(string: "https://example.com")!

    private final class CapturingLogger: HTTPClient.Logger, @unchecked Sendable {
        let includeHeaders: Bool
        let includeBody: Bool
        private let lock = NSLock()
        private(set) var messages: [String] = []

        init(includeHeaders: Bool = false, includeBody: Bool = false) {
            self.includeHeaders = includeHeaders
            self.includeBody = includeBody
        }

        func log(_ message: String) {
            lock.withLock {
                messages.append(message)
            }
        }
    }

    private func makeEngine(
        logger: CapturingLogger
    ) -> (HTTPClient, MockURLProtocol.MockContext, CapturingLogger) {
        let (session, mock) = MockURLProtocol.makePair()
        return (HTTPClient(session: session, logger: logger), mock, logger)
    }

    @Test func logsMethodAndURLByDefault() async throws {
        let logger = CapturingLogger()
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url)

        #expect(capturingLogger.messages == ["[GET ] https://example.com"])
    }

    @Test func includesHeadersWhenRequested() async throws {
        let logger = CapturingLogger(includeHeaders: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url, headers: ["B": "2", "A": "1"])

        #expect(capturingLogger.messages == [
            "[GET ] https://example.com\nA: 1\nB: 2"
        ])
    }

    @Test func includesTextBodyAndKeepsBinaryBodiesAsBase64() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.post(url, body: .text("hello"))

        #expect(capturingLogger.messages == [
            "[POST] https://example.com\nBody: hello"
        ])

        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, body: .binary(Data([0xFF, 0xFE]), contentType: "application/octet-stream"))

        #expect(capturingLogger.messages == [
            "[POST] https://example.com\nBody: hello",
            "[POST] https://example.com\nBody: base64://4="
        ])
    }
}
