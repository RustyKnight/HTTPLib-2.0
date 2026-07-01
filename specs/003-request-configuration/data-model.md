# Data Model: Request Configuration Struct

**Feature**: `003-request-configuration` | **Date**: 2026-06-28 | **Phase 1**

See `research.md` for the rationale behind each design decision referenced below.
This document covers all type changes required by this feature. Types not listed
here are unchanged from Feature 002 (`specs/002-configurable-headers/data-model.md`).

---

## New Nested Public Types

### `DefaultHTTPClient.Configuration`

**Kind**: `public struct` (nested inside `DefaultHTTPClient` via `public extension DefaultHTTPClient`)
**Conforms to**: `Sendable` (synthesised — all stored properties are `let` and `Sendable`)
**Location**: `Sources/HTTPClientLib/Implementation/DefaultHTTPClient+Configuration.swift` *(new file)*
**Spec ref**: FR-001, FR-002, FR-003, FR-005, FR-006, FR-009, FR-010, A-01–A-09

#### Stored Properties

| Property | Type | Default | Platform Default | Notes |
|----------|------|---------|-----------------|-------|
| `timeoutInterval` | `TimeInterval` | `60.0` | `60.0` | Request timeout in seconds. Negative values are passed through to the platform without validation (edge case — spec intentional). |
| `cachePolicy` | `URLRequest.CachePolicy` | `.useProtocolCachePolicy` | `.useProtocolCachePolicy` | Cache policy applied to every request using this configuration. |
| `allowsCellularAccess` | `Bool` | `true` | `true` | When `false`, requests are not sent over a cellular connection. |
| `allowsExpensiveNetworkAccess` | `Bool` | `true` | `true` | When `false`, requests are not sent over expensive network interfaces (e.g., hotspot). Available macOS 10.15+; no availability guard needed at macOS 14+. |
| `allowsConstrainedNetworkAccess` | `Bool` | `true` | `true` | When `false`, requests are not sent when Low Data Mode is active. Available macOS 10.15+; no availability guard needed at macOS 14+. |
| `httpShouldHandleCookies` | `Bool` | `true` | `true` | When `false`, the URL loading system does not send or accept cookies for this request. |

All properties are `let` — immutable after construction (FR-006).

#### Initialisers

```swift
public init(
    timeoutInterval: TimeInterval = 60.0,
    cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
    allowsCellularAccess: Bool = true,
    allowsExpensiveNetworkAccess: Bool = true,
    allowsConstrainedNetworkAccess: Bool = true,
    httpShouldHandleCookies: Bool = true
)
```

All parameters have defaults matching `URLRequest` platform defaults (FR-003,
Decision 4). Callers can supply zero arguments (for the built-in default), one
argument (to override a single property), or any combination.

#### Static Constants

```swift
public static let `default` = Configuration()
```

The canonical built-in default instance (FR-003). Used as the default parameter
value on `DefaultHTTPClient.init`: `configuration: DefaultHTTPClient.Configuration = .default`.
The backtick escaping is required in the declaration because `default` is a Swift
keyword; call sites use the clean member-access form `.default` without backticks.

#### Concurrency

`DefaultHTTPClient.Configuration` is a value type with all-`let` stored properties. It is
`Sendable` by synthesis. Passing the same configuration value to multiple
simultaneous engines or request calls is safe: each engine receives its own copy
(value semantics), so no shared mutable state exists between concurrent uses
(FR-010, A-05, A-06, research Decision 2).

---

## Changed Public Types

### `HTTPClient` (updated protocol)

**Kind**: `public protocol`
**Conforms to**: `Sendable`
**Location**: `Sources/HTTPClientLib/HTTPClient.swift`
**Spec ref**: FR-007, FR-008, A-07

`HTTPClient` is the decoupled public surface. It defines request methods and convenience
overloads while remaining implementation-agnostic.

### `DefaultHTTPClient` (updated default implementation)

**Kind**: `public struct`
**Conforms to**: `HTTPClient`, `Sendable` (synthesised)
**Location**: `Sources/HTTPClientLib/Implementation/DefaultHTTPClient.swift`
**Spec ref**: FR-004, FR-005, FR-009, A-07, A-09

#### Removed from Public API (BREAKING — requires MAJOR version bump, A-09)

| Removed item | Was | Impact |
|-------------|-----|--------|
| `RequestConfigurator` typealias | `public typealias RequestConfigurator = @Sendable (inout URLRequest) -> Void` | Callers that reference this typealias by name will not compile. |
| `configurator` stored property | `public let configurator: RequestConfigurator?` | Callers that read `engine.configurator` will not compile. |
| `configurator` init parameter | `configurator: RequestConfigurator? = nil` in `init` | Callers that pass `configurator:` to the init will not compile. |

