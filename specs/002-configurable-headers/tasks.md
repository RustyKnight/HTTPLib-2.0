---
description: "Implementation tasks for Feature 002 — Configurable Default Headers"
---

# Tasks: Configurable Default Headers

**Feature**: `002-configurable-headers` | **Branch**: `002-configurable-headers`
**Date**: 2026-06-28
**Input**: `specs/002-configurable-headers/` — spec.md ✅ plan.md ✅ research.md ✅ data-model.md ✅ contracts/public-api.md ✅ quickstart.md ✅

## Format: `[ID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel with other [P]-marked tasks (different files, no blocking deps)
- **[US1/US2/US3]**: User story this task belongs to (maps to spec.md priority order)
- Every implementation task includes the exact file path being modified or created

## Implementation Scope

| File | Change |
|------|--------|
| `Sources/HTTPLib/HTTPEngine.swift` | Add `defaultHeaders` property + updated init; pass to `dispatch`; update multipart inline assembly |
| `Sources/HTTPLib/Internal/RequestBuilder.swift` | Add `defaultHeaders` parameter; prepend it as step 1 of the now 4-step merge |
| `Tests/HTTPLibTests/HTTPEngineDefaultHeaderTests.swift` | **NEW** — 15 test cases covering all US1/US2/US3 acceptance criteria and edge cases |

All other source and test files are **unchanged** (FR-008, SC-003).

---

## Phase 1: Setup

**Purpose**: Read the two source files that will change before making any modifications.

- [X] T001 Read `Sources/HTTPLib/Internal/RequestBuilder.swift` (note the current 3-step merge: (1) caller `headers`, (2) library Content-Type, (3) configurator callback) and `Sources/HTTPLib/HTTPEngine.swift` (note the `dispatch(url:method:headers:body:)` call to `RequestBuilder.buildRequest` and the multipart POST inline assembly) — these are the only two call sites modified by this feature; confirm file contents match the design described in `specs/002-configurable-headers/data-model.md`

---

## Phase 2: Foundational (Blocking Prerequisite)

**Purpose**: Add the `defaultHeaders` stored property and updated initialiser to `HTTPEngine` so the new test file can compile. No merge logic is wired at this stage — this is the minimum stub required for US1 tests to be written and confirmed to fail deterministically.

**⚠️ CRITICAL**: The US1 test file (T004) cannot be created until this phase is complete.

- [X] T002 Add `public let defaultHeaders: [String: String]` stored property and `defaultHeaders: [String: String]? = nil` parameter to `HTTPEngine.init(session:configurator:defaultHeaders:)` with body line `self.defaultHeaders = defaultHeaders ?? [:]` in `Sources/HTTPLib/HTTPEngine.swift` — property stub only; do NOT yet update the `dispatch` call or multipart inline assembly; all existing call sites must continue to compile unchanged
- [X] T003 Run `swift build` and confirm zero errors and zero warnings; if a `Sendable` warning appears verify `defaultHeaders` is declared `let` (not `var`) and that `[String: String]` satisfies `Sendable` automatically (research Decision 7)

**Checkpoint**: `HTTPEngine` compiles with the new property and init parameter. The US1 test file can now be written.

---

## Phase 3: User Story 1 — Default Headers Applied to Every Request (Priority: P1) 🎯 MVP

**Goal**: Every request dispatched through an `HTTPEngine` configured with `defaultHeaders` automatically carries those headers — across GET, POST, PUT, DELETE, and multipart POST.

**Independent Test**: `swift test --filter HTTPEngineDefaultHeaderTests` — all 7 US1 tests pass, 0 failures

### Tests for User Story 1

> **TDD — write these tests FIRST and confirm they FAIL before writing any implementation**

