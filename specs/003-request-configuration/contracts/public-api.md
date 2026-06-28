# Public API Contract: Request Configuration Struct

**Feature**: `003-request-configuration` | **Date**: 2026-06-28 | **Phase 1**

This document is the authoritative delta-contract for the public API changes
introduced by Feature 003. It supersedes the corresponding sections of
`specs/002-configurable-headers/contracts/public-api.md` (and, transitively,
`specs/001-http-engine-library/contracts/public-api.md`) where they conflict.
All types and signatures not listed here remain exactly as specified in the
Feature 002 contract.

**⚠ BREAKING CHANGE**: This feature removes public API symbols. All callers that
reference `RequestConfigurator` by name or pass `configurator:` to `HTTPClient.init`
will not compile. This change MUST be accompanied by a **MAJOR version bump** from
`0.0.1` (pre-release) to `1.0.0`. See governance notes at the end of this document.

---

## Module

```swift
import HTTPLib
```

---

## New Type: `HTTPClient.Configuration`

```swift
public extension HTTPClient {
    struct Configuration: Sendable {

        public let timeoutInterval: TimeInterval
        public let cachePolicy: URLRequest.CachePolicy
        public let allowsCellularAccess: Bool
        public let allowsExpensiveNetworkAccess: Bool
        public let allowsConstrainedNetworkAccess: Bool
        public let httpShouldHandleCookies: Bool

        public init(
            timeoutInterval: TimeInterval = 60.0,
            cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
            allowsCellularAccess: Bool = true,
            allowsExpensiveNetworkAccess: Bool = true,
            allowsConstrainedNetworkAccess: Bool = true,
            httpShouldHandleCookies: Bool = true
        )

        public static let `default`: Configuration
    }
}
```

**Semantics**:
- All properties are immutable after construction (no setters exist — FR-006).
- `HTTPClient.Configuration.default` is the built-in zero-argument instance whose
  property values match `URLRequest` platform defaults (FR-003, A-04).
- Value type semantics: an `HTTPClient.Configuration` value is copied, not referenced,
  when passed to an initialiser or stored. Concurrent use of the same value from
  multiple tasks is safe without any synchronisation (FR-010, A-05).
- No validation is performed on property values (e.g., negative `timeoutInterval`);
  the value is passed through to `URLRequest` directly and platform-defined
  behaviour applies (spec edge cases).

---

## Changed Type: `HTTPClient`

### Removed from public API (breaking)

```swift
// REMOVED — no longer part of public API after this feature
public typealias RequestConfigurator = @Sendable (inout URLRequest) -> Void
public let configurator: RequestConfigurator?
// init parameter 'configurator: RequestConfigurator? = nil' also removed
```

### Updated initialiser

```swift
public init(
    session: URLSession = .shared,
    configuration: Configuration = .default,
    defaultHeaders: [String: String]? = nil
)
```

**Change**: The `configurator: RequestConfigurator? = nil` parameter is removed and
replaced by `configuration: Configuration = .default`. All existing call sites that
do not supply `configurator:` or `configuration:` compile unchanged.

### Updated stored properties

```swift
public let session: URLSession                  // unchanged
public let configuration: Configuration         // NEW — engine-level transport config
public let defaultHeaders: [String: String]     // unchanged
// configurator: RequestConfigurator?  — REMOVED
```

### HTTP method signatures (unchanged)

HTTP method signatures are **not changed** by this feature. Configuration is applied
uniformly via the engine's stored `configuration` property. All existing call sites
compile unchanged:

```swift
// GET
public func get(
    _ url: URL,
    headers: [String: String]? = nil
) async throws -> HTTPResponse

// POST with optional body
public func post(
    _ url: URL,
    body: RequestBody? = nil,
    headers: [String: String]? = nil
) async throws -> HTTPResponse

// POST multipart
public func post(
    _ url: URL,
    formItems: [FormItem],
    headers: [String: String]? = nil
) async throws -> HTTPResponse

// PUT
public func put(
    _ url: URL,
    body: RequestBody? = nil,
    headers: [String: String]? = nil
) async throws -> HTTPResponse

// DELETE
public func delete(
    _ url: URL,
    body: RequestBody? = nil,
    headers: [String: String]? = nil
) async throws -> HTTPResponse
```

---

## Behavioural Guarantees

### URLRequest assembly order (updated — 4 steps, replaces Feature 002's 4-step)

The following order applies to every request dispatched through `HTTPClient`,
for all HTTP methods including multipart POST:

| Step | Action | Notes |
|------|--------|-------|
| 1 (new) | Apply `HTTPClient.Configuration` properties | `timeoutInterval`, `cachePolicy`, `allowsCellularAccess`, `allowsExpensiveNetworkAccess`, `allowsConstrainedNetworkAccess`, `httpShouldHandleCookies` applied from `self.configuration` |
| 2 | Apply `HTTPClient.defaultHeaders` | Header priority tier 1 — lowest (unchanged from Feature 002) |
| 3 | Apply per-request `headers` argument | Header priority tier 2 — overwrites conflicting defaults (unchanged from Feature 002) |
| 4 | Apply library `Content-Type` + `httpBody` | Header priority tier 3 — highest; applied only when the request body requires it (unchanged from Feature 002) |

