import Foundation

// FR-011: @Sendable closure for URLRequest mutation before dispatch
public typealias RequestConfigurator = @Sendable (inout URLRequest) -> Void

// FR-001, FR-002, FR-005, FR-010: primary entry point; async operations; injectable session
public struct HTTPEngine: Sendable {

    public let session: URLSession
    public let configurator: RequestConfigurator?

    public init(
        session: URLSession = .shared,
        configurator: RequestConfigurator? = nil
    ) {
        self.session = session
        self.configurator = configurator
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
            configurator: self.configurator  // FR-011: configurator applied in RequestBuilder
        )

        let data: Data
        let urlResponse: URLResponse
        do {
            // FR-010: routes through injected session
            (data, urlResponse) = try await self.session.data(for: request)
        } catch is CancellationError {
            // FR-007: CancellationError propagates directly — never wrapped in HTTPEngineError
            throw CancellationError()
        } catch {
            throw HTTPEngineError.networkError(error)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw HTTPEngineError.networkError(URLError(.badServerResponse))
        }

        // FR-008: non-2xx status codes are returned to the caller, not thrown
        return HTTPResponse(
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

    /// POST with no body.
    public func post(
        _ url: URL,
        body: RequestBody? = nil,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse {
        try await dispatch(url: url, method: .post, headers: headers, body: body)
    }

    // MARK: - PUT (FR-002)

    /// PUT with an explicit body.
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
            throw HTTPEngineError.emptyFormItems
        }

        // FR-021: validate all item names before encoding
        guard formItems.allSatisfy({ !$0.name.isEmpty }) else {
            throw HTTPEngineError.emptyFormItemName
        }

        // FR-018: encode as RFC 2046 multipart/form-data
        let (multipartBody, contentType) = try MultipartEncoder.encode(formItems)

        // Build request manually (body is pre-encoded — not a RequestBody variant)
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue

        // Step 1 — caller headers first (research Decision 6)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Step 2 — library Content-Type overwrites any conflicting caller header (FR-009, US3-AC-03)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        // Step 3 — configurator last (FR-011: routes through injected configurator)
        self.configurator?(&request)  // FR-011: configurator applied in RequestBuilder

        request.httpBody = multipartBody

        // FR-010: routes through injected session
        do {
            let (data, urlResponse) = try await self.session.data(for: request)
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw HTTPEngineError.networkError(URLError(.badServerResponse))
            }
            // FR-008: non-2xx returned, not thrown
            return HTTPResponse(statusCode: httpResponse.statusCode, body: data.isEmpty ? nil : data)
        } catch is CancellationError {
            throw CancellationError()  // FR-007: CancellationError propagates directly
        } catch let e as HTTPEngineError {
            throw e  // HTTPEngineError from MultipartEncoder propagates directly
        } catch {
            throw HTTPEngineError.networkError(error)
        }
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
