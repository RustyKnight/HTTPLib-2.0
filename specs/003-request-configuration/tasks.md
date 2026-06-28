---

description: "Task list for Feature 003: Request Configuration Struct"

---

# Tasks: Request Configuration Struct

**Feature Branch**: `003-request-configuration`
**Input**: Design documents from `specs/003-request-configuration/`
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Data Model**: [data-model.md](data-model.md)
**Contract**: [contracts/public-api.md](contracts/public-api.md) | **Quickstart**: [quickstart.md](quickstart.md)

**⚠ BREAKING CHANGE**: This feature removes `RequestConfigurator` and `HTTPClient.configurator`. MAJOR version bump `0.0.1 → 1.0.0` (git tag) is required at merge.

**Testing Framework**: Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`) — established project standard per plan.md Complexity Tracking.

**TDD Discipline**: Within each story phase, tests are written FIRST (RED state) before implementation tasks. Constitution II is non-negotiable.

---

## Format: `[ID] [P?] [Story?] Description with file path`

- **[P]**: Task operates on a different file from other concurrent tasks — can run in parallel
- **[USn]**: Maps to user story n from spec.md
- All tasks include exact file paths

---

## Phase 1: Setup (Project Foundation for Feature 003)

**Purpose**: Create the new `HTTPClient.Configuration` type — the foundational type that everything else in this feature depends on. No other file can be updated correctly until this type exists.

- [X] T001 Create `Sources/HTTPLib/HTTPClient.Configuration.swift` — implement `public extension HTTPClient { struct Configuration: Sendable { ... } }` with exactly six `let` stored properties (`timeoutInterval: TimeInterval = 60.0`, `cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy`, `allowsCellularAccess: Bool = true`, `allowsExpensiveNetworkAccess: Bool = true`, `allowsConstrainedNetworkAccess: Bool = true`, `httpShouldHandleCookies: Bool = true`), a single memberwise `public init` with all-default parameters, and `public static let \`default\` = Configuration()`. No body, no other methods. The type must compile with zero warnings under Swift 6.0 strict concurrency; `Sendable` conformance is synthesised automatically.

---

## Phase 2: Foundational (Blocking Prerequisites — Test Migration)

**Purpose**: Migrate the two existing tests that reference the `RequestConfigurator`/`configurator` API before the old API is removed. These tests establish the RED state for the migration tests; they will not compile correctly until Phase 3 implementation is complete, which is the intended TDD starting condition.

**⚠️ CRITICAL**: These migrations must be written before Phase 3 implementation. Both touch different files and can proceed in parallel after Phase 1.

- [X] T002 [P] Migrate `Tests/HTTPLibTests/HTTPClientGetTests.swift` — rename the existing test `configuratorMutatesRequestBeforeDispatch` to `customTimeoutAppliedViaConfiguration`; replace `HTTPClient(configurator: { $0.timeoutInterval = 42 })` with `HTTPClient(session: session, configuration: HTTPClient.Configuration(timeoutInterval: 42))`; assert `mock.capturedRequest?.timeoutInterval == 42`. All other assertions remain unchanged.

- [X] T003 [P] Migrate `Tests/HTTPLibTests/HTTPClientPostTests.swift` — rename the existing test `configuratorIsInvokedForPostRequests` to `perRequestHeadersAppliedToPostRequest`; replace `HTTPClient(configurator: { $0.setValue("injected-value", forHTTPHeaderField: "X-Injected") })` with `HTTPClient()` (no configurator); change the `post` call to pass `headers: ["X-Injected": "injected-value"]` as a per-request header parameter; assert that `mock.capturedRequest?.value(forHTTPHeaderField: "X-Injected") == "injected-value"`. This test will become RED when `configurator:` is removed from `HTTPClient.init` in T005.

**Checkpoint**: Migration tests written. Phase 3 implementation may now begin.

---

## Phase 3: User Story 1 — Zero-Config Default Behaviour (Priority: P1) 🎯 MVP

**Goal**: Every existing call site that omits `configuration:` at both the init and
method level compiles and behaves identically to the pre-Feature-003 baseline. The
built-in default `HTTPClient.Configuration.default` produces `URLRequest` properties
matching platform defaults (60-second timeout, `useProtocolCachePolicy`, all access
flags `true`, cookies enabled). All Feature 001/002 regression tests pass unmodified
(except the two migrated tests from Phase 2).

