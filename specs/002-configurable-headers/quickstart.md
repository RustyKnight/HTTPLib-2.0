# Quickstart Validation Guide: Configurable Default Headers

**Feature**: `002-configurable-headers` | **Date**: 2026-06-28 | **Phase 1**

This guide describes how to validate that Feature 002 has been implemented correctly
end-to-end. Run it after the `tasks.md` implementation phase is complete to confirm
all acceptance criteria pass.

For type details see [`data-model.md`](data-model.md).
For API signatures and header-priority semantics see [`contracts/public-api.md`](contracts/public-api.md).
For the `MockURLProtocol` helper (used in all tests below) see
`Tests/HTTPLibTests/Helpers/MockURLProtocol.swift`.

---

## Prerequisites

- macOS 14 or later
- Swift 6.0 toolchain (`swift --version` should report `Swift version 6.x`)
- Repository cloned and on branch `002-configurable-headers`
- No external network access required — all tests use `MockURLProtocol`

---

## Build & Test

```bash
# From the repository root:
swift build          # Expected: zero warnings, zero errors
swift test           # Expected: ALL suites (001 regression + 002 new) pass with zero failures
```

`swift build` emitting any warning is a Constitution I violation and must be resolved
before tasks can be marked done.

---

## Feature 002 Validation Scenarios

### Story 1 — Default Headers Applied to Every Request (P1)

**Goal**: An engine initialised with `defaultHeaders` automatically includes those
headers on GET, POST, PUT, DELETE, and multipart POST requests.

```bash
swift test --filter HTTPClientDefaultHeaderTests
```

Key assertions made by the test suite (verified via `MockURLProtocol.capturedRequest`):

| Scenario | How to verify |
|----------|--------------|
| GET with `{X-API-Key: "abc123"}` default | `capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == "abc123"` |
| POST with same default | Same assertion on the POST captured request |
| PUT with same default | Same assertion on the PUT captured request |
| DELETE with same default | Same assertion on the DELETE captured request |
| Engine with `defaultHeaders: [:]` | No unexpected headers beyond library-managed ones |
| Engine with no `defaultHeaders` arg | Identical to a pre-feature `HTTPClient()` instance |

**Expected outcome**: All six scenarios pass with zero failures.

---

### Story 2 — Default and Per-Request Headers Both Applied (P2)

**Goal**: When an engine has default headers and a request call supplies per-request
headers with non-overlapping keys, both sets appear in the outbound request.

```bash
swift test --filter HTTPClientDefaultHeaderTests
```

Key assertions:

| Scenario | How to verify |
|----------|--------------|
| Default `{A: "1"}` + per-request `{B: "2"}` | `capturedRequest` contains both `A: 1` and `B: 2` |
| Default headers + nil per-request | Only default headers present (no `B` key) |
| No defaults + per-request headers | Only per-request headers present (pre-feature behaviour) |

**Expected outcome**: All three scenarios pass.

---

### Story 3 — Per-Request Headers Override Defaults on Conflict (P3)

**Goal**: When a per-request header shares a name (case-insensitively) with a
default header, the per-request value wins for that call; the stored default is
unaffected afterward.

```bash
swift test --filter HTTPClientDefaultHeaderTests
```

Key assertions:

| Scenario | How to verify |
|----------|--------------|
| Default `Authorization: default-token` + per-request `Authorization: scoped-token` | `capturedRequest?.value(forHTTPHeaderField: "Authorization") == "scoped-token"` |
| Subsequent request with no per-request `Authorization` | `capturedRequest?.value(forHTTPHeaderField: "Authorization") == "default-token"` (default restored) |
| Default `content-type: text/plain` + per-request `Content-Type: application/json` | `capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json"` (per-request wins, case-insensitive) |

**Expected outcome**: All three scenarios pass; the stored default is not mutated
between calls (verified by the second assertion above using the same engine instance).

---

### Edge Cases

```bash
swift test --filter HTTPClientDefaultHeaderTests
```

| Edge case | How to verify |
|-----------|--------------|
| Library `Content-Type` overrides a default `Content-Type: text/xml` when a JSON body is sent | `capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json"` |
| Default header with empty-string value | Header key is present in `capturedRequest?.allHTTPHeaderFields`; value is `""` |
| Default headers on multipart POST | Default header key present alongside `multipart/form-data` Content-Type (library wins on `Content-Type` conflict) |

---

## Regression Guard — Feature 001 Test Suites

Run the full Feature 001 test suite to confirm no existing behaviour regressed:

```bash
swift test --filter HTTPClientGetTests
swift test --filter HTTPClientPostTests
swift test --filter HTTPClientPutTests
swift test --filter HTTPClientDeleteTests
swift test --filter HTTPClientHeaderTests
swift test --filter HTTPClientMultipartTests
swift test --filter HTTPClientCancellationTests
swift test --filter MultipartEncoderTests
```

**Expected outcome**: All existing tests pass without modification (SC-003).
The default `nil` `defaultHeaders` argument means no change in outbound request
content for any test that does not pass `defaultHeaders`.

---

## Header Priority Spot-Check

The four-tier priority order can be spot-checked with a single test scenario:

```
Engine default: { "Content-Type": "text/xml",    "X-Default": "d" }
Per-request:    { "Content-Type": "text/csv",    "X-Request": "r" }
Body:           .json(someModel)     ← triggers library Content-Type
Configurator:   { $0.setValue("configurator", forHTTPHeaderField: "X-Config") }
```

Expected outbound request headers:

| Header | Expected value | Won by |
|--------|---------------|--------|
| `Content-Type` | `application/json` | Library (tier 3) |
| `X-Default` | `d` | Default (tier 1) |
| `X-Request` | `r` | Per-request (tier 2) |
| `X-Config` | `configurator` | Configurator (tier 4) |

This scenario is covered by `HTTPClientDefaultHeaderTests` and verifies all four
tiers interact correctly in a single request.

---

## Full Test Suite Run

After all stories are implemented, run the complete suite as a final gate:

```bash
swift test 2>&1 | tail -5
```

A passing output looks like:

```
Test Suite 'All tests' passed at …
     Executed N tests, with 0 failures (0 unexpected) in …
```

Confirm zero warnings:

```bash
swift build 2>&1 | grep -c warning || echo "0 warnings"
```

---

## Interpreting Results

| Outcome | Meaning |
|---------|---------|
| All tests green, zero `swift build` warnings | Feature complete and compliant |
| Default header absent from outbound request | FR-002 not implemented, or step 1 of merge missing |
| Per-request does not override default | FR-004 merge order inverted |
| Library `Content-Type` absent with JSON body | FR-005 / step 3 broken |
| Default header mutated after a conflicting request | FR-007 violated — defaultHeaders must be stored as `let` |
| Existing Feature 001 tests regress | Backward-compatibility broken — check init parameter default and RequestBuilder signature |
| `swift build` warning about `Sendable` | `[String: String]` stored property not declared `let` |
