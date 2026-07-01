# Research: Request Configuration Struct

**Feature**: `003-request-configuration` | **Date**: 2026-06-28 | **Phase 0**

This feature supersedes the closure-based `RequestConfigurator` mechanism from
Feature 001 with a typed, immutable `DefaultHTTPClient.Configuration` value type nested
inside `DefaultHTTPClient` via `public extension DefaultHTTPClient`. All design decisions below
are derived from the existing codebase (`DefaultHTTPClient.swift`, `RequestBuilder.swift`),
prior feature design artifacts (001–002), the requirements in `spec.md`, and the
project constitution. No NEEDS CLARIFICATION items remain.

---

## Decision 1 — Type name: `DefaultHTTPClient.Configuration`

**Decision**: The new type is named `DefaultHTTPClient.Configuration`, declared as a
nested type inside `DefaultHTTPClient` via `public extension DefaultHTTPClient { struct Configuration ... }`
in `Sources/HTTPClientLib/Implementation/DefaultHTTPClient+Configuration.swift`.

**Rationale**: Nesting the type inside `DefaultHTTPClient` expresses ownership clearly —
this is configuration *for* the default implementation, not a free-standing request concept.
The name `Configuration` alone within the `HTTPClient` namespace is noun-first and
Swifty (Constitution I, API Design Guidelines), consistent with patterns like
`URLSession.Configuration`. At call sites it reads as `DefaultHTTPClient.Configuration`,
which is self-documenting, and the default instance is accessed as `.default`
(member-access shorthand) wherever the type is contextually inferred.

**Alternatives considered**: Top-level `HTTPConfiguration` — no clear ownership
expressed; ambiguous whether it belongs to the engine or a request. `HTTPConfiguration` —
adds `HTTP` prefix redundant inside `HTTPClientLib`. `URLHTTPClient.Configuration` — too close
to `URLSessionConfiguration` in the Foundation namespace; would cause confusion.

---

## Decision 2 — Type kind: `public struct` with synthesised `Sendable`

**Decision**: `DefaultHTTPClient.Configuration` is a `public struct` with six `let` stored
properties. `Sendable` conformance is synthesised automatically by the Swift
compiler.

**Rationale**: Spec assumption A-05 explicitly states the type must be a value type,
consistent with Swift API Design Guidelines for configuration data. Constitution V
requires all types crossing concurrency boundaries to conform to `Sendable`. A
struct whose stored properties are all value types (`TimeInterval` = `Double`,
`URLRequest.CachePolicy` = `@frozen enum : UInt`, and `Bool`) is `Sendable` without
an explicit annotation — the compiler infers this in Swift 6 strict-concurrency
mode. Value semantics satisfy FR-006 (immutable after construction) and FR-010 (safe
for concurrent use) at zero runtime cost: the struct is copied, not referenced.

**Alternatives considered**: `public class` — reference semantics would require
explicit `@Sendable` annotation or an `NSCopying` pattern to prevent shared mutable
state across concurrent calls; spec A-05 explicitly rejects this. Protocol with
a concrete default implementation — more extensible but violates YAGNI
(Constitution I) and the spec's explicit requirement for a struct.

---

## Decision 3 — Property set: exactly the six properties from FR-002

**Decision**: `DefaultHTTPClient.Configuration` exposes exactly six properties:
`timeoutInterval`, `cachePolicy`, `allowsCellularAccess`,
`allowsExpensiveNetworkAccess`, `allowsConstrainedNetworkAccess`, and
`httpShouldHandleCookies`.