#### Updated Stored Properties

| Property | Type | Notes |
|----------|------|-------|
| `session` | `URLSession` | Unchanged from Feature 002. |
| `configuration` | `Configuration` | **NEW** — engine-level transport configuration (FR-004, A-03). |
| `defaultHeaders` | `[String: String]` | Unchanged from Feature 002. |

#### Updated Initialiser

```swift
public init(
    session: URLSession = .shared,
    configuration: Configuration = .default,
    defaultHeaders: [String: String]? = nil
)
```

The `configurator: RequestConfigurator? = nil` parameter is removed and replaced
by `configuration: Configuration = .default`. All init call sites that do not
supply either parameter compile unchanged (FR-009 / A-08).

#### Required HTTPClient Method Signatures (updated)

HTTP method signatures now include an additive optional
`progress: SupportLib.Progress?` parameter. Configuration remains applied uniformly
via the engine's stored `configuration` property (not via per-request configuration
parameters). Existing call sites remain source-compatible by passing no `progress`:

| Method | Signature |
|--------|-----------|
| GET | `get(_ url: URL, headers: [String: String]? = nil, progress: SupportLib.Progress? = nil) async throws -> HTTPResponse` |
| POST (body) | `post(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil, progress: SupportLib.Progress? = nil) async throws -> HTTPResponse` |
| POST (multipart) | `post(_ url: URL, formItems: [FormItem], headers: [String: String]? = nil, progress: SupportLib.Progress? = nil) async throws -> HTTPResponse` |
| PUT | `put(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil, progress: SupportLib.Progress? = nil) async throws -> HTTPResponse` |
| DELETE | `delete(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil, progress: SupportLib.Progress? = nil) async throws -> HTTPResponse` |

#### Convenience Overloads (additive protocol extension surface)

`HTTPClient` includes convenience overloads in a `public extension` that forward
to the required signatures above:

| Method | Signature |
|--------|-----------|
| GET | `get(_ url: URL) async throws -> HTTPResponse` |
| POST (body only) | `post(_ url: URL, body: RequestBody) async throws -> HTTPResponse` |
| POST (headers only) | `post(_ url: URL, headers: [String: String]) async throws -> HTTPResponse` |
| POST (no body, no headers) | `post(_ url: URL) async throws -> HTTPResponse` |
| PUT (body only) | `put(_ url: URL, body: RequestBody) async throws -> HTTPResponse` |
| PUT (headers only) | `put(_ url: URL, headers: [String: String]) async throws -> HTTPResponse` |
| PUT (no body, no headers) | `put(_ url: URL) async throws -> HTTPResponse` |
| POST multipart (no headers) | `post(_ url: URL, formItems: [FormItem]) async throws -> HTTPResponse` |
| DELETE (body only) | `delete(_ url: URL, body: RequestBody) async throws -> HTTPResponse` |
| DELETE (headers only) | `delete(_ url: URL, headers: [String: String]) async throws -> HTTPResponse` |
| DELETE (no body, no headers) | `delete(_ url: URL) async throws -> HTTPResponse` |

These do not add conformance requirements for custom `HTTPClient` types.

#### Updated `dispatch` (private helper)

The internal `dispatch` method uses `self.configuration` (the stored engine
property) rather than a per-call parameter:

```swift
private func dispatch(
    url: URL,
    method: HTTPMethod,
    headers: [String: String]?,
    body: RequestBody? = nil
) async throws -> HTTPResponse
```

---

## Changed Internal Types

### `RequestBuilder` (updated)

**Kind**: `internal enum` (set of `static` functions)
**Location**: `Sources/HTTPClientLib/Internal/RequestBuilder.swift`
**Spec ref**: FR-005, FR-007, FR-009, A-07

#### Updated signature

```swift
static func buildRequest(
    url: URL,
    method: HTTPMethod,
    headers: [String: String]?,
    body: RequestBody?,
    configuration: DefaultHTTPClient.Configuration,   // replaces configurator: RequestConfigurator?
    defaultHeaders: [String: String]
) throws -> URLRequest
```

The `configurator: RequestConfigurator?` parameter is removed. The
`configuration: DefaultHTTPClient.Configuration` parameter is added.

#### Updated assembly steps

The old 4-step assembly (Steps 1–4) becomes a new 4-step assembly with a different
Step 1 and the removal of the old Step 4 (configurator):

