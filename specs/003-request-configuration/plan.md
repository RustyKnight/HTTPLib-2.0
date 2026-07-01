# Implementation Plan: Request Configuration Struct

**Branch**: `003-request-configuration` | **Date**: 2026-06-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-request-configuration/spec.md`
**Plan Notes**: `Features/Plan-Base.md`

## Summary

Replace the open-ended, closure-based `RequestConfigurator` mechanism (FR-011,
Feature 001) with a typed, immutable `DefaultHTTPClient.Configuration` struct (declared as
a nested type via `public extension DefaultHTTPClient` in `DefaultHTTPClient+Configuration.swift`) that
carries the six `URLRequest` transport properties not otherwise managed by the engine:
timeout interval, cache policy, cellular access, expensive-network access,
constrained-network access, and cookie handling. `DefaultHTTPClient.init` gains a
`configuration: DefaultHTTPClient.Configuration = .default` parameter, leaving all existing
init call sites that omit the argument source-compatible. `DefaultHTTPClient` stores the
value as `public let configuration: Configuration` and applies it to every assembled
`URLRequest`. HTTP method signatures now include an additive optional
`SupportLib.Progress` parameter on `GET`/`POST`/`PUT`/`DELETE`; existing call sites remain
source-compatible because the parameter defaults to `nil` in the default implementation.
The built-in default instance
(`DefaultHTTPClient.Configuration.default`) reproduces `URLRequest` platform defaults exactly,
so default behaviour is unchanged. Because the public `RequestConfigurator`
typealias and `HTTPClient.configurator` property are removed, this is a **breaking
API change** requiring a MAJOR version bump from pre-release (`0.0.1`) to `1.0.0`
(spec A-09, Quality Gates).

## Technical Context

**Language/Version**: Swift 6.0 (`swift-tools-version: 6.0` in `Package.swift`)

**Primary Dependencies**: Foundation (`URLSession`, `URLRequest`,
`URLRequest.CachePolicy`) — no third-party dependencies

**Storage**: N/A

**Testing**: Swift Testing (`import Testing`, `@Test`, `@Suite`) — established as
the project standard from Feature 001 (same justified deviation as Features 001–002;
see Complexity Tracking)

**Target Platform**: macOS 14+ (as declared in `Package.swift`)

**Project Type**: Swift Package — reusable library distributed exclusively via SPM

**Performance Goals**: `DefaultHTTPClient.Configuration` application is a synchronous series
of six property assignments executed during `URLRequest` assembly. No performance
concern; no impact on actual network latency or throughput.

**Scale/Scope**: Moderate — one new source file (`Implementation/DefaultHTTPClient+Configuration.swift`),
targeted updates to `Implementation/DefaultHTTPClient.swift` and `RequestBuilder.swift`; one new test
suite (`HTTPClientConfigurationTests.swift`), two migrated tests in existing suites,
and a git tag bump to `1.0.0`. No schema migrations, no new external dependencies,
no new build targets.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Code Quality — explicit types, zero warnings, no force-unwraps, YAGNI | ✅ PASS | `DefaultHTTPClient.Configuration` is a nested struct with six explicitly-typed `let` properties declared via `public extension DefaultHTTPClient`; `Sendable` is synthesised automatically; no `!` introduced; no scope beyond the six FR-002 properties (YAGNI). |
| II | Testing Standards — TDD, XCTest, async/await tests, `swift test` runnable | ⚠️ JUSTIFIED DEVIATION | Swift Testing used (`@Test`, `@Suite`, `#expect`), as established in Feature 001. TDD discipline, async test bodies, and `swift test` runnability are fully met. See Complexity Tracking. |
| III | API UX — progressive disclosure, URL-only minimum, typed throws, Swifty naming | ✅ PASS | `configuration: DefaultHTTPClient.Configuration = .default` is opt-in on `DefaultHTTPClient.init`; all existing URL-only call sites compile unchanged (FR-009, A-08). The breaking change (configurator removal) is a deliberate simplification, not a regression. |
| IV | Performance & Reliability — async/await, cancellation, Sendable, no silent errors | ✅ PASS | No new async paths; `DefaultHTTPClient.Configuration` is a `Sendable` value type with no shared mutable state; six property assignments cannot fail silently; cancellation semantics unchanged. |
| V | Modern Standards — Swift 6.0, macOS 14+, URLSession only, SPM only | ✅ PASS | `URLRequest.CachePolicy`, `allowsExpensiveNetworkAccess`, and `allowsConstrainedNetworkAccess` are all available at macOS 14+ without availability guards. No platform, toolchain, or tooling changes. |

**Gate result**: ✅ PROCEED — one justified deviation (Swift Testing) documented in
Complexity Tracking. Breaking-change flag raised and documented (A-09, Quality
Gates).

