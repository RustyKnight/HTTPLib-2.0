import Foundation

// FR-001, FR-004, FR-009: primary entry point; async operations; injectable session
// Feature 003: RequestConfigurator typealias and configurator stored property removed (FR-008, breaking change A-09)
public struct HTTPClient: Sendable {

    public let session: URLSession
    public let configuration: Configuration
    // FR-002, FR-004, FR-007: immutable default headers applied to every outbound request (lowest priority tier)
    public let defaultHeaders: [String: String]
    public let logger: (any HTTPClient.Logger)?

    public init(
        session: URLSession = .shared,
        configuration: Configuration = .default,
        defaultHeaders: [String: String]? = nil,
        logger: (any HTTPClient.Logger)? = nil
    ) {
        self.session = session
        self.configuration = configuration
        self.defaultHeaders = defaultHeaders ?? [:]
        self.logger = logger
    }

    // MARK: - Shared dispatch helper

    /// Shared implementation for all HTTP methods. Handles cancellation, request building,
    /// network dispatch, error wrapping, and response construction.
    private func dispatch(
        url: URL,
        method: HTTPMethod,
        headers: [String: String]?,
        body: RequestBody? = nil
    ) async throws -> HTTPResponse {
        // FR-007, research Decision 8: check cancellation before any work
        try Task.checkCancellation()

        let request = try RequestBuilder.buildRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            configuration: configuration,        // Feature 003: replaces configurator (FR-008)
            defaultHeaders: self.defaultHeaders  // FR-002: engine-level default headers (step 2)
        )

        log(request: request, method: method)

        let data: Data
        let urlResponse: URLResponse
        do {
            // FR-010: routes through injected session
            (data, urlResponse) = try await self.session.data(for: request)
        } catch is CancellationError {
            // FR-007: CancellationError propagates directly — never wrapped in HTTPClientError
            throw CancellationError()
        } catch {
            throw HTTPClientError.networkError(error)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw HTTPClientError.networkError(URLError(.badServerResponse))
        }

        // FR-008: non-2xx status codes are returned to the caller, not thrown
        let responseHeaders = httpResponse.allHeaderFields as? [String: String] ?? [:]
        return HTTPResponse(
            url: url,
            method: method,
            headers: responseHeaders,
            statusCode: httpResponse.statusCode,
            body: data.isEmpty ? nil : data
        )
    }

    // MARK: - GET (FR-002, FR-014 — no body parameter)

    public func get(
        _ url: URL,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        try await dispatch(url: url, method: .get, headers: headers)
    }

    // MARK: - POST (FR-002)

    /// POST with an optional body.
    public func post(
        _ url: URL,
        body: RequestBody? = nil,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        try await dispatch(url: url, method: .post, headers: headers, body: body)
    }

    // MARK: - PUT (FR-002)

    /// PUT with an optional body.
    public func put(
        _ url: URL,
        body: RequestBody? = nil,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        try await dispatch(url: url, method: .put, headers: headers, body: body)
    }

    // MARK: - POST multipart (FR-015, US5)

    /// POST with multipart form-data. `formItems` must be non-empty and all items must have
    /// non-empty names. Throws before any network activity on validation or encoding failure.
    public func post(
        _ url: URL,
        formItems: [FormItem],
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        // FR-007: check cancellation before any work
        try Task.checkCancellation()  // FR-007: CancellationError propagates directly

        // FR-020: validate non-empty formItems before encoding
        guard !formItems.isEmpty else {
            throw HTTPClientError.emptyFormItems
        }

        // FR-021: validate all item names before encoding
        guard formItems.allSatisfy({ !$0.name.isEmpty }) else {
            throw HTTPClientError.emptyFormItemName
        }

        // FR-018: encode as RFC 2046 multipart/form-data
        let (multipartBody, contentType) = try MultipartEncoder.encode(formItems)

        // Build request manually (body is pre-encoded — not a RequestBody variant)
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue

        // Step 1 — apply HTTPClient.Configuration transport properties (Feature 003, FR-005, A-07)
        request.timeoutInterval = configuration.timeoutInterval
        request.cachePolicy = configuration.cachePolicy
        request.allowsCellularAccess = configuration.allowsCellularAccess
        request.allowsExpensiveNetworkAccess = configuration.allowsExpensiveNetworkAccess
        request.allowsConstrainedNetworkAccess = configuration.allowsConstrainedNetworkAccess
        request.httpShouldHandleCookies = configuration.httpShouldHandleCookies

        // Step 2 — default headers (lowest priority; FR-002, FR-004)
        for (key, value) in self.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Step 3 — caller headers overwrite step 2 conflicts (research Decision 6)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Step 4 — library Content-Type overwrites any conflicting caller header (FR-009, US3-AC-03)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        request.httpBody = multipartBody

        log(request: request, method: .post)

        // FR-010: routes through injected session
        do {
            let (data, urlResponse) = try await self.session.data(for: request)
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw HTTPClientError.networkError(URLError(.badServerResponse))
            }
            // FR-008: non-2xx returned, not thrown
            let responseHeaders = httpResponse.allHeaderFields as? [String: String] ?? [:]
            return HTTPResponse(
                url: url,
                method: .post,
                headers: responseHeaders,
                statusCode: httpResponse.statusCode,
                body: data.isEmpty ? nil : data
            )
        } catch is CancellationError {
            throw CancellationError()  // FR-007: CancellationError propagates directly
        } catch let e as HTTPClientError {
            throw e  // HTTPClientError from MultipartEncoder propagates directly
        } catch {
            throw HTTPClientError.networkError(error)
        }
    }

    private func log(request: URLRequest, method: HTTPMethod) {
        guard let logger else { return }
        logger.log(
            request.httpClientLogDescription(
                method: method,
                includeHeaders: logger.includeHeaders,
                includeBody: logger.includeBody
            )
        )
    }

    /// DELETE with an optional body.
    public func delete(
        _ url: URL,
        body: RequestBody? = nil,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        try await dispatch(url: url, method: .delete, headers: headers, body: body)
    }
}
