import Testing
import Foundation
@testable import HTTPLib

@Suite("HTTPEngine Default Headers") struct HTTPEngineDefaultHeaderTests {

    private let url = URL(string: "https://example.com")!

    // Shared helper: builds an engine + mock session pair with optional default headers.
    private func makeEngine(
        defaultHeaders: [String: String]? = nil
    ) -> (HTTPEngine, MockURLProtocol.MockContext) {
        let (session, mock) = MockURLProtocol.makePair()
        let engine = HTTPEngine(session: session, defaultHeaders: defaultHeaders)
        return (engine, mock)
    }

    // MARK: - US1-AC-1: Default headers applied to GET

    @Test func defaultHeadersAppliedToGetRequest() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["X-API-Key": "abc123"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == "abc123")
    }

    // MARK: - US1-AC-2: Default headers applied to POST, PUT, DELETE

    @Test func defaultHeadersAppliedToPostRequest() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["X-API-Key": "abc123"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == "abc123")
    }

    @Test func defaultHeadersAppliedToPutRequest() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["X-API-Key": "abc123"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.put(url)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == "abc123")
    }

    @Test func defaultHeadersAppliedToDeleteRequest() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["X-API-Key": "abc123"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.delete(url)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == "abc123")
    }

    // MARK: - US1-AC-3: Empty default headers adds no custom headers

    @Test func emptyDefaultHeadersAddsNoHeaders() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: [:])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == nil)
    }

    // MARK: - US1-AC-4: nil defaultHeaders matches pre-feature baseline

    @Test func nilDefaultHeadersMatchesBaseline() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: nil)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == nil)
    }

    // MARK: - US1-AC-2 + FR-002: Default headers on multipart POST

    @Test func defaultHeadersOnMultipartPostRequest() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["X-API-Key": "abc123"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        let item = FormItem.property(name: "field", value: "value")
        _ = try await engine.post(url, formItems: [item])
        // Default header present
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == "abc123")
        // Library Content-Type still set for multipart (FR-002)
        let contentType = mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") ?? ""
        #expect(contentType.hasPrefix("multipart/form-data"))
    }

    // MARK: - US2-AC-1: Both default and per-request headers present (non-overlapping keys)

    @Test func defaultAndPerRequestHeadersBothPresent() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["A": "1"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url, headers: ["B": "2"])
        #expect(mock.capturedRequest?.allHTTPHeaderFields?["A"] == "1")
        #expect(mock.capturedRequest?.allHTTPHeaderFields?["B"] == "2")
    }

    // MARK: - US2-AC-2: Default headers present when no per-request headers

    @Test func defaultHeadersPresentWhenNoPerRequestHeaders() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["A": "1"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url, headers: nil)
        #expect(mock.capturedRequest?.allHTTPHeaderFields?["A"] == "1")
        #expect(mock.capturedRequest?.allHTTPHeaderFields?["B"] == nil)
    }

    // MARK: - US2-AC-3: Only per-request headers when no defaults (pre-feature baseline)

    @Test func perRequestHeadersOnlyWhenNoDefaults() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: nil)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url, headers: ["B": "2"])
        #expect(mock.capturedRequest?.allHTTPHeaderFields?["B"] == "2")
        #expect(mock.capturedRequest?.allHTTPHeaderFields?["A"] == nil)
    }

    // MARK: - US3-AC-1: Per-request overrides default on key conflict

    @Test func perRequestOverridesDefaultOnConflict() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["Authorization": "default-token"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url, headers: ["Authorization": "scoped-token"])
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "scoped-token")
    }

    // MARK: - US3-AC-2: Stored default unchanged after conflicting request (immutability, FR-007)

    @Test func storedDefaultUnchangedAfterConflictingRequest() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["Authorization": "default-token"])

        // First call: per-request overrides the default
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url, headers: ["Authorization": "scoped-token"])
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "scoped-token")

        // Second call on the same engine instance: no per-request Authorization — default must still be present
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "default-token")
    }

    // MARK: - US3-AC-3: Case-insensitive conflict resolution (Foundation URLRequest.setValue contract)

    @Test func caseInsensitiveConflictResolution() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["content-type": "text/plain"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url, headers: ["Content-Type": "application/json"])
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    // MARK: - Edge case FR-005: Library Content-Type overrides default Content-Type

    @Test func libraryContentTypeOverridesDefaultHeader() async throws {
        struct Payload: Encodable { let x: Int }
        let (engine, mock) = makeEngine(defaultHeaders: ["Content-Type": "text/xml"])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, body: .json(Payload(x: 1)))
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    // MARK: - Edge case A-06: Empty-value default header is transmitted

    @Test func emptyValueDefaultHeaderIsTransmitted() async throws {
        let (engine, mock) = makeEngine(defaultHeaders: ["X-Custom": ""])
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.allHTTPHeaderFields?["X-Custom"] == "")
    }
}