**Independent Test**: Create an `HTTPClient` without a `configuration:` argument and
issue any HTTP method call using a `MockURLProtocol`-backed session; assert the
captured `URLRequest` carries `timeoutInterval == 60.0` and all other default values.
Run `swift test --filter HTTPClientGetTests` and confirm it still passes.

### Tests for User Story 1 ⚠️ Write FIRST — must FAIL before implementation

- [X] T004 [US1] Create `Tests/HTTPLibTests/HTTPClientConfigurationTests.swift` — new Swift Testing `@Suite struct HTTPClientConfigurationTests` with a `makeEngine(configuration:)` helper that calls `HTTPClient(session:configuration:)`. Write three US1 tests per `quickstart.md` Scenarios 1a–1c:
  1. `defaultConfigurationMatchesPlatformDefaults` — construct `HTTPClient.Configuration.default`; assert all six properties match their platform-default values.
  2. `defaultConfigurationIsAppliedWhenNoArgumentSupplied` — create engine with no `configuration:` arg; call `engine.get(url)`; assert `mock.capturedRequest?.timeoutInterval == 60.0`.
  3. `existingCallSitesUnchangedWithDefaultConfig` — call `engine.get(url)`, `engine.post(url)`, `engine.put(url)`, `engine.delete(url)` (each with no `configuration:` argument); assert each captured `URLRequest` has `timeoutInterval == 60.0` and `cachePolicy == .useProtocolCachePolicy`.

### Implementation for User Story 1

- [X] T005 [US1] Remove breaking API from `Sources/HTTPLib/HTTPClient.swift` — delete the `public typealias RequestConfigurator = @Sendable (inout URLRequest) -> Void` declaration; delete the `public let configurator: RequestConfigurator?` stored property; remove the `configurator: RequestConfigurator? = nil` parameter from `HTTPClient.init`; remove any reference to `self.configurator` inside the `dispatch` private method. The file will not compile cleanly until T006 is also applied; this is expected.

- [X] T006 [US1] Add `configuration: Configuration = .default` parameter and `public let configuration: Configuration` stored property to `Sources/HTTPLib/HTTPClient.swift`. Updated `HTTPClient.init` per `contracts/public-api.md`:
  - `public init(session: URLSession = .shared, configuration: Configuration = .default, defaultHeaders: [String: String]? = nil)`
  - Store as `self.configuration = configuration`
  - HTTP method signatures remain unchanged — no `configuration:` parameter on methods
  - Pass `configuration: configuration` (the stored property) to `RequestBuilder.buildRequest` inside `dispatch`

- [X] T007 [P] [US1] Update `Sources/HTTPLib/Internal/RequestBuilder.swift` — replace the `configurator: RequestConfigurator?` parameter in `buildRequest` with `configuration: HTTPClient.Configuration` (no default value, always supplied); insert a new Step 1 that applies all six configuration properties to the `URLRequest` immediately after URL and `httpMethod` are set and before `defaultHeaders` are applied:
  ```
  request.timeoutInterval                = configuration.timeoutInterval
  request.cachePolicy                    = configuration.cachePolicy
  request.allowsCellularAccess           = configuration.allowsCellularAccess
  request.allowsExpensiveNetworkAccess   = configuration.allowsExpensiveNetworkAccess
  request.allowsConstrainedNetworkAccess = configuration.allowsConstrainedNetworkAccess
  request.httpShouldHandleCookies        = configuration.httpShouldHandleCookies
  ```
  Steps 2 (defaultHeaders), 3 (per-request headers), and 4 (Content-Type + httpBody) remain unchanged. Remove the old Step 4 configurator callback.

- [X] T008 [US1] Apply `self.configuration` in the multipart inline path of `Sources/HTTPLib/HTTPClient.swift` — in `post(_:formItems:headers:)`, locate the inline `URLRequest` assembly block; insert Step 1 (the same six-property assignment block from T007, reading from `self.configuration`) immediately after `request.httpMethod` is set and before `defaultHeaders` are applied; ensure no residual `configurator` reference remains.

**Checkpoint**: US1 tests GREEN. All Feature 001/002 regression suites pass. `swift build` produces zero warnings.

---

## Phase 4: User Story 2 — Custom Engine-Level Configuration (Priority: P2)

**Goal**: A developer can create an `HTTPClient` with an `HTTPClient.Configuration` value carrying any combination of the six supported properties. All supplied properties are applied exactly to every outgoing `URLRequest` assembled by that engine; none are silently ignored.