**Post-Phase 1 re-check**: ✅ Design in `data-model.md` and `contracts/public-api.md`
introduces no new violations. `DefaultHTTPClient.Configuration` synthesises `Sendable`; all
assembly-step changes stay within the existing `RequestBuilder` + multipart inline
scope. All five gates still pass after Phase 1 design.

## Project Structure

### Documentation (this feature)

```text
specs/003-request-configuration/
├── plan.md              # This file
├── research.md          # Phase 0 output — all 9 design decisions resolved
├── data-model.md        # Phase 1 — DefaultHTTPClient.Configuration struct + all changed types
├── quickstart.md        # Phase 1 — runnable validation guide (US1–US4)
├── contracts/
│   └── public-api.md    # Phase 1 — updated public API delta-contract; v1.0.0 notes
└── tasks.md             # Phase 2 — generated by /speckit.tasks (not created here)
```

### Source Code (repository root)

```text
Sources/HTTPClientLib/
├── Implementation/DefaultHTTPClient+Configuration.swift  # NEW: public extension DefaultHTTPClient { struct Configuration }
├── Implementation/DefaultHTTPClient.swift                # UPDATED: remove RequestConfigurator + configurator;
│                                                         #   add configuration param to DefaultHTTPClient.init;
│                                                         #   store as public let configuration: Configuration;
│                                   #   apply config in dispatch + multipart inline path
├── HTTPClient.swift                                     # UPDATED protocol public surface
├── HTTPResponse.swift                                   # Unchanged protocol
├── RequestBody.swift                                    # Unchanged
├── FormItem.swift                                       # Unchanged
├── Implementation/HTTPClientError.swift                 # Unchanged
└── Internal/
    ├── RequestBuilder.swift        # UPDATED: replace configurator param with
    │                               #   configuration: DefaultHTTPClient.Configuration; Step 1 applies
    │                               #   config; Step 4 (configurator callback) removed
    └── MultipartEncoder.swift      # Unchanged

Tests/HTTPClientLibTests/
├── HTTPClientConfigurationTests.swift  # NEW: all US1–US4 acceptance criteria (21 tests)
├── HTTPClientGetTests.swift            # MIGRATED: configuratorMutatesRequestBeforeDispatch
│                                       #   → customTimeoutAppliedViaConfiguration
├── HTTPClientPostTests.swift           # MIGRATED: configuratorIsInvokedForPostRequests
│                                       #   → perRequestHeadersAppliedToPostRequest
├── HTTPClientPutTests.swift            # Unchanged (regression guard)
├── HTTPClientDeleteTests.swift         # Unchanged (regression guard)
├── HTTPClientHeaderTests.swift         # Unchanged (regression guard)
├── HTTPClientDefaultHeaderTests.swift  # Unchanged (regression guard)
├── HTTPClientMultipartTests.swift      # Unchanged (regression guard)
├── HTTPClientCancellationTests.swift   # Unchanged (regression guard)
├── MultipartEncoderTests.swift         # Unchanged
└── Helpers/
    └── MockURLProtocol.swift           # Unchanged — reused as-is
```

**Structure Decision**: Standard Swift Package Manager layout unchanged from
Features 001–002. All source changes are confined to `Implementation/DefaultHTTPClient+Configuration.swift`
(new), `Implementation/DefaultHTTPClient.swift`, protocol docs in `HTTPClient.swift`, and `Internal/RequestBuilder.swift`. All test changes are confined
to one new test file and two migrated tests in existing files. No new build targets,
no package dependency changes, no new public types beyond `DefaultHTTPClient.Configuration`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Swift Testing used instead of XCTest (Constitution II references XCTest) | Established project standard from Feature 001: plan notes prefer Swift Testing; the existing test scaffold uses `import Testing`, `@Test`, `@Suite`, and `#expect` throughout. | Reverting to XCTest would contradict plan notes, require rewriting the existing test scaffold and all prior test suites, and break the precedent set in Features 001–002. All functional requirements of Constitution II (TDD, async-capable tests, runnable via `swift test`) are fully satisfied by Swift Testing. (Identical justification to Features 001–002.) |
| Removal of `RequestConfigurator` public API constitutes a BREAKING CHANGE (MAJOR version bump from 0.0.1 → 1.0.0) | FR-008 mandates removal; keeping a deprecated dual-path API would create ambiguity between configurator mutations and `DefaultHTTPClient.Configuration` properties, and leaves the open-ended mutation surface that the feature is designed to replace. | Deprecating instead of removing would require maintaining both paths indefinitely, add complexity to assembly ordering (which wins: configurator or config?), and contradict spec A-01 and A-09. The MAJOR version bump is the correct governed response per the constitution. |
