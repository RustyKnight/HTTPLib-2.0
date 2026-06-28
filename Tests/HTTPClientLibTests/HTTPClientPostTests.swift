import Testing
import Foundation
@testable import HTTPClientLib

@Suite("HTTPClient POST") struct HTTPClientPostTests {

    private let url = URL(string: "https://example.com")!

    private func makeEngine() -> (HTTPClient, MockURLProtocol.MockContext) {
        let (session, mock) = MockURLProtocol.makePair()
        return (HTTPClient(session: session), mock)
    }

    // MARK: - User Story 1

    @Test func postNoBodyReturnsStatusCode() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 201), Data())
        let r = try await engine.post(url)
        #expect(r.statusCode == 201)
    }

    @Test func postNoBodySetsHTTPMethodToPOST() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url)
        #expect(mock.capturedRequest?.httpMethod == "POST")
    }

    // MARK: - User Story 2

    @Test func postTextBodySetsHTTPBodyAndContentType() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, body: .text("hello"))
        #expect(mock.capturedRequest?.httpBody == Data("hello".utf8))
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "text/plain; charset=utf-8")
    }

    @Test func postBinaryBodySetsHTTPBodyWithNoContentType() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, body: .binary(Data([0x01, 0x02]), contentType: "application/octet-stream"))
        #expect(mock.capturedRequest?.httpBody == Data([0x01, 0x02]))
        // Library must NOT set Content-Type for binary (data-model.md §RequestBody)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    }

    @Test func postJSONBodyEncodesEncodableAndSetsContentType() async throws {
        struct Payload: Encodable { let key: String }
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, body: .json(Payload(key: "val")))
        let bodyData = try #require(mock.capturedRequest?.httpBody)
        let decoded = try JSONDecoder().decode([String: String].self, from: bodyData)
        #expect(decoded == ["key": "val"])
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func postJSONBodyThrowsJsonEncodingFailedBeforeNetworkActivity() async throws {
        struct FailEncoder: Encodable {
            func encode(to encoder: any Encoder) throws {
                throw URLError(.unknown)
            }
        }
        let (engine, mock) = makeEngine()
        // No stub needed — encoding should fail before any network activity
        do {
            _ = try await engine.post(url, body: .json(FailEncoder()))
            Issue.record("Expected HTTPClientError.jsonEncodingFailed to be thrown")
        } catch HTTPClientError.jsonEncodingFailed {
            // PASS — correct error was thrown
        }
        // Nothing should have reached the session
        #expect(mock.capturedRequest == nil)
    }

    @Test func postWithBodySetsHTTPMethodToPOST() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, body: .text("x"))
        #expect(mock.capturedRequest?.httpMethod == "POST")
    }

    // MARK: - User Story 4

    // US1-AC-1 (Feature 003): per-request headers applied to POST request (migrated from configurator test)
    @Test func perRequestHeadersAppliedToPostRequest() async throws {
        let (session, mock) = MockURLProtocol.makePair()
        let engine = HTTPClient(session: session)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, headers: ["X-Injected": "injected-value"])
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-Injected") == "injected-value")
    }
}
