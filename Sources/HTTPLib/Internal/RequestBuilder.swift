import Foundation

// FR-005, FR-007, FR-009: request assembly — configuration, headers, body
// Feature 003: replaced configurator: RequestConfigurator? with configuration: RequestConfiguration (FR-008)
internal enum RequestBuilder {

    /// Assembles a URLRequest ready for dispatch.
    ///
    /// Assembly order (Feature 003, data-model.md):
    ///   Step 1 — RequestConfiguration transport properties (applied first; FR-005, A-07)
    ///   Step 2 — defaultHeaders (lowest header-priority tier; FR-002, FR-004)
    ///   Step 3 — per-request headers (overwrites step 2 conflicts; research Decision 6)
    ///   Step 4 — library Content-Type + httpBody (highest header-priority tier; FR-005)
    static func buildRequest(
        url: URL,
        method: HTTPMethod,
        headers: [String: String]?,
        body: RequestBody?,
        configuration: HTTPEngine.Configuration,    // Feature 003: replaces configurator (FR-008)
        defaultHeaders: [String: String]         // FR-002: engine-level default headers (lowest header priority)
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Step 1 — apply RequestConfiguration transport properties (Feature 003, FR-005, A-07)
        // Applied before headers and body; engine-managed properties (method, URL, body, headers)
        // are set in steps 2–4 and always take final precedence (FR-007).
        request.timeoutInterval = configuration.timeoutInterval
        request.cachePolicy = configuration.cachePolicy
        request.allowsCellularAccess = configuration.allowsCellularAccess
        request.allowsExpensiveNetworkAccess = configuration.allowsExpensiveNetworkAccess
        request.allowsConstrainedNetworkAccess = configuration.allowsConstrainedNetworkAccess
        request.httpShouldHandleCookies = configuration.httpShouldHandleCookies

        // Step 2 — defaultHeaders applied first (lowest header priority; no-op when empty, FR-004)
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Step 3 — caller per-request headers overwrite step 2 conflicts (research Decision 6)
        for (key, value) in headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Step 4 — library body encoding + Content-Type
        // Library sets Content-Type AFTER caller headers, overwriting any conflict (FR-009/US3-AC-03)
        if let body {
            switch body {
            case .text(let s):
                // FR-012: plain text body
                request.httpBody = Data(s.utf8)
                request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")

            case .binary(let d, let contentType):
                // FR-012: raw bytes verbatim
                request.httpBody = d
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")

            case .json(let v):
                // FR-012: JSON-encoded Encodable; throws before network activity on encode failure
                do {
                    request.httpBody = try JSONEncoder().encode(v)
                } catch {
                    throw HTTPEngineError.jsonEncodingFailed(error)
                }
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        return request
    }
}
