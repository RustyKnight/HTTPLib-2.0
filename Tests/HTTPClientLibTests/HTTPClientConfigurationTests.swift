import Testing
import Foundation
@testable import HTTPClientLib

// US1–US4 acceptance tests for Feature 003: Request Configuration Struct
// Engine-level configuration is provided at HTTPClient initialization.
@Suite("HTTPClient Configuration") struct HTTPClientConfigurationTests {

    private let url = URL(string: "https://example.com")!

    private func makeEngine(configuration: HTTPClient.Configuration = .default) -> (HTTPClient, MockURLProtocol.MockContext) {
        let (session, mock) = MockURLProtocol.makePair()
        return (HTTPClient(session: session, configuration: configuration), mock)
    }

    // MARK: - User Story 1: Zero-Config Default Behaviour

    // US1-AC-2: Built-in default value properties match URLRequest platform defaults
    @Test func defaultConfigurationMatchesPlatformDefaults() {
        let config = HTTPClient.Configuration.default
        #expect(config.timeoutInterval == 60.0)
        #expect(config.cachePolicy == .useProtocolCachePolicy)
        #expect(config.allowsCellularAccess == true)
        #expect(config.allowsExpensiveNetworkAccess == true)
        #expect(config.allowsConstrainedNetworkAccess == true)
        #expect(config.httpShouldHandleCookies == true)
    }

