# Research: Configurable Default Headers

**Feature**: `002-configurable-headers` | **Date**: 2026-06-28 | **Phase 0**

This feature is a small, additive change to an already-implemented library. No
external unknowns require network research. All decisions below are derived from
the existing codebase (`HTTPEngine.swift`, `RequestBuilder.swift`), Feature 001
design artifacts, and the requirements in `spec.md`. No NEEDS CLARIFICATION items
remain; `/speckit.tasks` generation may proceed.

---

## Decision 1 — Parameter type: `[String: String]?` matches per-request headers

**Decision**: The `defaultHeaders` init parameter type is `[String: String]?`,
matching the `headers` parameter type used on every existing HTTP method operation.

**Rationale**: FR-006 explicitly states "The default headers parameter type MUST
match the existing per-request headers parameter type; no new public types are
introduced by this feature." A-05 reinforces this. Using `[String: String]?` also
follows the progressive-disclosure principle (Constitution III): passing `nil` or
omitting the parameter entirely produces identical behaviour to a pre-feature engine
instance (FR-001).

**Alternatives considered**: A dedicated `DefaultHeaders` type — rejected; FR-006
and A-05 explicitly prohibit new public types for this feature. `[AnyHashable: Any]`
(mirroring `URLSessionConfiguration.httpAdditionalHeaders`) — rejected; less type-
safe and inconsistent with the typed `[String: String]` already established for per-
request headers.

---

## Decision 2 — Internal storage normalises nil to empty dictionary

**Decision**: `HTTPEngine` stores `let defaultHeaders: [String: String]` (not
optional). The init parameter `defaultHeaders: [String: String]? = nil` is
normalised at construction: `self.defaultHeaders = defaultHeaders ?? [:]`.

**Rationale**: Storing a non-optional `[String: String]` eliminates optional-
unwrapping on every request dispatch and makes the "no default headers" path
identical at runtime to the "empty dict" path (FR-001). An empty dictionary
costs one heap allocation at init time and negligible dispatch overhead. Keeping the
init parameter optional preserves the progressive-disclosure API (Constitution III):
the existing `HTTPEngine()` call site compiles without change.

**Alternatives considered**: Store as `[String: String]?` and guard-unwrap on each
dispatch — adds avoidable conditional complexity with no benefit; the stored-empty-
dict pattern is idiomatic Swift for "optional dictionary with no default entries".

---

## Decision 3 — Four-step merge in `RequestBuilder.buildRequest`

**Decision**: Extend `RequestBuilder.buildRequest` with a `defaultHeaders:
[String: String]` parameter and apply headers in four ordered steps:

1. **Instance default headers** (applied first — lowest priority)
2. **Per-request caller headers** (overwrite conflicting defaults)
3. **Library-required headers** (`Content-Type` for body encoding — overwrites both)
4. **`RequestConfigurator` callback** (runs last — highest priority)

**Rationale**: This ordering directly implements the precedence rule stated in
spec A-01 ("most-specific wins") and FR-004 ("per-request value MUST take
precedence") and FR-005 ("library-internal required value MUST take precedence").
The four-step extension of Feature 001's three-step strategy preserves all existing
behaviour exactly — steps 2–4 are unchanged; step 1 is prepended.

**Alternatives considered**: Merge defaults and per-request headers into a combined
dictionary first, then apply — equivalent but requires an extra allocation and hides
the precedence ordering. Apply defaults last (after per-request) — inverts the
required precedence and violates FR-004.

---

## Decision 4 — Case-insensitive conflict detection via `URLRequest.setValue`

**Decision**: No custom case-folding logic is required. Applying header dictionaries
sequentially via `URLRequest.setValue(_:forHTTPHeaderField:)` is sufficient for
case-insensitive conflict detection; the Foundation API documents that "HTTP headers
are case insensitive" and that `setValue` replaces any existing value for the same
field name regardless of casing.

**Rationale**: The spec requires case-insensitive conflict detection (US3-AC-3,
FR-004, A-03). Foundation's `setValue` already implements this contract at the
`URLRequest` level. Delegating to the platform API is simpler, more correct (it
matches the casing behaviour of the actual HTTP engine), and avoids a custom
normalisation function that would duplicate behaviour already guaranteed by the OS.

**Alternatives considered**: Manually lowercase all keys before insertion — adds
complexity and a secondary normalisation step that diverges from how `URLRequest`
stores header names. A custom `Dictionary<String, String>` subtype with lowercased
keys — adds a new public type, which FR-006 prohibits.

---

## Decision 5 — Multipart inline path in `HTTPEngine` also updated

**Decision**: The multipart POST path in `HTTPEngine.post(_:formItems:headers:)` uses
an inline `URLRequest` assembly block (not routed through `RequestBuilder`). This
block must also be updated to apply default headers in the same four-step order.

**Rationale**: The dispatch helper (`dispatch(url:method:headers:body:)`) used by all
non-multipart methods routes through `RequestBuilder`; updating `RequestBuilder`
covers GET, POST (body), PUT, and DELETE automatically. The multipart path is the
only code path that assembles a `URLRequest` outside `RequestBuilder`. Skipping this
update would leave multipart POSTs without default headers, violating FR-002 ("EVERY
request dispatched through that instance MUST include those headers").

**Alternatives considered**: Refactor the multipart path to route through
`RequestBuilder` — this would be a cleaner structural change, but it is scope beyond
the feature's stated requirements (FR-008: public signatures unchanged; no mention of
internal refactoring). The simpler fix is a targeted update to the inline block,
consistent with YAGNI (Constitution I).

---

## Decision 6 — No new public types (FR-006 and A-05)

**Decision**: This feature introduces no new public types, typealiases, or protocols.

**Rationale**: FR-006 explicitly prohibits new public types; A-05 states the default
headers parameter uses the same type as the per-request parameter. All required
semantics are expressible with the existing `[String: String]` type.

**Alternatives considered**: N/A — this is an explicit requirement, not a design
choice.

---

## Decision 7 — `[String: String]` is `Sendable`; struct synthesis unchanged

**Decision**: Adding `let defaultHeaders: [String: String]` to `HTTPEngine` requires
no changes to `Sendable` conformance. The struct continues to synthesise `Sendable`
automatically.

**Rationale**: `Swift.Dictionary` is `Sendable` when both `Key` and `Value` conform
to `Sendable`. `String` conforms to `Sendable`. Therefore `[String: String]` is
`Sendable`, and the stored `let` property does not break `HTTPEngine`'s synthesised
conformance (Constitution V; A-04 — concurrent use remains safe because the stored
value is fixed at init and never mutated).

**Alternatives considered**: N/A — this is a verification of an existing constraint,
not a choice.

---

## Summary of Resolved Unknowns

| Unknown | Resolution |
|---------|-----------|
| `defaultHeaders` parameter type | `[String: String]?` — matches per-request headers type per FR-006/A-05 |
| Internal storage type | `[String: String]` (non-optional) — nil normalised to `[:]` at init |
| Merge step order | 4-step: defaults → per-request → library Content-Type → configurator |
| Case-insensitive conflict detection | Delegated to `URLRequest.setValue` (Foundation contract) |
| Multipart path coverage | Inline assembly in `HTTPEngine.post(_:formItems:headers:)` updated separately |
| New public types | None (FR-006 explicit prohibition) |
| `Sendable` impact | None — `[String: String]` is `Sendable`; struct synthesis unchanged |