- [X] T004 [US1] Create `Tests/HTTPLibTests/HTTPEngineDefaultHeaderTests.swift` as a new Swift Testing `@Suite` using `import Testing` and `@testable import HTTPLib`; implement 7 US1 test cases — each constructs an `HTTPEngine` with `MockURLProtocol` as the session's `protocolClasses` and asserts on `MockURLProtocol.capturedRequest?.value(forHTTPHeaderField:)` or `allHTTPHeaderFields`:
  - `defaultHeadersAppliedToGetRequest` — `HTTPEngine(defaultHeaders: ["X-API-Key": "abc123"])`, GET request, assert `value(forHTTPHeaderField: "X-API-Key") == "abc123"` (US1-AC-1)
  - `defaultHeadersAppliedToPostRequest` — same engine, POST request, same assertion (US1-AC-2)
  - `defaultHeadersAppliedToPutRequest` — same engine, PUT request, same assertion (US1-AC-2)
  - `defaultHeadersAppliedToDeleteRequest` — same engine, DELETE request, same assertion (US1-AC-2)
  - `emptyDefaultHeadersAddsNoHeaders` — `HTTPEngine(defaultHeaders: [:])`, GET request, assert `value(forHTTPHeaderField: "X-API-Key") == nil` (US1-AC-3)
  - `nilDefaultHeadersMatchesBaseline` — `HTTPEngine()` (no `defaultHeaders` arg), GET request, assert no unexpected custom headers present (US1-AC-4)
  - `defaultHeadersOnMultipartPostRequest` — `HTTPEngine(defaultHeaders: ["X-API-Key": "abc123"])`, multipart POST with one `FormItem`, assert `value(forHTTPHeaderField: "X-API-Key") == "abc123"` alongside the multipart `Content-Type` (US1-AC-2 + FR-002)
- [X] T005 [US1] Confirm US1 tests fail (red phase) — run `swift test --filter HTTPEngineDefaultHeaderTests`; all 7 tests MUST fail because `dispatch` is not yet wired to pass `defaultHeaders` to `RequestBuilder`; if any test unexpectedly passes re-examine T002 to ensure the `dispatch` call was not accidentally updated

### Implementation for User Story 1

- [X] T006 [US1] Update `Sources/HTTPLib/Internal/RequestBuilder.swift`: add `defaultHeaders: [String: String]` as a new parameter to `buildRequest(url:method:headers:body:configurator:defaultHeaders:)` and prepend it as step 1 of the header merge — iterate `defaultHeaders` and call `request.setValue(_:forHTTPHeaderField:)` for each entry before the existing step that processes per-request `headers`; the existing steps are renumbered: (1) `defaultHeaders` NEW, (2) per-request `headers` (overwrites step-1 conflicts via Foundation case-insensitive `setValue`), (3) library Content-Type for body encoding (unchanged), (4) `configurator` callback (unchanged)
- [X] T007 [US1] Update `Sources/HTTPLib/HTTPEngine.swift`: (a) in `dispatch(url:method:headers:body:)` pass `defaultHeaders: self.defaultHeaders` as the new argument to `RequestBuilder.buildRequest`; (b) in the multipart POST inline assembly of `post(_:formItems:headers:)` prepend `self.defaultHeaders` as step 1 — iterate `self.defaultHeaders` and call `request.setValue(_:forHTTPHeaderField:)` before the existing step that applies per-request `headers`, keeping the multipart `Content-Type` at step 3 and `self.configurator` at step 4
- [X] T008 [US1] Confirm US1 tests pass (green phase) — run `swift test --filter HTTPEngineDefaultHeaderTests`; all 7 tests MUST be green; if any fail consult the Interpreting Results table in `specs/002-configurable-headers/quickstart.md`

**Checkpoint**: User Story 1 is fully functional and independently verified. `HTTPEngine(defaultHeaders:)` injects configured headers into every request type — GET, POST, PUT, DELETE, and multipart POST.

---

## Phase 4: User Story 2 — Default Headers and Per-Request Headers Both Applied (Priority: P2)

**Goal**: When an engine has default headers and a request supplies per-request headers with non-overlapping keys, both sets appear in the outbound request.

**Independent Test**: `swift test --filter HTTPEngineDefaultHeaderTests` — all 10 tests pass (7 US1 + 3 US2)

### Tests for User Story 2

- [X] T009 [US2] Append 3 US2 test cases to `Tests/HTTPLibTests/HTTPEngineDefaultHeaderTests.swift`:
  - `defaultAndPerRequestHeadersBothPresent` — `HTTPEngine(defaultHeaders: ["A": "1"])`, GET with per-request `headers: ["B": "2"]`, assert both `"A": "1"` and `"B": "2"` present in `capturedRequest?.allHTTPHeaderFields` (US2-AC-1)
  - `defaultHeadersPresentWhenNoPerRequestHeaders` — same engine, GET with `headers: nil`, assert `"A": "1"` present and no `"B"` key (US2-AC-2)
  - `perRequestHeadersOnlyWhenNoDefaults` — `HTTPEngine()` (no defaults), GET with per-request `headers: ["B": "2"]`, assert `"B": "2"` present and no `"A"` key — verifies pre-feature baseline is unchanged (US2-AC-3)