**Independent Test**: Create `HTTPClient(configuration: .init(timeoutInterval: 120.0))`, call `engine.get(url)`, and assert `capturedRequest.timeoutInterval == 120.0`. Run `swift test --filter HTTPClientConfigurationTests/customTimeout` to verify.

### Tests for User Story 2

- [X] T009 [US2] Add US2 tests to `Tests/HTTPLibTests/HTTPClientConfigurationTests.swift` — append 11 new `@Test` functions using the `makeEngine(configuration:)` helper. Each test uses a stub 200 response. Implement all bodies per `quickstart.md` Scenarios 2a–2h:
  1. `customTimeoutAppliedToRequest` — `makeEngine(configuration: .init(timeoutInterval: 120.0))` then `get`; assert `capturedRequest.timeoutInterval == 120.0`
  2. `customCachePolicyAppliedToRequest` — `makeEngine(configuration: .init(cachePolicy: .reloadIgnoringLocalCacheData))` then `post`; assert matching cache policy
  3. `cellularAccessDisabledAppliedToRequest` — engine with `allowsCellularAccess: false`; assert on `get`
  4. `expensiveNetworkAccessDisabledAppliedToRequest` — engine with `allowsExpensiveNetworkAccess: false`; assert on `get`
  5. `constrainedNetworkAccessDisabledAppliedToRequest` — engine with `allowsConstrainedNetworkAccess: false`; assert on `get`
  6. `cookieHandlingDisabledAppliedToRequest` — engine with `httpShouldHandleCookies: false`; assert on `get`
  7. `multiplePropertiesAllAppliedSimultaneously` — engine with non-default timeout + cache policy + cellular=false; assert all three on `get`
  8. `configurationAppliedToPostBodyRequest` — engine with custom timeout; call `post(_:body:headers:)`; assert timeout reflected
  9. `configurationAppliedToMultipartPostRequest` — engine with custom timeout; call `post(_:formItems:headers:)`; assert timeout reflected
  10. `configurationAppliedToPutRequest` — engine with custom timeout; call `put`; assert timeout reflected
  11. `configurationAppliedToDeleteRequest` — engine with custom timeout; call `delete`; assert timeout reflected

**Checkpoint**: All 11 US2 tests GREEN. Custom configuration is applied across all HTTP methods.

---

## Phase 5: User Story 3 — Configuration Is Consistent Across All Requests on an Engine (Priority: P3)

**Goal**: Every request dispatched through an engine consistently carries that engine's configuration. No configuration state leaks between engines, and the configuration value is not mutated by any request call.

**Independent Test**: Create an engine with `configuration: .init(timeoutInterval: 999.0)`, issue two sequential `get` calls, assert both captured requests have `timeoutInterval == 999.0`. This verifies the engine consistently applies its stored configuration.

### Tests for User Story 3

- [X] T010 [US3] Add US3 tests to `Tests/HTTPLibTests/HTTPClientConfigurationTests.swift` — append 3 new `@Test` functions. Implement per `quickstart.md` Scenarios 3a–3c:
  1. `configurationIsolatedAcrossSequentialRequests` — create engine with `configuration: .init(timeoutInterval: 999.0)`; issue two sequential `get` calls; assert both captured requests have `timeoutInterval == 999.0`
  2. `configurationValueNotMutatedByRequestCall` — construct `let sharedConfig = HTTPClient.Configuration(timeoutInterval: 30.0)`; create engine with it; call `engine.get` then `engine.post`; after both calls assert `sharedConfig.timeoutInterval == 30.0` (value semantics guarantee this at compile time; the test documents the intent)
  3. `concurrentRequestsCarryOwnConfiguration` — create two independent `MockURLProtocol`-backed engine/mock pairs (`engineA` with `timeoutInterval: 10.0`, `engineB` with default); launch concurrent requests; assert `mockA.capturedRequest?.timeoutInterval == 10.0` and `mockB.capturedRequest?.timeoutInterval == 60.0`

**Checkpoint**: All 3 US3 tests GREEN. Configuration consistency confirmed for sequential and concurrent requests.

---

## Phase 6: User Story 4 — Configuration Does Not Override Engine-Managed Properties (Priority: P4)

**Goal**: The `HTTPClient.Configuration` struct is strictly scoped to transport-level `URLRequest` properties. Engine-managed properties — HTTP method, URL, HTTP body, Content-Type header, and all caller-supplied headers — are always set by the engine after Step 1 and are never overridden by the configuration struct.

