# Public API Contract: HTTPClient Library

**Feature**: `001-http-engine-library` | **Date**: 2026-06-28 | **Phase 1**

This document is the authoritative contract for the public API surface of the
`HTTPLib` Swift Package. Breaking changes to any signature, type, or semantic
guarantee listed here MUST be accompanied by a MAJOR version bump in `Package.swift`
per the project constitution's governance policy.

---

## Module

```swift
import HTTPClientLib
```

---

## Types

### `HTTPClient`

```swift
public struct HTTPClient: Sendable {

    public init(
        session: URLSession = .shared,
        configurator: RequestConfigurator? = nil
    )

    // MARK: — GET

    public func get(
        _ url: URL,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse

    // MARK: — POST

    /// POST with no body.
    public func post(
        _ url: URL,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse

    /// POST with an explicit body (text, binary, or JSON-encoded Encodable).
    public func post(
        _ url: URL,
        body: RequestBody,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse

    /// POST with multipart form-data. `formItems` must be non-empty.
    public func post(
        _ url: URL,
        formItems: [FormItem],
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse

    // MARK: — PUT

    /// PUT with no body.
    public func put(
        _ url: URL,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse

    /// PUT with an explicit body.
    public func put(
        _ url: URL,
        body: RequestBody,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse

    // MARK: — DELETE

    /// DELETE with no body.
    public func delete(
        _ url: URL,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse

    /// DELETE with an optional body.
    public func delete(
        _ url: URL,
        body: RequestBody,
        headers: [String: String]? = nil
    ) async throws -> HTTPResponse
}
```

#### Concurrency guarantees

- All methods are `async`. The caller's `Task` is checked for cancellation at the
  start of each method (before request assembly).
- If the `Task` is already cancelled on entry, `CancellationError` is thrown
  immediately, before any network activity or encoding begins.
- If the `Task` is cancelled while a request is in-flight, `CancellationError` is
  propagated to the caller via `URLSession`'s native Swift Concurrency integration.
- **`CancellationError` is never wrapped in `HTTPClientError`.**
- Concurrent calls on the same `HTTPClient` instance from multiple `Task`s are safe.

#### Error contract

Errors thrown are `HTTPClientError` (see below) except for `CancellationError`
(which propagates directly). Non-2xx HTTP status codes are **not** thrown — they
are returned in `HTTPResponse.statusCode`.

---

### `HTTPResponse`

```swift
public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let body: Data?
}
```

- `statusCode` — the integer HTTP status code from the server's response.
- `body` — raw response body bytes; `nil` when the server sends no body.
- Non-2xx status codes are returned to the caller, not thrown.

---

### `RequestBody`

```swift
public enum RequestBody: @unchecked Sendable {
    /// Plain-text body. Encoded as UTF-8. Sets `Content-Type: text/plain; charset=utf-8`.
    case text(String)
    /// Raw binary body. Transmitted verbatim. No `Content-Type` is set by the library.
    case binary(Data)
    /// Any `Encodable` value. Serialised by `JSONEncoder`. Sets `Content-Type: application/json`.
    /// Throws `HTTPClientError.jsonEncodingFailed` if encoding fails.
    case json(any Encodable)
}
```

| Case | `Content-Type` set by library | Encoding behaviour |
|------|-------------------------------|-------------------|
| `.text` | `text/plain; charset=utf-8` | String → UTF-8 `Data` |
| `.binary` | *(none)* | `Data` used verbatim |
| `.json` | `application/json` | `JSONEncoder().encode(value)`; throws on failure |

---

### `FormItem`

```swift
public enum FormItem: Sendable {
    case file(name: String, url: URL, fileName: String?, mimeType: String?)
    case data(name: String, body: Data, fileName: String?, mimeType: String?)
    case property(name: String, value: String, mimeType: String?)
}
```

**Ergonomic factory methods** (preferred call-site form):