**The old Step 4 (RequestConfigurator callback) is removed** — this is the breaking
change. Open-ended request mutation is no longer part of the API.

### Configuration consistency

Every request dispatched through an `HTTPClient` instance receives that engine's
stored `configuration`. The engine does not accept per-request configuration
overrides on individual method calls. Callers that need different transport settings
for different requests should create separate `HTTPClient` instances with distinct
configurations (FR-010, A-06, US3).

### Engine property precedence

`HTTPClient.Configuration` properties target `URLRequest` transport settings
(`timeoutInterval`, `cachePolicy`, network-access flags, cookie handling).
Engine-managed properties (`httpMethod`, URL, `httpBody`, `Content-Type` for encoded
bodies) target different `URLRequest` fields and are applied after Step 1;
they are never overridden by the configuration struct (FR-007, A-07).

### Backward-compatibility guarantees

Existing code that constructs `HTTPClient` without `configurator:` or `configuration:`:

```swift
HTTPClient()
HTTPClient(session: mySession)
HTTPClient(defaultHeaders: ["Authorization": "Bearer token"])
HTTPClient(session: mySession, defaultHeaders: ["X-Client": "MyApp"])
```

and calls any HTTP method:

```swift
let r = try await engine.get(url)
let r = try await engine.post(url, body: .json(model))
let r = try await engine.post(url, headers: ["Accept": "application/json"])
```

all compile and behave identically to the pre-Feature-003 baseline. The
`configuration` init parameter is fully additive (FR-009, A-08).

**Breaking call sites** that must be migrated:

```swift
// ── Before Feature 003 ────────────────────────────────────────────────────
HTTPClient(configurator: { $0.timeoutInterval = 30 })
HTTPClient(session: s, configurator: { $0.timeoutInterval = 30 })
HTTPClient(configurator: myConfiguratorClosure)

// ── After Feature 003 ─────────────────────────────────────────────────────
// Option 1: engine-level configuration (all requests through this engine)
let engine = HTTPClient(configuration: HTTPClient.Configuration(timeoutInterval: 30))
let r = try await engine.get(url)

// Option 2: compose with default headers
let apiEngine = HTTPClient(
    configuration: HTTPClient.Configuration(timeoutInterval: 30),
    defaultHeaders: ["Authorization": "Bearer token"]
)

// Option 3: arbitrary header injection previously done via configurator
// → use the 'headers:' parameter or HTTPClient(defaultHeaders:) instead
let engine = HTTPClient(defaultHeaders: ["X-My-Header": "value"])
```

---

## Usage examples

```swift
// ── Zero-config: all defaults, call site unchanged ─────────────────────────
let engine = HTTPClient()
let response = try await engine.get(url)

// ── Custom timeout for a slow endpoint ────────────────────────────────────
let engine = HTTPClient(configuration: HTTPClient.Configuration(timeoutInterval: 120.0))
let response = try await engine.get(slowUrl)

// ── Reload bypassing cache ─────────────────────────────────────────────────
let engine = HTTPClient(configuration: HTTPClient.Configuration(cachePolicy: .reloadIgnoringLocalCacheData))
let response = try await engine.get(url)

// ── Restrict to non-cellular networks ─────────────────────────────────────
let engine = HTTPClient(configuration: HTTPClient.Configuration(allowsCellularAccess: false))
let response = try await engine.post(url, body: .json(payload))

// ── Multiple non-default properties ───────────────────────────────────────
let strictEngine = HTTPClient(configuration: HTTPClient.Configuration(
    timeoutInterval: 10.0,
    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
    allowsCellularAccess: false,
    httpShouldHandleCookies: false
))
let response = try await strictEngine.get(url)

// ── Default headers at engine level + configuration (compose) ─────────────
let apiEngine = HTTPClient(
    configuration: HTTPClient.Configuration(timeoutInterval: 5.0),
    defaultHeaders: ["Authorization": "Bearer token"]
)
let response = try await apiEngine.get(url)
// Outbound request carries both "Authorization" header AND 5-second timeout

// ── Zero-config multipart POST (unchanged call site) ──────────────────────
let formItems: [FormItem] = [.property(name: "field", value: "hello")]
let response = try await engine.post(url, formItems: formItems)
```

---

## Stability Policy & Governance

**Version at merge**: `1.0.0` — this is the **first stable public release** of
HTTPLib. The transition from `0.0.1` (pre-release) to `1.0.0` is triggered by the
removal of `RequestConfigurator` and `HTTPClient.configurator`, which constitutes
a breaking public API change per the constitution's governance policy.

From `1.0.0` onwards, the constitution's governance rules apply in full:
- Any removal or incompatible change to a type or signature listed in this document
  requires a MAJOR version bump.
- Additive changes (new types, new optional parameters with defaults) may be
  MINOR bumps.
- No breaking changes are permitted without documentation, justification, and a
  version bump.
