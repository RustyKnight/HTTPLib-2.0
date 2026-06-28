# Data Model: HTTPEngine Library

**Feature**: `001-http-engine-library` | **Date**: 2026-06-28 | **Phase 1**

See `research.md` for the rationale behind each design decision referenced below.

---

## Public Types

### `HTTPEngine`

**Kind**: `public struct`
**Conforms to**: `Sendable` (synthesised — all stored properties are `let` and `Sendable`)
**Location**: `Sources/HTTPLib/HTTPEngine.swift`
**Spec ref**: FR-001, FR-002, FR-010, FR-011, A-01, A-07

#### Stored Properties

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `session` | `URLSession` | `.shared` | All network operations are routed through this instance (FR-010). |
| `configurator` | `RequestConfigurator?` | `nil` | Invoked with the assembled `URLRequest` immediately before dispatch (FR-011). |

#### Initialiser

```swift
public init(session: URLSession = .shared, configurator: RequestConfigurator? = nil)
```

#### Operations

All operations are `async throws -> HTTPResponse`.

| Method | Signature | Body | Spec ref |
|--------|-----------|------|----------|
| GET | `get(_ url: URL, headers: [String: String]? = nil)` | None (FR-014) | FR-002, FR-003, FR-009 |
| POST | `post(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil)` | Optional | FR-002, FR-012 |
| POST multipart | `post(_ url: URL, formItems: [FormItem], headers: [String: String]? = nil)` | `[FormItem]` | FR-015 |
| PUT | `put(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil)` | Optional | FR-002, FR-012 |
| DELETE | `delete(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil)` | Optional | FR-002, FR-013 |

#### Validation Rules

- `formItems` must be non-empty — throws `HTTPEngineError.emptyFormItems` (FR-020).
- Each `FormItem` must have a non-empty `name` — throws `HTTPEngineError.emptyFormItemName` (FR-021).
- These checks run before any encoding or network activity begins.

#### Concurrency & Lifecycle

Each operation is stateless; no per-request mutable state is retained in the struct
after the call returns. Concurrent calls from multiple `Task`s are safe (A-07).
`Task.checkCancellation()` is called at the start of each operation; `CancellationError`
propagates directly to the caller (FR-007, research Decision 8).

---

### `HTTPResponse`

**Kind**: `public struct`
**Conforms to**: `Sendable` (synthesised)
**Location**: `Sources/HTTPLib/HTTPResponse.swift`
**Spec ref**: FR-004, FR-008

| Field | Type | Notes |
|-------|------|-------|
| `statusCode` | `Int` | HTTP status code from `HTTPURLResponse.statusCode`. Reflects the server value verbatim. |
| `body` | `Data?` | Raw response body bytes; `nil` if the server sent no body. |

Non-2xx status codes do **not** cause an error to be thrown (FR-008); `statusCode` is returned to
the caller for interpretation.

---

### `RequestBody`

**Kind**: `public enum`
**Conforms to**: `@unchecked Sendable` (see research Decision 3)
**Location**: `Sources/HTTPLib/RequestBody.swift`
**Spec ref**: FR-012, FR-013

| Case | Associated Value | `Content-Type` applied | Encoding |
|------|-----------------|------------------------|---------|
| `.text(String)` | `String` | `text/plain; charset=utf-8` | UTF-8 bytes |
| `.binary(Data)` | `Data` | *(none added by library)* | Raw bytes verbatim |
| `.json(any Encodable)` | `any Encodable` | `application/json` | `JSONEncoder().encode(value)` |

#### Validation Rules

- `.json` encoding failure: throws `HTTPEngineError.jsonEncodingFailed(underlying:)` before
  any network activity begins (FR-006, spec user story 2 AC-04).

---

### `FormItem`

**Kind**: `public enum`
**Conforms to**: `Sendable` (synthesised — `URL`, `Data`, `String` are all `Sendable`)
**Location**: `Sources/HTTPLib/FormItem.swift`
**Spec ref**: FR-016, FR-017, FR-019

| Case | Required fields | Optional fields | Default `Content-Type` |
|------|----------------|----------------|------------------------|
| `.file(name:url:fileName:mimeType:)` | `name: String`, `url: URL` | `fileName: String?`, `mimeType: String?` | `application/octet-stream` |
| `.data(name:body:fileName:mimeType:)` | `name: String`, `body: Data` | `fileName: String?`, `mimeType: String?` | `application/octet-stream` |
| `.property(name:value:mimeType:)` | `name: String`, `value: String` | `mimeType: String?` | `text/plain` |

When `mimeType` is explicitly supplied it overrides the default (FR-019, spec user story 5 AC-06).

#### Static Factory Methods (ergonomic constructors)

To satisfy the progressive-disclosure principle without requiring callers to spell out `nil`
for unused optional associated values, `FormItem` exposes static factory methods:

