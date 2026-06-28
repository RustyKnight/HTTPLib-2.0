# Quickstart Validation Guide: HTTPClient Library

**Feature**: `001-http-engine-library` | **Date**: 2026-06-28 | **Phase 1**

This guide describes how to validate that the `HTTPClient` library feature has been
implemented correctly end-to-end. It is intended to be used after implementation is
complete (once `tasks.md` has been executed) to confirm each user story passes its
acceptance criteria.

For type details see [`data-model.md`](data-model.md).
For API signatures see [`contracts/public-api.md`](contracts/public-api.md).

---

## Prerequisites

- macOS 14 or later
- Swift 6.0 toolchain (`swift --version` should report `Swift version 6.x`)
- Repository cloned and on branch `001-http-engine-library`
- No external network access or external services required — all tests use
  `MockURLProtocol` to intercept and stub URLSession requests

---

## Build & Test

```bash
# From the repository root:
swift build          # Expected: zero warnings, zero errors
swift test           # Expected: all test suites pass with zero failures
```

If `swift build` emits any warnings, the build is non-compliant with
Constitution I. All warnings must be resolved before tasks can be marked done.

---

## Validation Scenarios by User Story

### Story 1 — Basic HTTP Requests (P1)

**Goal**: GET, POST (no body), PUT (no body), DELETE (no body) all work with a
URL-only call and return the stubbed status code.

```bash
swift test --filter HTTPClientGetTests
swift test --filter HTTPClientPostTests
swift test --filter HTTPClientPutTests
swift test --filter HTTPClientDeleteTests
```

**Expected outcomes**:
- `engine.get(url)` returns an `HTTPResponse` with `statusCode` equal to the value
  `MockURLProtocol` was configured to return.
- `engine.post(url)` / `put(url)` / `delete(url)` (no body) behave identically.
- An unreachable host or network-level failure produces `HTTPClientError.networkError`,
  not a raw system error.
- A server response with status `404` is returned in `HTTPResponse.statusCode`,
  **not** thrown as an error.

---

### Story 2 — Request Body Variants (P2)

**Goal**: POST and PUT with `.text`, `.binary`, and `.json` bodies transmit the
correct payload and `Content-Type` header.

```bash
swift test --filter HTTPClientPostTests
swift test --filter HTTPClientPutTests
```

**Expected outcomes for each body variant** (verified by inspecting the
`URLRequest` captured by `MockURLProtocol`):

| Variant | `httpBody` | `Content-Type` header |
|---------|-----------|----------------------|
| `.text("hello")` | UTF-8 bytes of `"hello"` | `text/plain; charset=utf-8` |
| `.binary(data)` | `data` verbatim | *(not set by library)* |
| `.json(model)` | Valid JSON representation of `model` | `application/json` |

- A `.json` body for a type that fails encoding (e.g., a custom type with a
  throwing `encode` implementation) throws `HTTPClientError.jsonEncodingFailed`
  **before** `MockURLProtocol` receives any request.

---

### Story 3 — Per-Request Custom Headers (P3)

**Goal**: Caller-supplied headers appear in the outbound request; library headers
take precedence on conflict.

```bash
swift test --filter HTTPClientHeaderTests
```

**Expected outcomes**:
- A `headers` dictionary with custom keys/values is present in
  `URLRequest.allHTTPHeaderFields` as captured by `MockURLProtocol`.
- Omitting `headers` (nil) results in no unexpected headers beyond library-managed
  ones (`Content-Type` for body requests).
- Supplying `Content-Type: text/xml` alongside a `.json` body results in
  `Content-Type: application/json` in the outbound request (library wins).

---

### Story 4 — URLSession and URLRequest Customisation (P4)

**Goal**: A custom `URLSession` is used for all requests; the `RequestConfigurator`
callback can mutate the request before dispatch.

```bash
swift test --filter HTTPClientGetTests
swift test --filter HTTPClientPostTests
```

**Expected outcomes**:
- `HTTPClient(session: customSession)` routes requests through `customSession`
  (verified by registering `MockURLProtocol` on `customSession`'s configuration).
- `HTTPClient()` (no session argument) uses a default session that also performs
  the request without error.
- `HTTPClient(configurator: { $0.timeoutInterval = 5 })` results in
  `URLRequest.timeoutInterval == 5` in the request `MockURLProtocol` receives.
- A nil `configurator` produces no mutation.

---

### Story 5 — Multipart Form-Data POST (P5)

**Goal**: A multipart POST with `.file`, `.data`, and `.property` items produces a
well-formed RFC 2046 body; validation errors fire before network activity.

```bash
swift test --filter MultipartEncoderTests
swift test --filter HTTPClientMultipartTests
```

**Expected outcomes — `MultipartEncoderTests`** (no URLSession; encoder tested directly):

- The encoded `Data` opens with `--<boundary>\r\n` and closes with
  `--<boundary>--\r\n`.
- Each part has a `Content-Disposition: form-data; name="<name>"` line.
- A `.file` part body matches the bytes of the file at the given URL; its
  `Content-Disposition` includes `filename="<fileName>"` when `fileName` is set.
- A `.data` part body matches the supplied `Data`.
- A `.property` part body matches the supplied `value` encoded as UTF-8.
- An explicit `mimeType` on any item sets `Content-Type: <mimeType>` for that part;
  omitting `mimeType` uses the default (`application/octet-stream` or `text/plain`).

**Expected outcomes — `HTTPClientMultipartTests`** (full engine + mock session):

- `engine.post(url, formItems: [])` throws `HTTPClientError.emptyFormItems`
  **before** `MockURLProtocol` receives any request.
- `engine.post(url, formItems: [.property(name: "", value: "x")])` throws
  `HTTPClientError.emptyFormItemName`.
- A valid multipart call results in a request at `MockURLProtocol` with
  `Content-Type: multipart/form-data; boundary=----Boundary-<UUID>`.

---

### Cancellation (Edge Case)

**Goal**: A `Task` cancelled before or during a request propagates `CancellationError`
to the caller.

```bash
swift test --filter HTTPClientCancellationTests
```

**Expected outcomes**:
- A `Task` that is cancelled before the request method is called throws
  `CancellationError` at the `checkCancellation()` call (before network activity).
- A `Task` cancelled while `MockURLProtocol` holds a response in a suspended state
  (simulating an in-flight request) results in `CancellationError` reaching the caller.
- The thrown error is a raw `CancellationError`, **not** `HTTPClientError.networkError`.

---

## Interpreting Results

| Outcome | Meaning |
|---------|---------|
| All tests green | Feature is complete and correct |
| `swift build` warnings | Constitution I violation — must be resolved |
| Any test failure | Story or acceptance criterion not yet implemented |
| `CancellationError` wrapped in `HTTPClientError` | Concurrency contract broken (FR-007) |
| `networkError` thrown for a 404 response | Non-2xx handling broken (FR-008) |
| `Content-Type` set for `.binary` body | Library is over-managing headers |
| Missing `Content-Type` for `.json` body | Body variant handling incomplete |

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

Confirm `swift build` also produces zero warnings:

```bash
swift build 2>&1 | grep -c warning || echo "0 warnings"
```
