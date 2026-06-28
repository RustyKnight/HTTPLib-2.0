import Testing
import Foundation
@testable import HTTPLib

@Suite("HTTPClient Headers") struct HTTPClientHeaderTests {

    private let url = URL(string: "https://example.com")!

    private func makeEngine() -> (HTTPClient, MockURLProtocol.MockContext) {
        let (session, mock) = MockURLProtocol.makePair()
        return (HTTPClient(session: session), mock)
    }

    // US3-AC-01: Caller-supplied headers appear in the outbound request
    @Test func customHeadersAreForwardedInOutboundRequest() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url, headers: ["Authorization": "Bearer token", "X-Custom": "value"])
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-Custom") == "value")
    }

    // US3-AC-02: Nil headers produces no unexpected custom headers
    @Test func nilHeadersProducesNoUnexpectedHeaders() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url, headers: nil)
        let allHeaders = mock.capturedRequest?.allHTTPHeaderFields ?? [:]
        // Should not contain any caller-set custom headers
        #expect(allHeaders["Authorization"] == nil)
        #expect(allHeaders["X-Custom"] == nil)
    }

    // US3-AC-03: Library Content-Type overrides a conflicting caller-supplied Content-Type
    @Test func libraryContentTypeOverridesConflictingCallerHeader() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, body: .json(["k": "v"]), headers: ["Content-Type": "text/xml"])
        // Library wins — must be application/json, not text/xml (research Decision 6)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
}