**Independent Test**: Create an engine with `configuration: .init(timeoutInterval: 999.0, allowsCellularAccess: false)`; call `engine.get(url)` and `engine.post(url)`; assert the captured `URLRequest.httpMethod` is `"GET"` and `"POST"` respectively and the URL is unchanged.

### Tests for User Story 4

- [X] T011 [US4] Add US4 tests to `Tests/HTTPLibTests/HTTPClientConfigurationTests.swift` — append 4 new `@Test` functions. Implement per `quickstart.md` Scenarios 4a–4d:
  1. `configurationDoesNotOverrideHTTPMethod` — engine with `timeoutInterval: 999.0` and `allowsCellularAccess: false`; call `engine.get(url)`; assert `capturedRequest.httpMethod == "GET"`; call `engine.post(url)`; assert `capturedRequest.httpMethod == "POST"`
  2. `configurationDoesNotOverrideURL` — engine with `cachePolicy: .reloadIgnoringLocalCacheData`; call `engine.get(url)`; assert `capturedRequest.url == url`
  3. `configurationDoesNotOverrideHTTPBody` — engine with `timeoutInterval: 5.0`; call `engine.post(url, body: .json(["key": "value"]))`; assert `Content-Type == "application/json"` and body bytes match
  4. `configurationDoesNotOverrideCallerHeaders` — engine with `allowsCellularAccess: false`; call `engine.get(url, headers: ["X-Caller": "value"])`; assert `capturedRequest.value(forHTTPHeaderField: "X-Caller") == "value"`

**Checkpoint**: All 4 US4 tests GREEN. All 21 new tests in `HTTPClientConfigurationTests` pass. All Phase 2 migration tests pass.

---

## Phase 7: Polish & Quality Gates

**Purpose**: Verify all quality gates from the constitution and plan, and publish the MAJOR version tag.

- [X] T012 Run `swift build` from the repository root and confirm zero warnings and zero errors (Constitution I, Quality Gate 1). If any warnings are present, resolve them before proceeding. Expected output: build succeeds with no `warning:` lines.

- [X] T013 Run `swift test` from the repository root and confirm all tests pass with zero failures (Constitution II, Quality Gate 2). Verify the following suites pass: `HTTPClientConfigurationTests` (21 tests), `HTTPClientGetTests` (including migrated `customTimeoutAppliedViaConfiguration`), `HTTPClientPostTests` (including migrated `perRequestHeadersAppliedToPostRequest`), `HTTPClientPutTests`, `HTTPClientDeleteTests`, `HTTPClientHeaderTests`, `HTTPClientDefaultHeaderTests`, `HTTPClientMultipartTests`, `HTTPClientCancellationTests`, `MultipartEncoderTests`. Expected output: `Test Suite 'All tests' passed` with 0 failures.

- [X] T014 Create git tag `1.0.0` on the current HEAD commit: `git tag 1.0.0`. This is the MAJOR version bump required by spec A-09 and the constitution Quality Gates for the removal of `RequestConfigurator` and `HTTPClient.configurator`. No change to `Package.swift` is required; the library version is tracked via git semantics (see research Decision 9).

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (T001)
    │
    ├──▶ Phase 2 (T002, T003 — parallel, both depend on T001)
    │         │
    │         └──▶ Phase 3 (T004 then T005 → T006 → T007‖T008)
    │                   │
    │                   └──▶ Phase 4 (T009)
    │                             │
    │                             └──▶ Phase 5 (T010)
    │                                       │
    │                                       └──▶ Phase 6 (T011)
    │                                                 │
    │                                                 └──▶ Phase 7 (T012 → T013 → T014)
```

### User Story Dependencies

- **US1 (P1)**: Depends on Phase 1 (T001) + Phase 2 (T002, T003) — no dependency on other stories. **MVP scope.**
- **US2 (P2)**: Depends on US1 implementation being complete (Phase 3) — tests verify existing implementation; no new code changes required
- **US3 (P3)**: Depends on US1 — same as US2
- **US4 (P4)**: Depends on US1 — same as US2

### Within Phase 3 (US1 — Strict Dependency Chain)

```
T004 (write US1 tests, RED)
    │
T005 (remove RequestConfigurator/configurator from HTTPClient.swift)
    │