```swift
extension FormItem {
    public static func file(
        name: String,
        url: URL,
        fileName: String? = nil,
        mimeType: String? = nil
    ) -> FormItem

    public static func data(
        name: String,
        body: Data,
        fileName: String? = nil,
        mimeType: String? = nil
    ) -> FormItem

    public static func property(
        name: String,
        value: String,
        mimeType: String? = nil
    ) -> FormItem
}
```

The factory methods supply `nil` defaults for optional fields; the enum cases remain
public for exhaustive pattern matching in consumer code.

| Case | Default `Content-Type` | `mimeType` override |
|------|------------------------|---------------------|
| `.file` | `application/octet-stream` | Replaces default when non-nil |
| `.data` | `application/octet-stream` | Replaces default when non-nil |
| `.property` | `text/plain` | Replaces default when non-nil |

---

### `HTTPClientError`

```swift
public enum HTTPClientError: Error, Sendable {
    /// A `.json` body failed `JSONEncoder.encode`. Contains the underlying encoder error.
    case jsonEncodingFailed(any Error)
    /// A `.file` form item URL could not be read. Contains the file URL and underlying error.
    case fileReadFailed(url: URL, underlying: any Error)
    /// The `formItems` array supplied to a multipart POST was empty.
    case emptyFormItems
    /// A `FormItem.name` was the empty string.
    case emptyFormItemName
    /// URLSession threw a network-level error (typically `URLError`).
    case networkError(any Error)
}
```

`CancellationError` is **not** a case of this enum — it propagates directly.

---

### `RequestConfigurator`

```swift
public typealias RequestConfigurator = @Sendable (inout URLRequest) -> Void
```

Supplied to `HTTPClient.init(configurator:)`. Invoked synchronously with the
fully assembled `URLRequest` (all headers and body already applied) immediately
before the request is dispatched to `URLSession`. Any mutations the callback
applies are applied to the outbound request. Overriding the HTTP method set by the
library is the caller's responsibility (A-10).

---

## Behavioural Guarantees

### Header priority

1. Caller-supplied `headers` dictionary entries are applied first.
2. Library-required headers (`Content-Type` for body/multipart requests) are applied
   second, overwriting any conflicting caller-supplied value.
3. The `RequestConfigurator` callback (if provided) runs last; its mutations are
   applied to the final request.

### Body encoding order

1. `RequestBody.json` — encoding happens before the request is dispatched; any
   `JSONEncoder` failure throws `HTTPClientError.jsonEncodingFailed` before network
   activity begins.
2. Multipart `FormItem.file` — file contents are read before the request is
   dispatched; any read failure throws `HTTPClientError.fileReadFailed`.

### Non-throwing status codes

The library never throws for HTTP-level status codes (1xx–5xx). The caller receives
the status in `HTTPResponse.statusCode` and is responsible for interpretation.

### GET body restriction

`get(_:headers:)` does not accept a `body` parameter (FR-014). Callers requiring
non-standard GET semantics with a body may use the `RequestConfigurator` callback.

---

## Minimal usage examples

```swift
let engine = HTTPClient()

// GET
let response = try await engine.get(url)

// POST with JSON body
let response = try await engine.post(url, body: .json(myModel))

// POST multipart
let response = try await engine.post(url, formItems: [
    .property(name: "username", value: "alice"),
    .file(name: "avatar", url: avatarURL, fileName: "avatar.png", mimeType: "image/png")
])

// Custom session (e.g., for unit tests)
let session = URLSession(configuration: .ephemeral)
let testEngine = HTTPClient(session: session)

// URLRequest customisation
let engineWithTimeout = HTTPClient { request in
    request.timeoutInterval = 10
}
```

---

## Stability policy

This API surface is at version **0.0.1** (pre-release). Until `1.0.0` is declared
in `Package.swift`, breaking changes may occur on any version increment. Upon
`1.0.0`, the governance rules in `constitution.md` apply: breaking changes require
a MAJOR version bump.