    // US1-AC-1: Default configuration is applied when no argument is supplied
    @Test func defaultConfigurationIsAppliedWhenNoArgumentSupplied() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.timeoutInterval == 60.0)
        #expect(mock.capturedRequest?.cachePolicy == .useProtocolCachePolicy)
    }

    // US1-AC-3: All HTTP methods with no config argument carry default property values
    @Test func existingCallSitesUnchangedWithDefaultConfig() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.timeoutInterval == 60.0)
        #expect(mock.capturedRequest?.cachePolicy == .useProtocolCachePolicy)

        _ = try await engine.post(url)
        #expect(mock.capturedRequest?.timeoutInterval == 60.0)
        #expect(mock.capturedRequest?.cachePolicy == .useProtocolCachePolicy)

        _ = try await engine.put(url)
        #expect(mock.capturedRequest?.timeoutInterval == 60.0)
        #expect(mock.capturedRequest?.cachePolicy == .useProtocolCachePolicy)

        _ = try await engine.delete(url)
        #expect(mock.capturedRequest?.timeoutInterval == 60.0)
        #expect(mock.capturedRequest?.cachePolicy == .useProtocolCachePolicy)
    }

    // MARK: - User Story 2: Custom Per-Request Configuration

    // US2-AC-1: Custom timeout duration is applied to outgoing URLRequest
    @Test func customTimeoutAppliedToRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 120.0))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.timeoutInterval == 120.0)
    }

    // US2-AC-2: Custom cache policy is applied to outgoing URLRequest
    @Test func customCachePolicyAppliedToRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(cachePolicy: .reloadIgnoringLocalCacheData))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url)
        #expect(mock.capturedRequest?.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    // US2-AC-3: Cellular access restriction is applied to outgoing URLRequest
    @Test func cellularAccessDisabledAppliedToRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(allowsCellularAccess: false))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.allowsCellularAccess == false)
    }

    // US2-AC-4: Expensive-network restriction is applied to outgoing URLRequest
    @Test func expensiveNetworkAccessDisabledAppliedToRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(allowsExpensiveNetworkAccess: false))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.allowsExpensiveNetworkAccess == false)
    }

    // US2-AC-5: Constrained-network restriction is applied to outgoing URLRequest
    @Test func constrainedNetworkAccessDisabledAppliedToRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(allowsConstrainedNetworkAccess: false))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.allowsConstrainedNetworkAccess == false)
    }

    // US2-AC-6: Cookie handling restriction is applied to outgoing URLRequest
    @Test func cookieHandlingDisabledAppliedToRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(httpShouldHandleCookies: false))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.httpShouldHandleCookies == false)
    }

    // US2-AC-7: Multiple non-default properties are all applied simultaneously
    @Test func multiplePropertiesAllAppliedSimultaneously() async throws {
        let config = HTTPClient.Configuration(
            timeoutInterval: 10.0,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            allowsCellularAccess: false
        )
        let (engine, mock) = makeEngine(configuration: config)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.timeoutInterval == 10.0)
        #expect(mock.capturedRequest?.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
        #expect(mock.capturedRequest?.allowsCellularAccess == false)
    }

    // US2 (POST body): configured engine applies settings to post(_:body:headers:)
    @Test func configurationAppliedToPostBodyRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 77.0))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(url)
        #expect(mock.capturedRequest?.timeoutInterval == 77.0)
    }

    // US2 (multipart POST): configured engine applies settings to post(_:formItems:headers:)
    @Test func configurationAppliedToMultipartPostRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 88.0))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        let formItems = [FormItem.property(name: "key", value: "val")]
        _ = try await engine.post(url, formItems: formItems)
        #expect(mock.capturedRequest?.timeoutInterval == 88.0)
    }

    // US2 (PUT): configured engine applies settings to put(_:body:headers:)
    @Test func configurationAppliedToPutRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 99.0))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.put(url)
        #expect(mock.capturedRequest?.timeoutInterval == 99.0)
    }

    // US2 (DELETE): configured engine applies settings to delete(_:body:headers:)
    @Test func configurationAppliedToDeleteRequest() async throws {
        let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 55.0))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.delete(url)
        #expect(mock.capturedRequest?.timeoutInterval == 55.0)
    }

    // MARK: - User Story 3: Configuration Is Isolated Across Requests

    // US3-AC-1: Sequential requests on one engine consistently use that engine's configuration
    @Test func configurationIsolatedAcrossSequentialRequests() async throws {
        let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 999.0))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url)
        let timeoutA = mock.capturedRequest?.timeoutInterval

        _ = try await engine.get(url)
        let timeoutB = mock.capturedRequest?.timeoutInterval

        #expect(timeoutA == 999.0)
        #expect(timeoutB == 999.0)
    }

    // US3-AC-2: Configuration value is not mutated by request calls (value semantics)
    @Test func configurationValueNotMutatedByRequestCall() async throws {
        let sharedConfig = HTTPClient.Configuration(timeoutInterval: 30.0)
        let (engine, mock) = makeEngine(configuration: sharedConfig)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url)
        _ = try await engine.post(url)

        // Value semantics: sharedConfig properties are unchanged after both calls
        #expect(sharedConfig.timeoutInterval == 30.0)
    }

    // US3-AC-3: Concurrent requests from different engines keep engine-local configuration
    @Test func concurrentRequestsCarryOwnConfiguration() async throws {
        let (sessionA, mockA) = MockURLProtocol.makePair()
        let engineA = HTTPClient(session: sessionA, configuration: .init(timeoutInterval: 10.0))
        mockA.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        let (sessionB, mockB) = MockURLProtocol.makePair()
        let engineB = HTTPClient(session: sessionB)
        mockB.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        async let responseA = engineA.get(url)
        async let responseB = engineB.get(url)
        _ = try await (responseA, responseB)

        #expect(mockA.capturedRequest?.timeoutInterval == 10.0)
        #expect(mockB.capturedRequest?.timeoutInterval == 60.0)
    }

    // MARK: - User Story 4: Configuration Does Not Override Engine-Managed Properties

    // US4-AC-1: HTTP method is set by the engine; configuration cannot override it
    @Test func configurationDoesNotOverrideHTTPMethod() async throws {
        let config = HTTPClient.Configuration(timeoutInterval: 999.0, allowsCellularAccess: false)
        let (engine, mock) = makeEngine(configuration: config)
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.httpMethod == "GET")

        _ = try await engine.post(url)
        #expect(mock.capturedRequest?.httpMethod == "POST")
    }

    // US4-AC-2: URL is set by the engine; configuration cannot override it
    @Test func configurationDoesNotOverrideURL() async throws {
        let (engine, mock) = makeEngine(configuration: .init(cachePolicy: .reloadIgnoringLocalCacheData))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(url)
        #expect(mock.capturedRequest?.url == url)
    }

    // US4-AC-1: HTTP body and Content-Type set by the engine; configuration cannot override them
    @Test func configurationDoesNotOverrideHTTPBody() async throws {
        struct Payload: Encodable { let key: String }
        let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 5.0))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.post(
            url,
            body: .json(Payload(key: "value"))
        )
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let bodyData = try #require(mock.capturedRequest?.httpBody)
        let decoded = try JSONDecoder().decode([String: String].self, from: bodyData)
        #expect(decoded == ["key": "value"])
    }

    // US4-AC-1: Caller-supplied headers are unchanged; configuration does not interfere
    @Test func configurationDoesNotOverrideCallerHeaders() async throws {
        let (engine, mock) = makeEngine(configuration: .init(allowsCellularAccess: false))
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
        _ = try await engine.get(
            url,
            headers: ["X-Caller": "value"]
        )
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-Caller") == "value")
    }
}
