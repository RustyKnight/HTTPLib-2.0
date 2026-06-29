import Testing
import Foundation
@testable import HTTPClientLib

@Suite("HTTPClient GET") struct HTTPClientGetTests {

    private let url = URL(string: "https://example.com")!

    private func makeEngine() -> (DefaultHTTPClient, MockURLProtocol.MockContext) {
        let (session, mock) = MockURLProtocol.makePair()
        return (DefaultHTTPClient(session: session), mock)
    }

    @Test func getReturnsStatusCode() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        let r = try await engine.get(url)
        #expect(r.statusCode == 200)
    }

    @Test func getNonTwoXXStatusIsReturnedNotThrown() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 404), Data())
        let r = try await engine.get(url)
        #expect(r.statusCode == 404)
    }

    @Test func getReturnsBodyData() async throws {
        let (engine, mock) = makeEngine()
        let expected = Data("hello".utf8)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), expected)
        let r = try await engine.get(url)
        #expect(r.body == expected)
    }

    @Test func getReturnsNilBodyForEmptyResponse() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        let r = try await engine.get(url)
        #expect(r.body == nil)
    }

    // MARK: - User Story 4

    // US4-AC-01: Custom session is used for all requests
    @Test func customSessionIsUsedForAllRequests() async throws {
        let (session, mock) = MockURLProtocol.makePair()
        let engine = DefaultHTTPClient(session: session)  // custom session injected
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        // Custom session intercepted the request (not URLSession.shared)
        #expect(mock.capturedRequest != nil)
    }

    // US1-AC-1 (Feature 003): engine-level configuration timeout is applied on get
    @Test func customTimeoutAppliedViaConfiguration() async throws {
        let (session, mock) = MockURLProtocol.makePair()
        let engine = DefaultHTTPClient(
            session: session,
            configuration: DefaultHTTPClient.Configuration(timeoutInterval: 42)
        )
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.timeoutInterval == 42)
    }
}

