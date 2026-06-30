import Testing
import Foundation
@testable import HTTPClientLib

@Suite("HTTPClient Logging") struct HTTPClientLoggingTests {

    private let url = URL(string: "https://example.com")!

    private final class CapturingLogger: DefaultHTTPClient.Logger, @unchecked Sendable {
        let includeHeaders: Bool
        let includeBody: Bool
        private let lock = NSLock()
        private(set) var requestMessages: [DefaultHTTPClient.HTTPRequestLogMessage] = []
        private(set) var responseMessages: [DefaultHTTPClient.HTTPResponseLogMessage] = []

        init(includeHeaders: Bool = false, includeBody: Bool = false) {
            self.includeHeaders = includeHeaders
            self.includeBody = includeBody
        }

        func log(request: DefaultHTTPClient.HTTPRequestLogMessage) {
            lock.withLock {
                requestMessages.append(request)
            }
        }

        func log(response: DefaultHTTPClient.HTTPResponseLogMessage) {
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

    /// Formats a request message as it would be displayed in logs
    private func formatRequest(_ message: DefaultHTTPClient.HTTPRequestLogMessage) -> String {
        var lines: [String] = ["[\(message.method)] \(message.url)"]
        if includeHeaders(for: message) {
            lines.append(contentsOf: message.headers.sortedHeaderLines)
        }
        if includeBody(for: message) {
            let bodyLine = message.body ?? "[no data]"
            lines.append("Body: \(bodyLine)")
        }
        return lines.joined(separator: "\n")
    }

    /// Formats a response message as it would be displayed in logs
    private func formatResponse(_ message: DefaultHTTPClient.HTTPResponseLogMessage) -> String {
        var lines: [String] = ["[\(message.method)] \(message.statusCode) \(message.url)"]
        if includeHeaders(for: message) {
            lines.append(contentsOf: message.headers.sortedHeaderLines)
        }
        if includeBody(for: message) {
            let bodyLine = message.body ?? "[no data]"
            lines.append("Body: \(bodyLine)")
        }
        return lines.joined(separator: "\n")
    }

    /// Returns true if the logger should include headers for this message
    private func includeHeaders(for message: DefaultHTTPClient.HTTPRequestLogMessage) -> Bool {
        // For now, always check headers if they're present
        // The logger's includeHeaders is checked during logging, not during formatting
        return !message.headers.isEmpty
    }

    /// Returns true if the logger should include headers for this message
    private func includeHeaders(for message: DefaultHTTPClient.HTTPResponseLogMessage) -> Bool {
        return !message.headers.isEmpty
    }

    /// Returns true if the logger should include body for this message
    private func includeBody(for message: DefaultHTTPClient.HTTPRequestLogMessage) -> Bool {
        return message.body != nil
    }

    /// Returns true if the logger should include body for this message
    private func includeBody(for message: DefaultHTTPClient.HTTPResponseLogMessage) -> Bool {
        return message.body != nil
    }

    @Test func logsMethodAndURLByDefault() async throws {
        let logger = CapturingLogger()
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url)

        #expect(capturingLogger.requestMessages.count == 1)
        #expect(capturingLogger.requestMessages[0].url == "https://example.com")
        #expect(capturingLogger.requestMessages[0].method == "GET")
        #expect(capturingLogger.requestMessages[0].headers.isEmpty)
        #expect(capturingLogger.requestMessages[0].body == nil)

        #expect(capturingLogger.responseMessages.count == 1)
        #expect(capturingLogger.responseMessages[0].url == "https://example.com")
        #expect(capturingLogger.responseMessages[0].method == "GET")
        #expect(capturingLogger.responseMessages[0].statusCode == 200)
        #expect(capturingLogger.responseMessages[0].headers.isEmpty)
        #expect(capturingLogger.responseMessages[0].body == nil)
    }

