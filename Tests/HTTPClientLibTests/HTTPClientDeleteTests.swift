import Testing
import Foundation
@testable import HTTPClientLib

@Suite("HTTPClient DELETE") struct HTTPClientDeleteTests {

    private let url = URL(string: "https://example.com")!

    private func makeEngine() -> (HTTPClient, MockURLProtocol.MockContext) {
        let (session, mock) = MockURLProtocol.makePair()
        return (HTTPClient(session: session), mock)
    }

    // MARK: - User Story 1

    @Test func deleteNoBodyReturnsStatusCode() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        let r = try await engine.delete(url)
        #expect(r.statusCode == 200)
    }

    @Test func deleteNoBodySetsHTTPMethodToDELETE() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.delete(url)
        #expect(mock.capturedRequest?.httpMethod == "DELETE")
    }

    // MARK: - User Story 2

    @Test func deleteWithTextBodyIncludesBodyAndContentType() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.delete(url, body: .text("payload"))
        #expect(mock.capturedRequest?.httpBody == Data("payload".utf8))
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "text/plain; charset=utf-8")
    }

    @Test func deleteWithNilBodySendsNoBody() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.delete(url)  // no-body overload from US1
        #expect(mock.capturedRequest?.httpBody == nil)
    }
}


