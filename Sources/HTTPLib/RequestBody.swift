import Foundation

// FR-012, FR-013: body variants for POST, PUT, DELETE
// @unchecked Sendable required because `any Encodable` is not statically Sendable in Swift 6.
// JSON encoding occurs synchronously in RequestBuilder before the async boundary,
// so no data-race is possible in practice (research.md Decision 3).
public enum RequestBody: @unchecked Sendable {
    /// Plain-text body. Encoded as UTF-8. Sets `Content-Type: text/plain; charset=utf-8`.
    case text(String)
    /// Raw binary body. Transmitted verbatim.
    case binary(Data, contentType: String)
    /// Any `Encodable` value. Serialised by `JSONEncoder`. Sets `Content-Type: application/json`.
    /// Throws `HTTPClientError.jsonEncodingFailed` if encoding fails.
    case json(any Encodable)
}