    @Test func includesHeadersWhenRequested() async throws {
        let logger = CapturingLogger(includeHeaders: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url, headers: ["B": "2", "A": "1"])

        #expect(capturingLogger.requestMessages.count == 1)
        let requestMsg = capturingLogger.requestMessages[0]
        #expect(requestMsg.url == "https://example.com")
        #expect(requestMsg.method == "GET")
        #expect(requestMsg.headers == ["B": "2", "A": "1"])
        #expect(requestMsg.body == nil)
    }

    @Test func includesTextBodyAndMarksBinaryBodiesAsBinaryData() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.post(url, body: .text("hello"))

        #expect(capturingLogger.requestMessages.count == 1)
        let requestMsg = capturingLogger.requestMessages[0]
        #expect(requestMsg.url == "https://example.com")
        #expect(requestMsg.method == "POST")
        #expect(requestMsg.body == "hello")

        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, body: .binary(Data([0xFF, 0xFE]), contentType: "application/octet-stream"))

        #expect(capturingLogger.requestMessages.count == 2)
        let binaryMsg = capturingLogger.requestMessages[1]
        #expect(binaryMsg.url == "https://example.com")
        #expect(binaryMsg.method == "POST")
        #expect(binaryMsg.body == "[binary data]")
    }

    @Test func logsResponseWithStatusCode() async throws {
        let logger = CapturingLogger()
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 404), Data())

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages.count == 1)
        let responseMsg = capturingLogger.responseMessages[0]
        #expect(responseMsg.url == "https://example.com")
        #expect(responseMsg.method == "GET")
        #expect(responseMsg.statusCode == 404)
        #expect(responseMsg.body == nil)
    }

    @Test func logsResponseBodyAsText() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        
        let responseData = "Hello, World!".data(using: .utf8)!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/plain"])!
        mock.stub = (response, responseData)

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages.count == 1)
        let responseMsg = capturingLogger.responseMessages[0]
        #expect(responseMsg.url == "https://example.com")
        #expect(responseMsg.method == "GET")
        #expect(responseMsg.statusCode == 200)
        #expect(responseMsg.body == "Hello, World!")
    }

    @Test func logsResponseBodyAsBinaryData() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        
        let responseData = Data([0xFF, 0xFE])
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/octet-stream"])!
        mock.stub = (response, responseData)

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages.count == 1)
        let responseMsg = capturingLogger.responseMessages[0]
        #expect(responseMsg.body == "[binary data]")
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

        #expect(capturingLogger.responseMessages.count == 1)
        let responseMsg = capturingLogger.responseMessages[0]
        #expect(responseMsg.url == "https://example.com")
        #expect(responseMsg.method == "GET")
        #expect(responseMsg.statusCode == 200)
        #expect(responseMsg.headers == ["Content-Type": "application/json", "Accept-Language": "en-US"])
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

        #expect(capturingLogger.responseMessages.count == 1)
        let responseMsg = capturingLogger.responseMessages[0]
        #expect(responseMsg.body == "{\"name\": \"Test\", \"value\": 123}")
    }

    @Test func logsResponseWithNoBodyWhenIncludeBodyIsTrue() async throws {
        let logger = CapturingLogger(includeBody: true)
        let (engine, mock, capturingLogger) = makeEngine(logger: logger)
        
        let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
        mock.stub = (response, Data())

        _ = try await engine.get(url)

        #expect(capturingLogger.responseMessages.count == 1)
        let responseMsg = capturingLogger.responseMessages[0]
        #expect(responseMsg.body == nil)
    }
}

extension Dictionary where Key == String, Value == String {
    /// Returns HTTP headers formatted as sorted lines for logging
    var sortedHeaderLines: [String] {
        sorted { lhs, rhs in
            let lhsKey = lhs.key.lowercased()
            let rhsKey = rhs.key.lowercased()
            if lhsKey == rhsKey {
                return lhs.value < rhs.value
            }
            return lhsKey < rhsKey
        }
        .map { "\($0.key): \($0.value)" }
    }
}
