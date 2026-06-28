import Foundation

// FR-009, FR-011: request assembly — headers, body, configurator
internal enum RequestBuilder {

    /// Assembles a URLRequest ready for dispatch.
    ///
    /// Header priority (research Decision 6, Feature 002 data-model.md):
    ///   1. defaultHeaders (applied first — lowest priority, FR-002, FR-004)
    ///   2. Caller-supplied per-request headers (overwrites step 1 conflicts — US3-AC-01)
    ///   3. Library-managed Content-Type for body requests (overwrites steps 1–2 — FR-005)
    ///   4. RequestConfigurator callback (applied last — FR-011)
    static func buildRequest(
        url: URL,
        method: HTTPMethod,
        headers: [String: String]?,
        body: RequestBody?,
        configurator: RequestConfigurator?,
        defaultHeaders: [String: String]         // FR-002: engine-level default headers (lowest priority)
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Step 1 — defaultHeaders applied first (lowest priority; no-op when empty, FR-004)
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Step 2 — caller per-request headers overwrite step 1 conflicts (research Decision 6)
        for (key, value) in headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Step 3 — library body encoding + Content-Type
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

        // Step 4 — configurator runs last (FR-011)
        configurator?(&request)

        return request
    }
}