- [X] T010 [US2] Confirm US2 tests pass — run `swift test --filter HTTPEngineDefaultHeaderTests`; all 10 tests MUST be green; the 4-step merge implemented in Phase 3 already handles additive (non-conflicting) merging; if `defaultAndPerRequestHeadersBothPresent` fails inspect step 2 of `RequestBuilder.buildRequest` in `Sources/HTTPLib/Internal/RequestBuilder.swift` to confirm per-request headers are applied additively (not replacing the full header set)

**Checkpoint**: User Stories 1 and 2 fully verified. Both header sets merge correctly when keys are distinct.

---

## Phase 5: User Story 3 — Per-Request Headers Override Default Headers on Conflict (Priority: P3)

**Goal**: When a per-request header name matches a default header name (case-insensitively), the per-request value wins for that call only. The stored default is never mutated.

**Independent Test**: `swift test --filter HTTPEngineDefaultHeaderTests` — all 15 tests pass (10 US1+US2 + 5 US3+edge)

### Tests for User Story 3

- [X] T011 [US3] Append 5 US3 and edge-case test cases to `Tests/HTTPLibTests/HTTPEngineDefaultHeaderTests.swift`:
  - `perRequestOverridesDefaultOnConflict` — `HTTPEngine(defaultHeaders: ["Authorization": "default-token"])`, GET with per-request `headers: ["Authorization": "scoped-token"]`, assert `value(forHTTPHeaderField: "Authorization") == "scoped-token"` (US3-AC-1)
  - `storedDefaultUnchangedAfterConflictingRequest` — using the **same engine instance** as above, issue a second GET with no per-request `Authorization`, assert `value(forHTTPHeaderField: "Authorization") == "default-token"` — verifies the stored default was never mutated (US3-AC-2, FR-007)
  - `caseInsensitiveConflictResolution` — `HTTPEngine(defaultHeaders: ["content-type": "text/plain"])`, GET with per-request `headers: ["Content-Type": "application/json"]`, assert final value is `"application/json"` — case-insensitive conflict resolution is delegated to `URLRequest.setValue` Foundation contract (US3-AC-3, research Decision 4)
  - `libraryContentTypeOverridesDefaultHeader` — `HTTPEngine(defaultHeaders: ["Content-Type": "text/xml"])`, POST with `.json(...)` body and no per-request headers, assert `value(forHTTPHeaderField: "Content-Type") == "application/json"` — library tier 3 wins over both default and per-request (edge case, FR-005)
  - `emptyValueDefaultHeaderIsTransmitted` — `HTTPEngine(defaultHeaders: ["X-Custom": ""])`, GET with no per-request headers, assert `capturedRequest?.allHTTPHeaderFields?["X-Custom"] == ""` — empty value is valid HTTP and must not be stripped (edge case, A-06)
- [X] T012 [US3] Confirm US3 and edge-case tests pass — run `swift test --filter HTTPEngineDefaultHeaderTests`; all 15 tests MUST be green; if `storedDefaultUnchangedAfterConflictingRequest` fails verify `defaultHeaders` is stored as `let` (not `var`) in `Sources/HTTPLib/HTTPEngine.swift` (FR-007); if `caseInsensitiveConflictResolution` fails no custom code is needed — verify that headers are applied via `URLRequest.setValue` which provides the Foundation case-insensitive contract

**Checkpoint**: All three user stories verified. All 15 tests in `HTTPEngineDefaultHeaderTests` pass. The full acceptance matrix from `specs/002-configurable-headers/quickstart.md` is satisfied.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final quality gates required by the project constitution before the feature is merge-ready.

- [X] T013 Run the full test suite `swift test` and confirm ALL Feature 001 and Feature 002 tests pass with zero failures (SC-002, SC-003); if any Feature 001 suite regresses verify the new `defaultHeaders` parameter has a `nil` default and that the `[:]` normalised path is a no-op in step 1 of `RequestBuilder.buildRequest` in `Sources/HTTPLib/Internal/RequestBuilder.swift`
- [X] T014 Run `swift build` and confirm zero warnings and zero errors (SC-005, Constitution I quality gate); this gate MUST pass before merge per `constitution.md`; if a `Sendable` warning appears verify `defaultHeaders` is `let` in `Sources/HTTPLib/HTTPEngine.swift`
- [X] T015 [P] Review new and modified code in `Sources/HTTPLib/HTTPEngine.swift` and `Sources/HTTPLib/Internal/RequestBuilder.swift` for Constitution I compliance: zero force-unwraps (`!`), zero `fatalError` calls in non-irrecoverable paths, explicit types on all stored properties and parameters, no unused imports; document any necessary deviation in `specs/002-configurable-headers/plan.md` Complexity Tracking table

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS US test file creation (T004)
- **US1 (Phase 3)**: Depends on Phase 2 completion — write tests (red) → implement → confirm pass (green)
- **US2 (Phase 4)**: Depends on Phase 3 completion — write tests; no new source changes needed
- **US3 (Phase 5)**: Depends on Phase 4 completion — write tests; no new source changes needed
- **Polish (Phase 6)**: Depends on all user story phases complete