| Step | Action | Priority |
|------|--------|----------|
| 1 (new) | Apply `configuration` properties to `URLRequest` | URLRequest transport settings (before headers and body) |
| 2 | Apply `defaultHeaders` | Lowest header-priority tier (unchanged from Feature 002) |
| 3 | Apply per-request `headers` argument | Overwrites conflicting defaults (unchanged from Feature 002) |
| 4 | Apply library `Content-Type` + `httpBody` | Highest header-priority tier (unchanged from Feature 002) |

Step 1 applies configuration properties in order:
```
request.timeoutInterval              = configuration.timeoutInterval
request.cachePolicy                  = configuration.cachePolicy
request.allowsCellularAccess         = configuration.allowsCellularAccess
request.allowsExpensiveNetworkAccess = configuration.allowsExpensiveNetworkAccess
request.allowsConstrainedNetworkAccess = configuration.allowsConstrainedNetworkAccess
request.httpShouldHandleCookies      = configuration.httpShouldHandleCookies
```

No reordering within this group is semantically significant; all six assignments are
independent.

---

## Changed Inline Assembly (Multipart Path)

`HTTPClient.post(_:formItems:headers:)` assembles its `URLRequest` inline. The
inline block is updated to:

1. Apply `self.configuration` properties (new Step 1)
2. Apply `self.defaultHeaders` (step 2, unchanged)
3. Apply per-request `headers` (step 3, unchanged)
4. Apply multipart `Content-Type` (step 4, unchanged)
5. Remove the old `self.configurator?(&request)` call

---

## Removed Public API

| Symbol | Kind | Reason |
|--------|------|--------|
| `RequestConfigurator` | `public typealias` | Superseded by `DefaultHTTPClient.Configuration` (FR-008) |
| `HTTPClient.configurator` | `public let` stored property | Superseded; see Decision 6 |

---

## Unchanged Types

The following types are unaffected by this feature:

- `HTTPResponse` — no change
- `RequestBody` — no change
- `FormItem` — no change
- `HTTPClientError` — no change (no new error cases)
- `MultipartEncoder` (internal) — no change
- `HTTPMethod` (internal) — no change

---

## New Source File

| File | Description |
|------|-------------|
| `Sources/HTTPClientLib/Implementation/DefaultHTTPClient+Configuration.swift` | `public extension DefaultHTTPClient { struct Configuration ... }` |

---

## Updated Source Files

| File | Change summary |
|------|---------------|
| `Sources/HTTPClientLib/Implementation/DefaultHTTPClient.swift` | Remove `RequestConfigurator` typealias path usage and `configurator` init support; add `configuration: Configuration = .default` to `DefaultHTTPClient.init`; store as `public let configuration: Configuration`; apply via `self.configuration` in `dispatch` and inline multipart path |
| `Sources/HTTPClientLib/Internal/RequestBuilder.swift` | Replace `configurator: RequestConfigurator?` with `configuration: DefaultHTTPClient.Configuration`; apply configuration properties at Step 1; remove Step 4 configurator callback |

---

## New Test Suite

### `HTTPClientConfigurationTests`

**Kind**: Swift Testing `@Suite`
**Location**: `Tests/HTTPClientLibTests/HTTPClientConfigurationTests.swift` *(new file)*
**Spec ref**: All US1–US4 acceptance scenarios + edge cases

