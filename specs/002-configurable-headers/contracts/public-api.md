# Public API Contract: Configurable Default Headers

**Feature**: `002-configurable-headers` | **Date**: 2026-06-28 | **Phase 1**

This document is the authoritative delta-contract for the public API changes
introduced by Feature 002. It supersedes the corresponding sections of
`specs/001-http-engine-library/contracts/public-api.md` where they conflict.
All types and signatures not listed here remain exactly as specified in the
Feature 001 contract.

Breaking changes to any signature, type, or semantic guarantee listed here MUST
be accompanied by a MAJOR version bump in `Package.swift` per the project
constitution's governance policy.

---

## Module

```swift
import HTTPLib
```

---

## Changed Type: `HTTPEngine`

### Updated initialiser

```swift
public init(
    session: URLSession = .shared,
    configurator: RequestConfigurator? = nil,
    defaultHeaders: [String: String]? = nil
)
```

**Change**: `defaultHeaders: [String: String]? = nil` is added as a new optional
parameter. All existing call sites that omit this parameter compile unchanged (fully
backward-compatible).

**Semantics**:
- When `defaultHeaders` is `nil` or `[:]`, engine behaviour is identical to the
  pre-feature baseline (FR-001).
- When `defaultHeaders` is non-empty, every request dispatched through this engine
  automatically includes those headers at the lowest priority tier (FR-002).
- Default headers are immutable after construction — no setter or mutating method
  is provided (FR-007).

### Updated stored property

```swift
public let defaultHeaders: [String: String]
```

Read-only. Value is `[:]` when the init argument was `nil` or `[:]`.

### Unchanged HTTP method signatures

All of the following signatures are **identical** to Feature 001 (FR-008):

```swift
public func get(
    _ url: URL,
    headers: [String: String]? = nil
) async throws -> HTTPResponse

public func post(
    _ url: URL,
    body: RequestBody? = nil,
    headers: [String: String]? = nil
) async throws -> HTTPResponse

public func post(
    _ url: URL,
    formItems: [FormItem],
    headers: [String: String]? = nil
) async throws -> HTTPResponse

public func put(
    _ url: URL,
    body: RequestBody? = nil,
    headers: [String: String]? = nil
) async throws -> HTTPResponse

public func delete(
    _ url: URL,
    body: RequestBody? = nil,
    headers: [String: String]? = nil
) async throws -> HTTPResponse
```

---

## Updated Behavioural Guarantees

### Header priority (updated — 4 tiers)

The following order applies to every request dispatched through `HTTPEngine`,
for all HTTP methods including multipart POST:

| Priority | Source | Rule |
|----------|--------|------|
| 1 (lowest) | `HTTPEngine.defaultHeaders` | Applied first; establishes the baseline for this request. |
| 2 | Per-request `headers` argument | Applied second; overwrites any conflicting default (FR-004). |
| 3 | Library-required headers (e.g., `Content-Type` for body encoding) | Applied third; overwrites any conflicting caller or default value (FR-005). |
| 4 (highest) | `RequestConfigurator` callback | Applied last; any mutations are final. |

**Conflict detection is case-insensitive** for all four tiers. A default header
`content-type: text/plain` and a per-request header `Content-Type: application/json`
are treated as the same field; the per-request value prevails (A-03, US3-AC-3).

**The stored default headers are never mutated** by request dispatch. Each call
begins from the same `defaultHeaders` base (FR-007, A-02).

### Backward-compatibility guarantee

Existing code that constructs `HTTPEngine` without `defaultHeaders`:

```swift
HTTPEngine()
HTTPEngine(session: mySession)
HTTPEngine(configurator: myConfigurator)
HTTPEngine(session: mySession, configurator: myConfigurator)
```

compiles and behaves identically to the pre-feature baseline. No source-level
changes are required at existing call sites (SC-003, FR-001, FR-008).

---

## Unchanged Behavioural Guarantees (from Feature 001)

The following guarantees are inherited unchanged:

- Concurrency: all methods are `async`; `Task.checkCancellation()` is called at
  entry before any work; `CancellationError` propagates directly (never wrapped).
- Non-throwing status codes: 1xx–5xx HTTP status codes are returned in
  `HTTPResponse.statusCode`, never thrown.
- GET body restriction: `get(_:headers:)` accepts no body parameter.
- Error contract: failures surface as `HTTPEngineError` (except `CancellationError`).

---

## Minimal usage examples (updated)

```swift
// ── Pre-feature baseline (unchanged) ──────────────────────────────────────
let engine = HTTPEngine()
let response = try await engine.get(url)

// ── Default headers configured at construction ─────────────────────────────
let apiEngine = HTTPEngine(defaultHeaders: [
    "X-API-Key":    "abc123",
    "X-Client-App": "MyApp/1.0"
])

// Default headers appear automatically on every request
let getResponse  = try await apiEngine.get(url)
let postResponse = try await apiEngine.post(url, body: .json(myModel))

// ── Per-request headers merge with defaults ────────────────────────────────
// Both "X-API-Key" (default) and "Accept" (per-request) appear in the request
let response = try await apiEngine.get(url, headers: ["Accept": "application/json"])

// ── Per-request overrides a default on conflict ────────────────────────────
// Outbound request carries "Authorization: scoped-token" for this call only
let scoped = try await apiEngine.get(url, headers: ["Authorization": "scoped-token"])
// Immediately after, the stored default is unaffected (A-02)
let full = try await apiEngine.get(url)  // carries the original default "X-API-Key"

// ── Library headers override conflicting defaults ─────────────────────────
// Even if defaultHeaders contains "Content-Type: text/xml", a JSON body
// results in "Content-Type: application/json" in the outbound request (FR-005)
let strictEngine = HTTPEngine(defaultHeaders: ["Content-Type": "text/xml"])
let jsonResponse = try await strictEngine.post(url, body: .json(myModel))
// ↑ outbound Content-Type == "application/json" (library wins, FR-005)

// ── All init parameters together ──────────────────────────────────────────
let fullEngine = HTTPEngine(
    session:        customSession,
    configurator:   { $0.timeoutInterval = 10 },
    defaultHeaders: ["Authorization": "Bearer token"]
)
```

---

## Stability policy

This API surface is at version **0.0.1** (pre-release), consistent with Feature 001.
The `defaultHeaders` addition is additive and non-breaking. Upon `1.0.0`, the
governance rules in `constitution.md` apply.