### User Story Dependencies

| Story | Depends on | New source changes | Notes |
|-------|-----------|-------------------|-------|
| US1 (P1) | Phase 2 | `RequestBuilder.swift` (4-step merge), `HTTPEngine.swift` (wire dispatch + multipart) | Core implementation |
| US2 (P2) | Phase 3 | None | US1 merge logic already handles additive case |
| US3 (P3) | Phase 3 | None | `URLRequest.setValue` Foundation contract handles case-insensitive override |

### Within Each User Story (TDD Order, Constitution II)

1. Write test cases in `Tests/HTTPLibTests/HTTPEngineDefaultHeaderTests.swift`
2. Confirm tests FAIL (red phase — mandatory before writing implementation)
3. Write implementation code in `Sources/`
4. Confirm tests PASS (green phase)
5. Move to next user story phase

### Parallel Opportunities

- **T013 + T015** (Polish Phase): Different concerns — test suite execution vs code review; can run in parallel

---

## Parallel Execution: User Story 1

```bash
# After T003 (build confirmed), write and fail US1 tests:
T004: Create Tests/HTTPLibTests/HTTPEngineDefaultHeaderTests.swift (7 US1 test cases)
T005: swift test --filter HTTPEngineDefaultHeaderTests  ← must FAIL (red)

# After T005 (red confirmed), implement — T007 depends on T006 (new parameter signature):
T006: Update Sources/HTTPLib/Internal/RequestBuilder.swift  (add defaultHeaders param + step 1)
T007: Update Sources/HTTPLib/HTTPEngine.swift               (wire dispatch + multipart)  ← after T006
T008: swift test --filter HTTPEngineDefaultHeaderTests      ← must PASS (green)
```

---

## Implementation Strategy

### MVP First (User Story 1 — Phases 1–3, 8 tasks)

1. T001: Read existing source to understand current 3-step merge
2. T002–T003: Add property stub, confirm zero-warning build
3. T004–T008: Write US1 tests (red) → implement 4-step merge → confirm green
4. **STOP and VALIDATE**: `swift test --filter HTTPEngineDefaultHeaderTests` — 7 tests pass
5. US1 deliverable: `HTTPEngine(defaultHeaders:)` automatically injects headers on every request type

### Incremental Delivery (Full Feature)

1. T001–T003 → Foundation ready (property stub compiles)
2. T004–T008 → **US1 complete (MVP)** — automatic default headers on GET, POST, PUT, DELETE, multipart POST ✅
3. T009–T010 → **US2 complete** — additive merge with per-request headers verified ✅
4. T011–T012 → **US3 complete** — conflict override, immutability, case-insensitivity, edge cases verified ✅
5. T013–T015 → **Quality gates passed** — zero warnings, full regression green, code reviewed ✅

---

## Notes

- **[P]** marks tasks that can run concurrently with other [P]-marked tasks (no file conflicts, no blocking deps)
- **[US1/US2/US3]** labels trace each task to its user story for independent verification and testing
- **TDD is mandatory** per Constitution II: write tests → confirm FAIL → implement → confirm PASS; never skip the red phase
- All 15 test cases go in **a single file** — T009 and T011 **append** to the file created in T004; do not create separate files
- `MockURLProtocol` is reused from Feature 001 **without modification** — reference `Tests/HTTPLibTests/Helpers/MockURLProtocol.swift`
- Case-insensitive header conflict resolution is provided by `URLRequest.setValue(_:forHTTPHeaderField:)` — no custom case-folding is needed (research Decision 4); the Foundation API contract is sufficient for US3-AC-3
- Zero `swift build` warnings is a **non-negotiable quality gate** per `constitution.md`; the `let defaultHeaders: [String: String]` property satisfies `Sendable` automatically (research Decision 7, `[String: String]` is `Sendable` because `String` is `Sendable`)
- The `DELETE` method appears after multipart POST in `HTTPEngine.swift` — it routes through `dispatch` like GET/POST/PUT and requires **no separate treatment**