**Rationale**: FR-002 enumerates the minimum required properties. Spec assumption
A-02 explicitly excludes `networkServiceType` ("narrow use cases; deferred to
follow-up if needed"). No other `URLRequest` property is in scope for this feature.
Adding more properties than specified violates YAGNI (Constitution I) and would
require additional acceptance scenarios that are not currently defined.

**Platform availability**: All six properties are available on macOS 14 (the
project's minimum target per Package.swift). `allowsExpensiveNetworkAccess` and
`allowsConstrainedNetworkAccess` were introduced in macOS 10.15; both are available
without availability guards at macOS 14+.

**Alternatives considered**: Including `networkServiceType` — explicitly deferred
by A-02. Including `httpShouldUsePipelining` — deprecated by Apple and no longer
effective in modern URL loading; out of scope. Including custom headers — out of
scope per FR-001: "HTTP method, URL, body, content-type, and caller-supplied headers
are explicitly out of scope for this type."

---

## Decision 4 — Default property values match `URLRequest` platform defaults

**Decision**: The default values for all six properties match the `URLRequest`
platform defaults documented by Apple:

| Property | Default Value | Source |
|----------|---------------|--------|
| `timeoutInterval` | `60.0` | `URLRequest.timeoutInterval` default |
| `cachePolicy` | `.useProtocolCachePolicy` | `URLRequest.cachePolicy` default |
| `allowsCellularAccess` | `true` | `URLRequest.allowsCellularAccess` default |
| `allowsExpensiveNetworkAccess` | `true` | `URLRequest.allowsExpensiveNetworkAccess` default |
| `allowsConstrainedNetworkAccess` | `true` | `URLRequest.allowsConstrainedNetworkAccess` default |
| `httpShouldHandleCookies` | `true` | `URLRequest.httpShouldHandleCookies` default |

**Rationale**: FR-003 explicitly requires that the default configuration's property
values be "equivalent to the platform-standard `URLRequest` defaults for those same
properties." Spec assumption A-04 states: "If platform defaults change in future OS
versions, the library's default configuration should be updated to match." Matching
platform defaults ensures SC-002 (zero observable behavioural change relative to
the pre-feature baseline) and satisfies User Story 1 acceptance scenarios entirely.

**Alternatives considered**: Hard-coding values that differ from platform defaults
to provide "sensible library-specific defaults" — rejected; FR-003 is explicit that
the default configuration is a pass-through to the platform baseline. Any
opinion-based default (e.g., a 30-second timeout) would introduce a silent
behavioural change relative to existing callers.

---

## Decision 5 — Static default instance: `DefaultHTTPClient.Configuration.default`

**Decision**: `DefaultHTTPClient.Configuration` exposes a `public static let default =
Configuration()` property. `DefaultHTTPClient.init` uses this as the default parameter
value: `configuration: DefaultHTTPClient.Configuration = .default`.

**Rationale**: FR-003 ("MUST expose a built-in default value obtainable without
supplying any constructor arguments") and FR-004 ("MUST accept a configuration
argument that defaults to the built-in default value when omitted") are both
satisfied by a static `let` constant. Using `.default` in the parameter default
value is idiomatic Swift (consistent with `.shared` on `URLSession`, `.main` on
`DispatchQueue`, etc.), readable at call sites, and requires no runtime allocation —
the constant is initialised once. The name `default` is a Swift keyword used as an
identifier in backtick context when needed, but as a plain label in `.default`
member-access syntax it is clean and unambiguous.

**Alternatives considered**: `DefaultHTTPClient.Configuration()` as a direct default argument
expression — works but produces a new value on every call site. The static constant
is semantically clearer ("this is THE default") and conveys intent. Named
`DefaultHTTPClient.Configuration.standard` — less idiomatic than `.default` for a "platform
baseline" configuration constant.

---

## Decision 6 — `RequestConfigurator` typealias and `configurator` property removed

**Decision**: The `RequestConfigurator` typealias (`public typealias
RequestConfigurator = @Sendable (inout URLRequest) -> Void`) and the
`HTTPClient.configurator: RequestConfigurator?` stored property are both removed.
The `configurator` init parameter on `DefaultHTTPClient.init` is also removed. This is a
**breaking public API change**.

**Rationale**: FR-008 states: "The prior closure-based `URLRequest` customisation
mechanism introduced in Feature 001 (FR-011) is superseded by this feature; it MUST
be removed or replaced by the configuration struct." Spec assumption A-09 explicitly
flags this as a breaking change requiring a MAJOR version bump. Removing the
mechanism completely rather than keeping it as a deprecated path avoids an ambiguous
dual-path API where the closure's arbitrary mutation could silently override
`DefaultHTTPClient.Configuration` properties (or vice versa).

**Migration path for existing callers**:
- Callers that used `configurator` to set `timeoutInterval` → use
  `DefaultHTTPClient(configuration: DefaultHTTPClient.Configuration(timeoutInterval: …))`.
- Callers that used `configurator` to set `cachePolicy` → use
  `DefaultHTTPClient(configuration: DefaultHTTPClient.Configuration(cachePolicy: …))`.
- Callers that used `configurator` to inject arbitrary headers → use the `headers:`
  parameter on the HTTP method call or `DefaultHTTPClient(defaultHeaders:)` at init time.
  Open-ended mutation outside the configuration struct's property surface is
  intentionally out of scope per spec A-01.

**Existing tests affected** (two tests require migration, not new behaviour):
- `HTTPClientGetTests.configuratorMutatesRequestBeforeDispatch` — currently sets
  `timeoutInterval = 42` via configurator; migrated to
  `DefaultHTTPClient(configuration: DefaultHTTPClient.Configuration(timeoutInterval: 42))`.
- `HTTPClientPostTests.configuratorIsInvokedForPostRequests` — currently injects an
  arbitrary header `X-Injected` via configurator; migrated to use the `headers:`
  parameter directly (the capability is unchanged; only the API surface changes).

**Alternatives considered**: Deprecating `RequestConfigurator` instead of removing
it — rejected; FR-008 says "removed or replaced"; keeping a deprecated form adds a
dual-path API that is harder to test and document. Adding a `configurator` property
to `DefaultHTTPClient.Configuration` — rejected; that re-introduces open-ended mutation in
exactly the way spec A-01 says the struct supersedes ("The closure offered
open-ended mutation; the struct provides a defined, auditable property surface").

---

## Decision 7 — Assembly ordering: configuration applied before engine-managed properties

**Decision**: In `RequestBuilder.buildRequest` and in the multipart inline path,
`DefaultHTTPClient.Configuration` properties are applied to the `URLRequest` immediately
after URL and HTTP method are set, and before any header application. Engine-managed
properties (HTTP body, Content-Type) are applied last.

Full 4-step assembly (replaces old 4-step):

| Step | Action | Notes |
|------|--------|-------|
| 0 (implicit) | `URLRequest(url:)` + `request.httpMethod` | URL and method set at creation and from parameter |
| 1 (new) | Apply `configuration` properties | `timeoutInterval`, `cachePolicy`, cellular/expensive/constrained access, cookie handling |
| 2 | Apply `defaultHeaders` | Lowest header-priority tier (unchanged from Feature 002) |
| 3 | Apply per-request `headers` | Overwrites conflicting defaults (unchanged from Feature 002) |
| 4 | Apply library `Content-Type` + `httpBody` | Highest header priority; applied only when a body variant requires it (unchanged from Feature 002) |

**Rationale**: FR-007 states "Configuration application MUST NOT override properties
set by the engine." Spec A-07 states "Library-managed properties are always applied
after the configuration struct's properties." Since `DefaultHTTPClient.Configuration` targets
`URLRequest` properties that are orthogonal to the engine-managed fields (method,
URL, body, Content-Type header), there is no practical conflict. The ordering
clarifies intent: the configuration struct sets up the transport-level properties
of the request; the engine's own steps set the semantic content (what is sent, to
where, with what headers). The old Step 4 (RequestConfigurator callback) is removed.

**Alternatives considered**: Applying configuration last (after headers and body) —
rejected; would invert the stated precedence in A-07 even though there is no
practical conflict. Applying configuration inside `RequestBuilder` only — the
multipart path assembles its `URLRequest` inline; it must also apply the
configuration in the same position to maintain consistent behaviour across all HTTP
methods.

---

## Decision 8 — Configuration applied at engine-initialisation level, not per-request

**Decision**: The `configuration` parameter is placed on `DefaultHTTPClient.init`, not on
individual HTTP method signatures. The engine stores it as `public let configuration:
Configuration` and applies it uniformly to every dispatched request.

```swift
public init(
    session: URLSession = .shared,
    configuration: DefaultHTTPClient.Configuration = .default,
    defaultHeaders: [String: String]? = nil
)
```

HTTP method signatures include an additive optional `progress: SupportLib.Progress?`
parameter (defaulted by `DefaultHTTPClient`), while remaining source-compatible for
existing call sites that omit the new argument:

```swift
public func get(_ url: URL, headers: [String: String]? = nil, progress: SupportLib.Progress? = nil) async throws -> HTTPResponse
public func post(_ url: URL, body: RequestBody? = nil, headers: [String: String]? = nil, progress: SupportLib.Progress? = nil) async throws -> HTTPResponse
// … etc.
```

**Rationale**: Engine-level configuration aligns with how `URLSession` itself works:
a session has a configuration (`URLSessionConfiguration`) applied to all requests
it dispatches. Placing the configuration on the engine init keeps method signatures
clean (FR-009 remains satisfied because call sites remain compatible), makes the engine's
transport intent explicit at construction time, and gives callers a natural
composition point — create one engine per distinct transport profile. All existing
HTTP method call sites compile unchanged without modification.

**Alternatives considered**: Per-request `configuration:` parameter on each HTTP
method — would clutter every call site with an opt-in parameter that is usually
identical across all calls through the same engine; makes it harder to reason about
what transport settings an engine will use. The engine-level approach is the simpler
and more idiomatic model.

---

## Decision 9 — MAJOR version bump: implicit 0.x pre-release → 1.0.0

**Decision**: Consistent with spec A-09 and the constitution Quality Gates,
this feature must be accompanied by a MAJOR version bump. The library's current
pre-release version is `0.0.1` (established in Feature 001/002 contracts). The
next version after this breaking change is `1.0.0`.

**Rationale**: Removing a public property (`HTTPClient.configurator`) and a public
typealias (`RequestConfigurator`) from the library's public API is a breaking change.
The constitution states: "Breaking public API changes MUST be flagged and MUST be
accompanied by a MAJOR version bump in `Package.swift`." SPM libraries are
versioned via git tags; the tasks for this feature include tagging `1.0.0` after
merge. No in-file version constant exists in `Package.swift` for this library;
the version is tracked via git semantics.

**Alternatives considered**: Keeping both the configurator (deprecated) and the new
struct — rejected; FR-008 is unambiguous. Bumping to `0.1.0` (minor, pre-release) —
rejected; the constitution and A-09 both specify MAJOR for this class of change.

---

## Summary of Resolved Unknowns

| Unknown | Resolution |
|---------|-----------|
| Type name | `DefaultHTTPClient.Configuration` (nested type, Decision 1) |
| Type kind | `public struct`, Sendable synthesised (Decision 2) |
| Properties | Exactly 6: timeout, cachePolicy, cellular/expensive/constrained access, cookies (Decision 3) |
| Default values | Match `URLRequest` platform defaults (Decision 4) |
| Static default | `DefaultHTTPClient.Configuration.default` used as `DefaultHTTPClient.init` parameter default (Decision 5) |
| Configurator removal | Fully removed (breaking change); two existing tests migrated (Decision 6) |
| Assembly ordering | Config applied at Step 1 (after URL+method); headers/body steps unchanged (Decision 7) |
| Configuration scope | Engine-level (on `DefaultHTTPClient.init`), not per-request (Decision 8) |
| Version bump | `0.0.1` → `1.0.0` via git tag at merge (Decision 9) |