| Test | Scenario | Spec ref |
|------|----------|----------|
| `defaultConfigurationIsAppliedWhenNoArgumentSupplied` | Engine init with no config arg; GET request; URLRequest has `timeoutInterval` = 60.0 | US1-AC-1 |
| `defaultConfigurationMatchesPlatformDefaults` | All 6 properties of `.default` match URLRequest platform defaults | US1-AC-2 |
| `existingCallSitesUnchangedWithDefaultConfig` | Engine with no config; all HTTP methods; captured requests carry default property values | US1-AC-3 |
| `customTimeoutAppliedToRequest` | `DefaultHTTPClient(configuration: .init(timeoutInterval: 120.0))` GET; captured request has `timeoutInterval` = 120.0 | US2-AC-1 |
| `customCachePolicyAppliedToRequest` | `DefaultHTTPClient(configuration: .init(cachePolicy: .reloadIgnoringLocalCacheData))` POST; captured request has matching cache policy | US2-AC-2 |
| `cellularAccessDisabledAppliedToRequest` | `DefaultHTTPClient(configuration: .init(allowsCellularAccess: false))` GET; captured request disallows cellular | US2-AC-3 |
| `expensiveNetworkAccessDisabledAppliedToRequest` | `DefaultHTTPClient(configuration: .init(allowsExpensiveNetworkAccess: false))` GET; captured request reflects restriction | US2-AC-4 |
| `constrainedNetworkAccessDisabledAppliedToRequest` | `DefaultHTTPClient(configuration: .init(allowsConstrainedNetworkAccess: false))` GET; captured request reflects restriction | US2-AC-5 |
| `cookieHandlingDisabledAppliedToRequest` | `DefaultHTTPClient(configuration: .init(httpShouldHandleCookies: false))` GET; captured request has `httpShouldHandleCookies` = false | US2-AC-6 |
| `multiplePropertiesAllAppliedSimultaneously` | Engine with non-default timeout + cache policy + cellular=false; all three reflected in captured request | US2-AC-7 |
| `configurationIsolatedAcrossSequentialRequests` | Engine with custom timeout; two sequential requests; both captured requests carry same custom timeout | US3-AC-1 |
| `configurationValueNotMutatedByRequestCall` | Same config used to init engine; two calls later config properties unchanged | US3-AC-2 |
| `concurrentRequestsCarryOwnConfiguration` | Two engines with different configs; concurrent requests; each captured request carries its engine's settings | US3-AC-3 |
| `configurationDoesNotOverrideHTTPMethod` | Config with any non-default property; captured method is exactly what engine assembled | US4-AC-1 |
| `configurationDoesNotOverrideURL` | Config with any non-default property; captured URL is the URL passed to the method | US4-AC-2 |
| `configurationDoesNotOverrideHTTPBody` | Config + body; captured body is exactly the encoded body; no config property interferes | US4-AC-1 |
| `configurationDoesNotOverrideCallerHeaders` | Config + per-request headers; captured request carries per-request headers untouched | US4-AC-1 |
| `configurationAppliedToPostBodyRequest` | Custom config on engine; `post(_:body:headers:)` request; config properties reflected | US2 (POST) |
| `configurationAppliedToMultipartPostRequest` | Custom config on engine; `post(_:formItems:headers:)` request; config properties reflected | US2 (multipart) |
| `configurationAppliedToPutRequest` | Custom config on engine; `put(_:body:headers:)` request; config properties reflected | US2 (PUT) |
| `configurationAppliedToDeleteRequest` | Custom config on engine; `delete(_:body:headers:)` request; config properties reflected | US2 (DELETE) |

### Migrated Tests (modified, not new)

| File | Test | Migration |
|------|------|-----------|
| `HTTPClientGetTests.swift` | `configuratorMutatesRequestBeforeDispatch` | Renamed to `customTimeoutAppliedViaConfiguration`; migrated to `DefaultHTTPClient(session: session, configuration: DefaultHTTPClient.Configuration(timeoutInterval: 42))` |
| `HTTPClientPostTests.swift` | `configuratorIsInvokedForPostRequests` | Renamed to `perRequestHeadersAppliedToPostRequest`; migrated to `headers: ["X-Injected": "injected-value"]` on `post` call (capability unchanged; API surface changes) |

---

## Type Relationships (updated)

```
HTTPClient
  ├── holds → URLSession                (Foundation — injected or .shared)
  ├── holds → configuration: Configuration      ← NEW stored property (engine-level)
  ├── holds → defaultHeaders: [String: String]   (immutable; unchanged from Feature 002)
  ├── delegates assembly to → RequestBuilder (internal)
  │     ├── receives → configuration: DefaultHTTPClient.Configuration   ← NEW parameter
  │     ├── receives → defaultHeaders: [String: String]          (unchanged)
  │     ├── produces → URLRequest (4-step assembly; see below)
  │     ├── encodes  → RequestBody       (.text / .binary / .json)
  │     └── delegates multipart to → MultipartEncoder (internal)
  │           └── consumes → [FormItem] (.file / .data / .property)
  ├── dispatches via → URLSession.data(for:delegate:)
  └── returns → HTTPResponse            (.statusCode + .body)

DefaultHTTPClient.Configuration (NEW — nested via public extension)
  ├── carries → timeoutInterval: TimeInterval
  ├── carries → cachePolicy: URLRequest.CachePolicy
  ├── carries → allowsCellularAccess: Bool
  ├── carries → allowsExpensiveNetworkAccess: Bool
  ├── carries → allowsConstrainedNetworkAccess: Bool
  ├── carries → httpShouldHandleCookies: Bool
  └── provides → static let default: Configuration   (all platform defaults)

URLRequest assembly order (new, 4 steps):
  Step 1: DefaultHTTPClient.Configuration properties (transport-level settings)
  Step 2: defaultHeaders (header priority tier 1 — lowest)
  Step 3: per-request headers (header priority tier 2)
  Step 4: library Content-Type + httpBody (header priority tier 3 — highest)

REMOVED:
  RequestConfigurator typealias → removed (FR-008)
  HTTPClient.configurator → removed (FR-008, breaking change, MAJOR version bump)
```
