import Testing
import Foundation
@testable import HTTPLib

@Suite("HTTPEngine Multipart POST") struct HTTPEngineMultipartTests {

    private let url = URL(string: "https://example.com")!

    private func makeEngine() -> (HTTPEngine, MockURLProtocol.MockContext) {
        let (session, mock) = MockURLProtocol.makePair()
        return (HTTPEngine(session: session), mock)
    }

    // FR-020: empty formItems throws before network activity
    @Test func emptyFormItemsThrowsBeforeNetworkActivity() async throws {
        let (engine, mock) = makeEngine()
        // No stub needed — should throw before any dispatch
        do {
            _ = try await engine.post(url, formItems: [])
            Issue.record("Expected HTTPEngineError.emptyFormItems")
        } catch HTTPEngineError.emptyFormItems {
            // PASS
        }
        #expect(mock.capturedRequest == nil)
    }

    // FR-021: empty item name throws before network activity
    @Test func emptyItemNameThrowsBeforeNetworkActivity() async throws {
        let (engine, mock) = makeEngine()
        do {
            _ = try await engine.post(url, formItems: [FormItem.property(name: "", value: "x")])
            Issue.record("Expected HTTPEngineError.emptyFormItemName")
        } catch HTTPEngineError.emptyFormItemName {
            // PASS
        }
        #expect(mock.capturedRequest == nil)
    }

    // FR-018: valid multipart call sets correct Content-Type header
    @Test func validMultipartRequestSetsMultipartContentTypeHeader() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url, formItems: [FormItem.property(name: "key", value: "value")])
        let contentType = mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") ?? ""
        #expect(contentType.hasPrefix("multipart/form-data; boundary=----Boundary-"))
    }
}