```swift
// .file
public static func file(name: String, url: URL, fileName: String? = nil, mimeType: String? = nil) -> FormItem

// .data
public static func data(name: String, body: Data, fileName: String? = nil, mimeType: String? = nil) -> FormItem

// .property
public static func property(name: String, value: String, mimeType: String? = nil) -> FormItem
```

These are implemented as `extension FormItem` static functions returning the corresponding
enum case. The enum cases themselves remain public for exhaustive pattern matching.

#### Validation Rules

- `name` must be non-empty on every case; validated by `HTTPEngine` before encoding (FR-021).
- `.file` with an unreadable `url`: throws `HTTPEngineError.fileReadFailed(url:underlying:)` during
  encoding, before network activity (spec user story 5 AC-03, FR-006).

---

### `HTTPEngineError`

**Kind**: `public enum`
**Conforms to**: `Error`, `Sendable`
**Location**: `Sources/HTTPLib/HTTPEngineError.swift`
**Spec ref**: FR-006

| Case | Parameters | Trigger |
|------|-----------|---------|
| `jsonEncodingFailed(any Error)` | Underlying encoder error | `.json` body fails `JSONEncoder.encode` |
| `fileReadFailed(url: URL, underlying: any Error)` | File URL + underlying error | `.file` form item URL is unreadable |
| `emptyFormItems` | — | `formItems` is empty on a multipart POST call |
| `emptyFormItemName` | — | A `FormItem.name` is the empty string |
| `networkError(any Error)` | Underlying `URLError` or similar | URLSession throws during data task |

**Note**: `CancellationError` is **not** wrapped in this enum — it propagates directly (FR-007,
research Decision 8). `HTTPEngineError` covers library-originated and URLSession-originated
failures; `CancellationError` is a Swift Concurrency primitive and must remain unwrapped.

---

### `RequestConfigurator`

**Kind**: `public typealias`
**Location**: `Sources/HTTPLib/HTTPEngine.swift`
**Spec ref**: FR-011

```swift
public typealias RequestConfigurator = @Sendable (inout URLRequest) -> Void
```

Invoked with the fully assembled `URLRequest` (headers and body already applied)
immediately before dispatch to `URLSession.data(for:delegate:)`. Any mutations the
callback applies are reflected in the outbound request. A-10 documents that overriding
the HTTP method via this callback is the caller's responsibility.

---

## Internal Types

### `MultipartEncoder`

**Kind**: `internal struct`
**Location**: `Sources/HTTPLib/Internal/MultipartEncoder.swift`
**Spec ref**: FR-018

```swift
static func encode(_ items: [FormItem]) throws -> (body: Data, contentType: String)
```

- Generates a fresh boundary: `"----Boundary-\(UUID().uuidString)"` (A-09).
- Encodes each part with CRLF (`\r\n`) line endings per RFC 2046 §4.1.
- Returns the encoded body `Data` and the complete `Content-Type` header value
  (e.g., `multipart/form-data; boundary=----Boundary-XXXX`).
- Throws `HTTPEngineError.fileReadFailed` if a `.file` item is unreadable.
- Throws `HTTPEngineError.emptyFormItemName` if any item has an empty `name`.
  (Validation is also performed by `HTTPEngine` before calling the encoder, so this
  acts as a defence-in-depth guard.)

---

### `RequestBuilder`

**Kind**: `internal` (set of `static` functions or `internal struct`)
**Location**: `Sources/HTTPLib/Internal/RequestBuilder.swift`
**Spec ref**: FR-009, FR-011, FR-012

Responsibilities:

1. Construct a `URLRequest` from URL + HTTP method string.
2. Apply caller-supplied `headers` dictionary (FR-009).
3. Apply library-required headers (`Content-Type` for body variants) — overwriting
   any conflicting caller-supplied value (user story 3 AC-03, research Decision 6).
4. Set `httpBody` from `RequestBody` if provided; perform JSON encoding here.
5. Invoke `RequestConfigurator` callback if non-nil (FR-011); mutations are applied last.

---

## Type Relationships

```
HTTPEngine
  ├── holds → URLSession                (Foundation — injected or .shared)
  ├── holds → RequestConfigurator?      (typealias for @Sendable closure)
  ├── delegates assembly to → RequestBuilder (internal)
  │     ├── produces → URLRequest
  │     ├── encodes → RequestBody       (.text / .binary / .json)
  │     └── delegates multipart to → MultipartEncoder (internal)
  │           └── consumes → [FormItem] (.file / .data / .property)
  ├── dispatches via → URLSession.data(for:delegate:)
  └── returns → HTTPResponse            (.statusCode + .body)

Errors thrown (public)
  └── HTTPEngineError
        ├── jsonEncodingFailed   (from RequestBuilder .json encoding)
        ├── fileReadFailed       (from MultipartEncoder .file reading)
        ├── emptyFormItems       (from HTTPEngine validation gate)
        ├── emptyFormItemName    (from HTTPEngine validation gate)
        └── networkError         (from URLSession data task)

Errors that bypass HTTPEngineError (propagate directly)
  └── CancellationError          (from Task.checkCancellation / URLSession async)
```
