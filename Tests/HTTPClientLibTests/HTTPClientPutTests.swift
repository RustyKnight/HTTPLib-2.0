import Testing
import Foundation
@testable import HTTPClientLib

@Suite("HTTPClient PUT") struct HTTPClientPutTests {

    private let url = URL(string: "https://example.com")!

    private func makeEngine() -> (HTTPClient, MockURLProtocol.MockContext) {
        let (session, mock) = MockURLProtocol.makePair()
        return (HTTPClient(session: session), mock)
    }

    // MARK: - User Story 1

    @Test func putNoBodyReturnsStatusCode() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        let r = try await engine.put(url)
        #expect(r.statusCode == 200)
    }

    @Test func putNoBodySetsHTTPMethodToPUT() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.put(url)
        #expect(mock.capturedRequest?.httpMethod == "PUT")
    }

    // MARK: - User Story 2

    @Test func putTextBodySetsHTTPBodyAndContentType() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.put(url, body: .text("data"))
        #expect(mock.capturedRequest?.httpBody == Data("data".utf8))
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "text/plain; charset=utf-8")
    }

    @Test func putBinaryBodySetsHTTPBodyWithNoContentType() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.put(url, body: .binary(Data([0xFF]), contentType: "application/octet-stream"))
        #expect(mock.capturedRequest?.httpBody == Data([0xFF]))
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    }

    @Test func putJSONBodyEncodesEncodableAndSetsContentType() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.put(url, body: .json(["a": 1]))
        let bodyData = try #require(mock.capturedRequest?.httpBody)
        let decoded = try JSONDecoder().decode([String: Int].self, from: bodyData)
        #expect(decoded == ["a": 1])
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
}


