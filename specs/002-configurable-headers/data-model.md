# Data Model: Configurable Default Headers

**Feature**: `002-configurable-headers` | **Date**: 2026-06-28 | **Phase 1**

See `research.md` for the rationale behind each design decision referenced below.
All types not listed here are **unchanged** from Feature 001
(`specs/001-http-engine-library/data-model.md`).

---

## Changed Public Types

### `HTTPEngine` (updated)

**Kind**: `public struct`
**Conforms to**: `Sendable` (synthesised — all stored properties are `let` and `Sendable`)
**Location**: `Sources/HTTPLib/HTTPEngine.swift`
**Spec ref**: FR-001, FR-002, FR-004, FR-005, FR-006, FR-007, FR-008, A-01–A-06

#### Stored Properties

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `session` | `URLSession` | `.shared` | Unchanged from Feature 001. |
| `configurator` | `RequestConfigurator?` | `nil` | Unchanged from Feature 001. |
| `defaultHeaders` | `[String: String]` | `[:]` | **NEW.** Populated at init; `nil` init argument normalised to `[:]`. Immutable after construction (FR-007). Merged into every outbound request as the lowest-priority header tier (FR-002, FR-004). |

#### Initialiser (updated)

```swift
public init(
    session: URLSession = .shared,
    configurator: RequestConfigurator? = nil,
    defaultHeaders: [String: String]? = nil
)
```

The `defaultHeaders` parameter is optional with a `nil` default, preserving full
backward compatibility with all existing call sites (FR-001, FR-008, SC-003).
Internally: `self.defaultHeaders = defaultHeaders ?? [:]`.

#### Operations

All HTTP method operations are **unchanged** (FR-008). Their signatures are repeated
here for completeness only.

| Method | Signature | Body | Spec ref |
|--------|-----------|------|----------|
| GET | `get(_ url: URL, headers: [String: String]? = nil)` | None | Unchanged |
| POST | `post(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil)` | Optional | Unchanged |
| POST multipart | `post(_ url: URL, formItems: [FormItem], headers: [String: String]? = nil)` | `[FormItem]` | Unchanged |
| PUT | `put(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil)` | Optional | Unchanged |
| DELETE | `delete(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil)` | Optional | Unchanged |

#### Header Merge Semantics

For every request dispatched through this instance, headers are merged in four steps
(research Decision 3):

| Step | Source | Priority | Notes |
|------|--------|----------|-------|
| 1 | `self.defaultHeaders` | Lowest | Applied first; establishes the baseline. |
| 2 | Per-request `headers` argument | Medium | Overwrites any conflicting default (FR-004). |
| 3 | Library-required headers (e.g., `Content-Type`) | High | Overwrites both; applies only when a body variant requires it (FR-005). |
| 4 | `RequestConfigurator` callback | Highest | Runs last; any mutation it applies is final (FR-011, unchanged from Feature 001). |

Conflict detection is case-insensitive; `URLRequest.setValue(_:forHTTPHeaderField:)`
implements this contract at the Foundation level — no custom case-folding is required
(research Decision 4, A-03).

#### Concurrency & Lifecycle

`defaultHeaders` is a `let` property fixed at init; it is never mutated after
construction. This makes concurrent calls on the same `HTTPEngine` instance from
multiple `Task`s safe with respect to the default headers value (A-02, A-04).
All other concurrency guarantees from Feature 001 are unchanged.

---

## Changed Internal Types

### `RequestBuilder` (updated)

**Kind**: `internal enum` (set of `static` functions)
**Location**: `Sources/HTTPLib/Internal/RequestBuilder.swift`
**Spec ref**: FR-002, FR-004, FR-005, FR-009, FR-011

#### Updated signature

```swift
static func buildRequest(
    url: URL,
    method: HTTPMethod,
    headers: [String: String]?,
    body: RequestBody?,
    configurator: RequestConfigurator?,
    defaultHeaders: [String: String]         // NEW parameter
) throws -> URLRequest
```

The new `defaultHeaders` parameter is always passed from `HTTPEngine.dispatch(...)`.
When `HTTPEngine.defaultHeaders` is empty (`[:]`), step 1 is a no-op; the resulting
`URLRequest` is identical to what Feature 001 produced.

#### Updated header-assembly steps

```
Step 1 — defaultHeaders applied first (lowest priority)
Step 2 — per-request caller headers (overwrite step 1 conflicts)
Step 3 — library Content-Type for body encoding (overwrite steps 1–2 conflicts)
Step 4 — RequestConfigurator callback (runs last — FR-011)
```

