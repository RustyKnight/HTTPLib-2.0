<!--
## Sync Impact Report

**Version change**: (none) → 1.0.0 — initial constitution, first fill of template.

**Principles defined**:
- I. Code Quality (new)
- II. Testing Standards (new)
- III. API User Experience (new)
- IV. Performance & Reliability (new)
- V. Modern Standards & Architecture (new)

**Sections added**: Technology & Platform Constraints, Quality Gates

**Templates reviewed**:
- `.specify/templates/plan-template.md` ✅ no changes required (Constitution Check gate is generic)
- `.specify/templates/spec-template.md` ✅ no changes required
- `.specify/templates/tasks-template.md` ✅ no changes required
- `.specify/templates/checklist-template.md` ✅ no changes required

**Inferred from project** (source doc was a one-sentence directive):
- Swift 6.0 / macOS 14+ / SPM — from Package.swift
- URLSession as engine — from Feature-HTTPLibrary.md
- HTTP methods scope (GET, POST, PUT, DELETE) — from Feature-HTTPLibrary.md
- No ratification date prior to today — marked as first ratification

**Deferred TODOs**: none
-->

# HTTPLib-2.0 Constitution

## Core Principles

### I. Code Quality

All Swift code MUST conform to the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
Public API surfaces MUST use explicit types, clear naming, and MUST NOT contain force-unwraps (`!`)
or `fatalError` calls except where a programming error is truly irrecoverable.
The codebase MUST compile with zero warnings at the target Swift version.
Complexity MUST be justified — prefer the simplest correct solution (YAGNI).

**Rationale**: A shared library is only as trustworthy as its code is readable. Consistent style and
zero warnings reduce maintenance cost and make integration errors obvious at compile time.

### II. Testing Standards (NON-NEGOTIABLE)

TDD is mandatory: tests MUST be written, reviewed, and confirmed to fail before any implementation
code is written (Red → Green → Refactor).
Every public API method MUST have corresponding XCTest unit tests.
Async methods MUST be tested with `async`/`await` test bodies — no callback shims.
Tests MUST be independent, deterministic, and runnable via `swift test` without external services.

**Rationale**: An HTTP library is safety-critical infrastructure. Untested behaviour is undefined
behaviour. The Red-Green-Refactor discipline prevents implementation bias in test design.

### III. API User Experience

The public API MUST follow a progressive-disclosure model: the simplest use case MUST require the
fewest arguments (URL only, for methods that need nothing else).
All parameters beyond URL MUST be optional with sensible defaults.
Errors MUST be propagated as typed `throws` (not string messages or `NSError` codes) so callers
can handle them programmatically.
Naming MUST be Swifty: verb-first method names, no redundant type names, consistent argument labels.

**Rationale**: HTTPLib is a consumer-facing reusable library. Every additional required parameter
is friction. Typed errors enable callers to write exhaustive error handling without string parsing.

### IV. Performance & Reliability

All network operations MUST use Swift Concurrency (`async`/`await`) — blocking calls on any thread
are prohibited.
The library MUST respect task cancellation: every network operation MUST propagate
`CancellationError` when its Swift `Task` is cancelled.
The library MUST NOT retain strong references beyond the lifetime of a single request unless
explicitly documented.
No operation MUST silently discard errors; all failure paths MUST surface a typed error to the
caller.

**Rationale**: Consumers embed this library in apps and services with their own concurrency models.
Predictable cancellation, structured concurrency, and no silent failures make integration safe.

### V. Modern Standards & Architecture

The library MUST target Swift 6.0+ and macOS 14+ (as declared in Package.swift).
`URLSession` and `URLRequest` are the canonical HTTP engine — no third-party networking
dependencies are permitted.
All public types that cross concurrency boundaries MUST conform to `Sendable`.
Distribution MUST be Swift Package Manager only; no CocoaPods or Carthage support is required.

**Rationale**: Swift 6 strict concurrency checking catches data-race bugs at compile time.
Confining to platform-native APIs keeps the dependency graph flat and the package lightweight.

## Technology & Platform Constraints

- **Language**: Swift 6.0 (swift-tools-version 6.0)
- **Minimum platform**: macOS 14
- **Build & distribution**: Swift Package Manager (`Package.swift` at repository root)
- **HTTP engine**: `URLSession` / `URLRequest` (Foundation) — no third-party deps
- **Testing framework**: XCTest (via `.testTarget("HTTPLibTests")`)
- **Supported HTTP methods**: GET, POST, PUT, DELETE (scope defined in `Features/Feature-HTTPLibrary.md`)

## Quality Gates

Every PR MUST satisfy all of the following before merge:

- `swift build` succeeds with zero warnings
- `swift test` passes with zero failures
- New or changed public API has new or updated XCTest coverage
- No new force-unwraps or `fatalError` calls in public API without documented justification
- Breaking public API changes MUST be flagged and MUST be accompanied by a MAJOR version bump
  in `Package.swift`

## Governance

This constitution supersedes all other development practices for HTTPLib-2.0.
Amendments require: (1) a written rationale, (2) a version bump per the policy below, and
(3) an update to this file committed to the default branch.

**Versioning policy**:
- **MAJOR**: Principle removed, redefined, or governance rules materially weakened.
- **MINOR**: New principle or section added; existing principle materially expanded.
- **PATCH**: Clarification, wording fix, or non-semantic refinement.

All PRs and code reviews MUST verify compliance with the Core Principles above.
Any complexity that violates a principle MUST be documented in the plan's Complexity Tracking
table with explicit justification.

**Version**: 1.0.0 | **Ratified**: 2026-06-28 | **Last Amended**: 2026-06-28
