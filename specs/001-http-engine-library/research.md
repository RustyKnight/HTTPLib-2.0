# Research: HTTPClient Library

**Feature**: `001-http-engine-library` | **Date**: 2026-06-28 | **Phase 0**

All design questions raised during Technical Context analysis are resolved below.
No unknowns remain; `tasks.md` generation may proceed.

---

## Decision 1 — Testing framework: Swift Testing over XCTest

**Decision**: Use Swift Testing (`import Testing`, `@Test`, `@Suite`) throughout
`Tests/HTTPLibTests/`.

**Rationale**: Plan notes (`Features/Plan-HTTPLibrary.md`) explicitly state
"Swift Testing as a preference". The committed test scaffold
(`Tests/HTTPLibTests/HTTPLibTests.swift`) already uses `import Testing` and Swift
Testing macros, establishing the precedent. Swift Testing ships with Swift 6 as
Apple's modern testing framework: `@Test` functions are natively `async throws`
without shims, the `#expect` macro provides richer failure diagnostics than
`XCTAssert`, and `@Test(arguments:)` enables parameterised test cases with minimal
boilerplate. It is fully supported by `swift test` and Xcode.

**Alternatives considered**: XCTest — rejected; contradicts plan notes and the
existing scaffold. Mixed XCTest + Swift Testing — rejected; two testing frameworks
in one target adds unnecessary complexity.

---

## Decision 2 — `HTTPClient` as a struct (value type)

**Decision**: Implement `HTTPClient` as a `public struct` with `let` stored
properties.

**Rationale**: The spec (A-01) mandates a concrete type; a struct with two `let`
properties — `session: URLSession` and `configurator: RequestConfigurator?` —
synthesises `Sendable` automatically in Swift 6, satisfying Constitution V without
`@unchecked Sendable`. `URLSession` is declared `@unchecked Sendable` by Apple in
Foundation; `RequestConfigurator` is a `@Sendable` closure. A-07 confirms
concurrent use of the same `HTTPClient` instance is safe — no per-instance mutable
state is accumulated between calls. Structs cannot be subclassed, keeping the
public surface minimal.

**Alternatives considered**: `final class` — no shared mutable state in the design,
struct is strictly simpler. Protocol `HTTPClientProtocol` — deferred per A-01; a
protocol abstraction is a future concern.

---

## Decision 3 — `RequestBody` enum with `@unchecked Sendable`

**Decision**: Define `public enum RequestBody: @unchecked Sendable` with three
cases: `.text(String)`, `.binary(Data)`, `.json(any Encodable)`.

**Rationale**: The `any Encodable` existential is not statically `Sendable` in
Swift 6. However, JSON encoding is performed *synchronously* in `RequestBuilder`
before the assembled `URLRequest` is handed to `URLSession.data(for:delegate:)` —
the only async boundary. No `Encodable` value escapes to a different concurrency
domain; the data race the compiler would flag is not reachable in practice.
`@unchecked Sendable` is the standard Swift 6 pattern for this. The `.text` and
`.binary` cases would be fully `Sendable` on their own.

**Alternatives considered**: Generic overloads
`post<T: Encodable & Sendable>(_:body:headers:)` — creates a combinatorial
explosion of overloads and prevents `RequestBody` from being stored as a first-class
value. Constraining to `any Encodable & Sendable` — unnecessarily restrictive; most
model types are not marked `Sendable` even when they are only used for synchronous
encoding.

---

## Decision 4 — `URLProtocol` subclass for test isolation

**Decision**: Provide `MockURLProtocol: URLProtocol` in
`Tests/HTTPLibTests/Helpers/`. Tests inject it by constructing a
`URLSession(configuration:)` whose `URLSessionConfiguration` has
`MockURLProtocol` registered via `protocolClasses`.

**Rationale**: Satisfies user story 4's injectable session requirement and all
consumer-code unit-testability goals without adding a protocol abstraction over
`URLSession` to the public API (A-01 explicitly defers this). `URLProtocol`
subclassing is Apple's canonical approach for URLSession mocking in unit tests. It
intercepts requests at the URL-loading-system level, giving full access to the
assembled `URLRequest` (for header and body assertions) and allowing canned
`HTTPURLResponse` + `Data` pairs to be returned. The approach works for both
synchronous `swift test` runs and async test bodies.

**Alternatives considered**: `URLSessionProtocol` — would add a public protocol to
the library's surface area with no consumer use case justifying it (A-01 defers
this). `OHHTTPStubs` or similar third-party library — prohibited by Constitution V.

---

## Decision 5 — RFC 2046 multipart/form-data encoding