Steps 2–4 are unchanged from Feature 001.

---

## Changed Inline Assembly (Multipart Path)

The `HTTPEngine.post(_:formItems:headers:)` method assembles a `URLRequest` inline
(not via `RequestBuilder`). This inline block is updated to apply the same four-step
merge:

```
Step 1 — self.defaultHeaders applied first
Step 2 — per-request caller headers
Step 3 — library multipart Content-Type (overwrites step 1–2 conflicts)
Step 4 — self.configurator callback
```

This change is internal to `HTTPEngine`; the method's public signature is unchanged
(FR-008). See research Decision 5 for rationale.

---

## Unchanged Types

The following types are unaffected by this feature and are specified in full in
`specs/001-http-engine-library/data-model.md`:

- `HTTPResponse` — no change
- `RequestBody` — no change
- `FormItem` — no change
- `HTTPEngineError` — no change (no new error cases)
- `RequestConfigurator` — no change
- `MultipartEncoder` (internal) — no change

---

## Type Relationships (updated)

```
HTTPEngine
  ├── holds → URLSession                (Foundation — injected or .shared)
  ├── holds → RequestConfigurator?      (typealias for @Sendable closure)
  ├── holds → defaultHeaders: [String: String]   ← NEW (immutable, empty when nil passed)
  ├── delegates assembly to → RequestBuilder (internal)
  │     ├── receives → defaultHeaders          ← NEW parameter
  │     ├── produces → URLRequest (4-step header merge)
  │     ├── encodes → RequestBody       (.text / .binary / .json)
  │     └── delegates multipart to → MultipartEncoder (internal)
  │           └── consumes → [FormItem] (.file / .data / .property)
  ├── dispatches via → URLSession.data(for:delegate:)
  └── returns → HTTPResponse            (.statusCode + .body)

Header merge order (lowest → highest priority):
  defaultHeaders → per-request headers → library Content-Type → RequestConfigurator
```

---

## New Test Entity

### `HTTPEngineDefaultHeaderTests`

**Kind**: Swift Testing `@Suite`
**Location**: `Tests/HTTPLibTests/HTTPEngineDefaultHeaderTests.swift`
**Spec ref**: All US1/US2/US3 acceptance scenarios + edge cases

| Test | Scenario | Spec ref |
|------|----------|----------|
| `defaultHeadersAppliedToGetRequest` | Engine with default headers; GET; outbound request contains default headers | US1-AC-1 |
| `defaultHeadersAppliedToPostRequest` | Engine with default headers; POST; outbound request contains default headers | US1-AC-2 |
| `defaultHeadersAppliedToPutRequest` | Engine with default headers; PUT; outbound request contains default headers | US1-AC-2 |
| `defaultHeadersAppliedToDeleteRequest` | Engine with default headers; DELETE; outbound request contains default headers | US1-AC-2 |
| `emptyDefaultHeadersAddsNoHeaders` | Engine with empty `[:]`; any request; no unexpected headers added | US1-AC-3 |
| `nilDefaultHeadersMatchesBaseline` | Engine with no `defaultHeaders` arg; any request; identical to pre-feature baseline | US1-AC-4 |
| `defaultAndPerRequestHeadersBothPresent` | Default `{A:"1"}` + per-request `{B:"2"}`; both keys in outbound request | US2-AC-1 |
| `defaultHeadersPresentWhenNoPerRequestHeaders` | Default headers + nil per-request; full default set in outbound request | US2-AC-2 |
| `perRequestHeadersOnlyWhenNoDefaults` | No defaults + per-request headers; only per-request headers present | US2-AC-3 |
| `perRequestOverridesDefaultOnConflict` | Default `Authorization: default-token` + per-request `Authorization: scoped-token`; outbound carries `scoped-token` | US3-AC-1 |
| `storedDefaultUnchangedAfterConflictingRequest` | Above scenario; subsequent request with no per-request `Authorization`; outbound carries `default-token` | US3-AC-2 |
| `caseInsensitiveConflictResolution` | Default `content-type: text/plain` + per-request `Content-Type: application/json`; per-request value wins | US3-AC-3 |
| `libraryContentTypeOverridesDefaultHeader` | Default `Content-Type: text/xml` + JSON body; library `Content-Type: application/json` wins | Edge case (FR-005) |
| `emptyValueDefaultHeaderIsTransmitted` | Default header with empty string value; transmitted in outbound request | Edge case (A-06) |
| `defaultHeadersOnMultipartPostRequest` | Engine with default headers; multipart POST; default headers present alongside multipart Content-Type | US1-AC-2 + FR-002 |