T006 (add configuration param to HTTPClient.init; store as public let configuration)
    │
    ├──▶ T007 [P] (update RequestBuilder.swift — different file, parallel with T008)
    │
    └──▶ T008 (update dispatch + multipart inline in HTTPClient.swift to use self.configuration)
```

T007 and T008 can be executed in parallel (different files: `RequestBuilder.swift` vs `HTTPClient.swift`), but both depend on T006.

### Within Phase 7

```
T012 (swift build — must pass first)
    │
T013 (swift test — runs only after clean build)
    │
T014 (git tag — only after all tests pass)
```

### Parallel Opportunities Per Phase

| Phase | Parallel Tasks | Notes |
|-------|---------------|-------|
| Phase 2 | T002 ‖ T003 | Different files: `HTTPClientGetTests.swift` vs `HTTPClientPostTests.swift` |
| Phase 3 | T007 ‖ T008 | Different files: `RequestBuilder.swift` vs `HTTPClient.swift` (after T006) |
| Phase 4–6 | T009, T010, T011 | Sequential (same file): must be added in story-priority order |

---

## Parallel Example: User Story 1

```bash
# After T006 completes, launch T007 and T008 in parallel:
Task A: "Update Sources/HTTPLib/Internal/RequestBuilder.swift — replace configurator
         with configuration, apply Step 1, remove Step 4"
Task B: "Update private dispatch + multipart inline path in Sources/HTTPLib/HTTPClient.swift"

# These touch different files and can complete independently.
# No merge conflict possible.
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Create `HTTPClient.Configuration.swift`
2. Complete Phase 2: Migrate two existing failing tests
3. Complete Phase 3: US1 tests (RED) → implementation → GREEN
4. **STOP AND VALIDATE**: Run `swift test` — all regressions pass, US1 tests pass
5. This is a fully shippable increment (zero config works, existing callers unbroken)

### Incremental Delivery

1. Setup (T001) → Foundation ready
2. Phase 2 migrations → TDD baseline established
3. Phase 3 (US1) → Default behaviour confirmed, BREAKING change landed → **MVP**
4. Phase 4 (US2) → Custom configuration verified → Per-request control confirmed
5. Phase 5 (US3) → Isolation verified → Concurrent safety confirmed
6. Phase 6 (US4) → Boundary verified → Engine-managed properties confirmed safe
7. Phase 7 → Quality gates + `1.0.0` tag → Ready to ship

### Single-Developer Sequence

```
T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012 → T013 → T014
```

All tasks are independently completable in this order. Commit after each task or logical group.

---

## Task Count Summary

| Scope | Tasks | Task IDs |
|-------|-------|----------|
| Setup (Phase 1) | 1 | T001 |
| Foundational — test migration (Phase 2) | 2 | T002–T003 |
| US1 — Zero-Config Default (Phase 3) | 5 | T004–T008 |
| US2 — Custom Per-Request Config (Phase 4) | 1 | T009 |
| US3 — Config Isolation (Phase 5) | 1 | T010 |
| US4 — No Engine Override (Phase 6) | 1 | T011 |
| Polish & Quality Gates (Phase 7) | 3 | T012–T014 |
| **Total** | **14** | **T001–T014** |

**New source files**: 1 (`Sources/HTTPLib/HTTPClient.Configuration.swift`)
**Modified source files**: 2 (`Sources/HTTPLib/HTTPClient.swift`, `Sources/HTTPLib/Internal/RequestBuilder.swift`)
**New test files**: 1 (`Tests/HTTPLibTests/HTTPClientConfigurationTests.swift`, 21 tests)
**Modified test files**: 2 (`Tests/HTTPLibTests/HTTPClientGetTests.swift`, `Tests/HTTPLibTests/HTTPClientPostTests.swift`)
**Version tag**: `1.0.0` (MAJOR — breaking change)

---

## Notes

- **[P]** tasks operate on different files — no merge conflicts possible
- **[USn]** label maps each task to a specific user story for traceability to spec.md
- Constitution II (TDD): All test tasks within each phase are listed before implementation tasks
- Each story phase is independently completable and verifiable with `swift test --filter <SuiteName>`
- No force-unwraps in `Sources/` — use `try #require(...)` in tests, not `!`
- Swift Testing `@Suite`/`@Test`/`#expect` throughout — consistent with Features 001–002
- Commit after T008 (US1 complete) is the natural MVP checkpoint
- `git tag 1.0.0` (T014) must only be applied after `swift test` passes (T013)