**Decision**: Implement `MultipartEncoder` as an `internal struct` with a single
`static func encode(_ items: [FormItem]) throws -> (body: Data, contentType: String)`
entry point. Boundary format: `"----Boundary-\(UUID().uuidString)"` generated fresh
per call. Part separators use CRLF (`\r\n`) per RFC 2046. The final boundary line is
terminated with `--`. Each part includes `Content-Disposition: form-data; name="…"`
and an optional `filename="…"`. `Content-Type` per part defaults to
`application/octet-stream` (`.file`, `.data`) or `text/plain` (`.property`) unless
the item's `mimeType` field is set.

**Rationale**: Separating encoding into an `internal` struct allows focused unit
testing in `MultipartEncoderTests.swift` without spinning up a full URLSession
stack. UUID-derived boundaries are globally unique with no collision risk and satisfy
A-09 (no caller-supplied boundary). CRLF is mandatory in RFC 2046 §4.1; using `\r\n`
string literals avoids platform line-ending surprises that `\n`-only approaches risk.

**Alternatives considered**: `\n`-only line endings — non-compliant with RFC 2046.
Random alphanumeric boundary — UUID is simpler and requires no custom RNG.
Streaming/chunked multipart encoding — unnecessary complexity for the file sizes
this library targets (deferred to a future version if needed).

---

## Decision 6 — Internal header priority strategy

**Decision**: In `RequestBuilder`, apply caller-supplied headers first, then apply
library-required headers (e.g., `Content-Type` for body requests) — overwriting any
conflicting caller-supplied value. The `URLRequest` configurator callback is invoked
*after* this step; its mutations are applied last.

**Rationale**: Setting caller headers first and library headers second (overwriting)
is a single pass with no conditional logic. FR-009 requires all caller headers to be
transmitted; user story 3 AC-03 requires library headers to take precedence on
conflict — both are satisfied by this ordering. The configurator callback runs last
to give advanced callers maximum flexibility (FR-011), noting that A-10 makes
overriding the HTTP method via the configurator the caller's responsibility.

**Alternatives considered**: Reject conflicting caller headers with an error — overly
strict, breaks callers who set `Content-Type` on non-body requests. Merge with
precedence logic per key — same outcome, higher cyclomatic complexity.

---

## Decision 7 — `RequestConfigurator` typealias and `@Sendable`

**Decision**: `public typealias RequestConfigurator = @Sendable (inout URLRequest) -> Void`

**Rationale**: `HTTPClient` (a struct) synthesises `Sendable`. Swift 6 requires all
stored closures in `Sendable` types to themselves be `@Sendable`. Using
`inout URLRequest` gives the callback direct mutation semantics without an extra
allocation. The callback is invoked synchronously during request assembly — it is
not retained for deferred or concurrent invocation — so `@escaping` is not needed.

**Alternatives considered**: `(URLRequest) -> URLRequest` — avoids `inout` but
forces a new `URLRequest` allocation on every dispatch even when the closure is
minimal. `@escaping` — incorrect semantics; the callback is not stored beyond the
request-assembly call stack.

---

## Decision 8 — Cancellation propagation

**Decision**: Call `try Task.checkCancellation()` at the entry of each request
method (before request assembly). Rely on `URLSession.data(for:delegate:)`'s native
Swift Concurrency integration for in-flight cancellation. Do **not** wrap
`CancellationError` in `HTTPClientError`; let it propagate directly to the caller.

**Rationale**: `URLSession.data(for:delegate:)` integrates with Swift Concurrency's
cooperative cancellation model: when the calling `Task` is cancelled, the URLSession
data task is cancelled and `CancellationError` is thrown automatically. The entry
`checkCancellation()` guards against tasks that were already cancelled before any
request assembly starts. FR-007 requires `CancellationError` to reach the caller
unchanged; wrapping it in `HTTPClientError` would break callers who specifically
catch `CancellationError`.

**Alternatives considered**: `withTaskCancellationHandler` wrapping URLSession —
unnecessary; `URLSession.data(for:)` already handles this natively in Swift 6. Not
calling `checkCancellation()` at entry — risks assembling a full URLRequest for a
task that is already cancelled.

---

## Summary of Resolved Unknowns

| Unknown | Resolution |
|---------|-----------|
| Testing framework | Swift Testing (`import Testing`) per plan notes and existing scaffold |
| `HTTPClient` value vs reference type | `struct` — synthesises `Sendable`, no shared mutable state |
| `RequestBody` Sendable conformance | `@unchecked Sendable` on the enum; `any Encodable` encoded synchronously before async dispatch |
| URLSession mock strategy | `MockURLProtocol: URLProtocol` — no public protocol abstraction needed |
| Multipart boundary generation | `UUID().uuidString`-derived, per-request, `\r\n` CRLF line endings |
| Header conflict resolution | Library headers overwrite caller headers on conflict; configurator runs last |
| `RequestConfigurator` closure type | `@Sendable (inout URLRequest) -> Void` |
| Cancellation strategy | `Task.checkCancellation()` at entry + native URLSession async integration; `CancellationError` propagates directly |
