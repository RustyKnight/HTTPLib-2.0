import Testing
import Foundation
import SupportLib
@testable import HTTPClientLib

@Suite("HTTPClient Protocol Surface") struct HTTPClientProtocolSurfaceTests {

    private let url = URL(string: "https://example.com")!

    private struct MockResponse: HTTPResponse {
        let url: URL
        let method: HTTPMethod
        let headers: [String: String]
        let statusCode: Int
        let body: Data?
    }

    private struct CapturedCall {
        let method: HTTPMethod
        let url: URL
        let body: RequestBody?
        let headers: [String: String]?
        let progress: SupportLib.ProgressTracker?
    }

    private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var lastCapturedCall: CapturedCall?
        private(set) var lastMultipartCall: (url: URL, formItems: [FormItem], headers: [String: String]?, progress: SupportLib.ProgressTracker?)?
        private let nextResponse: HTTPResponse

        init(nextResponse: HTTPResponse) {
            self.nextResponse = nextResponse
        }

        func get(_ url: URL, headers: [String : String]?, progress: SupportLib.ProgressTracker?) async throws -> HTTPResponse {
            lock.withLock { lastCapturedCall = CapturedCall(method: .get, url: url, body: nil, headers: headers, progress: progress) }
            return nextResponse
        }

        func post(_ url: URL, body: RequestBody?, headers: [String : String]?, progress: SupportLib.ProgressTracker?) async throws -> HTTPResponse {
            lock.withLock { lastCapturedCall = CapturedCall(method: .post, url: url, body: body, headers: headers, progress: progress) }
            return nextResponse
        }

        func put(_ url: URL, body: RequestBody?, headers: [String : String]?, progress: SupportLib.ProgressTracker?) async throws -> HTTPResponse {
            lock.withLock { lastCapturedCall = CapturedCall(method: .put, url: url, body: body, headers: headers, progress: progress) }
            return nextResponse
        }

        func post(_ url: URL, formItems: [FormItem], headers: [String : String]?, progress: SupportLib.ProgressTracker?) async throws -> HTTPResponse {
            lock.withLock { lastMultipartCall = (url: url, formItems: formItems, headers: headers, progress: progress) }
            return nextResponse
        }

        func delete(_ url: URL, body: RequestBody?, headers: [String : String]?, progress: SupportLib.ProgressTracker?) async throws -> HTTPResponse {
            lock.withLock { lastCapturedCall = CapturedCall(method: .delete, url: url, body: body, headers: headers, progress: progress) }
            return nextResponse
        }
    }

    @Test func convenienceGetForwardsToHeadersOverload() async throws {
        let expected = MockResponse(url: url, method: .get, headers: [:], statusCode: 200, body: nil)
        let mock = MockHTTPClient(nextResponse: expected)
        let client: any HTTPClient = mock

        let response = try await client.get(url)
        let call = try #require(mock.lastCapturedCall)

        #expect(call.method == .get)
        #expect(call.url == url)
        #expect(call.headers == nil)
        #expect(call.progress == nil)
        #expect(response.statusCode == 200)
    }

    @Test func conveniencePostBodyForwardsNilHeaders() async throws {
        let expected = MockResponse(url: url, method: .post, headers: [:], statusCode: 201, body: nil)
        let mock = MockHTTPClient(nextResponse: expected)
        let client: any HTTPClient = mock

        _ = try await client.post(url, body: .text("hello"))
        let call = try #require(mock.lastCapturedCall)

        #expect(call.method == .post)
        #expect(call.headers == nil)
        #expect(call.progress == nil)
        if case .text(let value)? = call.body {
            #expect(value == "hello")
        } else {
            Issue.record("Expected .text body to be forwarded")
        }
    }

    @Test func conveniencePostHeadersForwardsNilBody() async throws {
        let expected = MockResponse(url: url, method: .post, headers: [:], statusCode: 202, body: nil)
        let mock = MockHTTPClient(nextResponse: expected)
        let client: any HTTPClient = mock

        _ = try await client.post(url, headers: ["X-Trace": "abc"])
        let call = try #require(mock.lastCapturedCall)

        #expect(call.method == .post)
        switch call.body {
        case nil:
            break
        default:
            Issue.record("Expected nil body to be forwarded")
        }
        #expect(call.headers?["X-Trace"] == "abc")
        #expect(call.progress == nil)
    }
}
