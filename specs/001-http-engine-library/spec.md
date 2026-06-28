# Feature Specification: HTTPClient Library

**Feature Branch**: `001-http-engine-library`

**Created**: 2026-06-28

**Status**: Draft

**Input**: User description: "Build a simple HTTP library which covers all the major methods of the protocol called `HTTPClient`. The intention is to provide a simple, re-usable HTTP implementation." (Sources/Feature-HTTPLibrary.md)

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic HTTP Requests (Priority: P1)

A developer using the library needs to issue GET, POST, PUT, and DELETE requests by supplying only a URL. The call returns a structured response containing the HTTP status code and an optional response body as raw bytes. No additional configuration is required for the simplest case — one argument, one call.

**Why this priority**: This is the foundational contract of the library. Every other story builds on it. Without working bare-minimum requests the library cannot be integrated at all.

**Independent Test**: Can be fully tested by calling each of the four methods with a URL against a mock session and asserting the returned status code equals the session's stubbed response. No real network required; delivers a minimal working HTTP client.

**Acceptance Scenarios**:

1. **Given** a valid URL, **When** `GET` is called with no additional parameters, **Then** the library returns the HTTP status code and optional response body data.
2. **Given** a valid URL, **When** `POST`, `PUT`, or `DELETE` is called with no body and no headers, **Then** the library returns the HTTP status code and optional response body data.
3. **Given** an invalid URL or unreachable host, **When** any method is called, **Then** a typed error is thrown; no silent failure or raw system error is surfaced.
4. **Given** a server that returns a non-2xx status code, **When** any method is called, **Then** the non-2xx status is returned to the caller without throwing; the caller decides how to handle it.

---

### User Story 2 - Request Body Variants (Priority: P2)

A developer needs to send POST or PUT requests with a structured body. The library supports three body forms: a plain text string, raw binary data, or any `Encodable` value automatically serialised as JSON. The developer supplies whichever variant fits their use case.

**Why this priority**: POST and PUT without body support is incomplete for the vast majority of REST API interactions. This is the next most commonly needed capability after basic requests.

**Independent Test**: Can be tested in isolation by sending each body variant to a request-echo mock and verifying the captured request body matches the supplied value.

**Acceptance Scenarios**:

1. **Given** a POST or PUT call with a plain text body, **When** the request is sent, **Then** the text is transmitted as the request payload with `Content-Type: text/plain`.
2. **Given** a POST or PUT call with a raw Data body, **When** the request is sent, **Then** the raw bytes are transmitted as the request payload.
3. **Given** a POST or PUT call with an `Encodable` value, **When** the request is sent, **Then** the value is serialised as JSON and transmitted with `Content-Type: application/json`.
4. **Given** an `Encodable` value that fails JSON serialisation, **When** the request is prepared, **Then** a typed encoding error is thrown before any network activity begins.
5. **Given** a DELETE call with an optional body, **When** the body is omitted, **Then** no body is included in the outbound request.

---

### User Story 3 - Per-Request Custom Headers (Priority: P3)

A developer needs to attach custom HTTP headers to individual requests — for example `Authorization`, `Accept`, or `X-API-Key`. Headers are provided per-call and do not persist across separate requests.

**Why this priority**: Authenticated and content-negotiated APIs require custom headers. Without this, the library is unusable against any real-world secured endpoint.

**Independent Test**: Can be tested by supplying a custom headers dictionary to any method with a mock session, then inspecting the captured `URLRequest` to confirm each header is present.

**Acceptance Scenarios**:

1. **Given** a request call with a headers dictionary, **When** the request is sent, **Then** each key/value pair in the dictionary appears as an HTTP header in the outbound request.
2. **Given** no headers dictionary is supplied, **When** the request is sent, **Then** no custom headers are added beyond those the library requires internally (e.g., `Content-Type` for body requests).
3. **Given** a caller-supplied header whose key conflicts with a required internal header (e.g., `Content-Type` on a multipart request), **When** the request is assembled, **Then** the library's internally required value takes precedence and the caller-supplied value is overridden.

---

### User Story 4 - URLSession and URLRequest Customisation (Priority: P4)

A developer needs fine-grained control over the underlying request mechanism. They can supply a custom `URLSession` (e.g., a mock session for unit testing, or a session with a custom timeout configuration) and/or provide a configuration callback that modifies the `URLRequest` object before it is dispatched — allowing access to settings the library does not expose as first-class parameters.

**Why this priority**: Testability of consumer code requires injectable sessions. Without this, any code using the library cannot be unit-tested without real network calls.

**Independent Test**: Can be tested by injecting a mock `URLSession` and asserting the library routes its request through it rather than a default shared session.

**Acceptance Scenarios**:

1. **Given** a custom `URLSession` is provided to `HTTPClient`, **When** any request method is called, **Then** all network activity is routed through the supplied session.
2. **Given** no `URLSession` is provided, **When** any request method is called, **Then** the library uses a sensible default (e.g., `URLSession.shared` or a default-configured session).
3. **Given** a `URLRequest` customisation callback is supplied, **When** the internal `URLRequest` has been assembled, **Then** the callback is invoked with the assembled request before dispatch, and any mutations the callback makes are applied to the final outbound request.

---

### User Story 5 - Multipart Form-Data POST (Priority: P5)

A developer needs to upload files or structured form data using multipart form-data encoding. They supply a list of form items; the library handles boundary generation, part encoding, and `Content-Type` header management automatically. Three item types are supported: a file reference (URL to a file on disk), raw bytes, and a simple name/value text property.

**Why this priority**: File upload is a non-trivial, distinct capability with its own encoding rules (RFC 2046). It is independently testable and provides significant value for any API that accepts file uploads.

**Independent Test**: Can be tested by constructing a multipart request with at least one item of each type and verifying the encoded body is well-formed (correct boundary markers, `Content-Disposition` headers, payload bytes) without a real network call.

**Acceptance Scenarios**:

1. **Given** a multipart POST call with one or more form items, **When** the request is sent, **Then** the body is encoded as RFC 2046 multipart/form-data with a unique boundary, and the `Content-Type` header is set to `multipart/form-data; boundary=<boundary>`.
2. **Given** a `file` form item with a valid file URL, **When** encoded, **Then** the file contents are read and included as the part body; `Content-Disposition` includes `name` and, if provided, `filename`; `Content-Type` is set to the supplied `mimeType` or `application/octet-stream` by default.
3. **Given** a `file` form item with a URL pointing to a non-existent or unreadable file, **When** the request is prepared, **Then** a typed file-read error is thrown before any network activity begins.
4. **Given** a `data` form item with raw bytes, **When** encoded, **Then** the raw bytes are included as the part body with correct `Content-Disposition`; `Content-Type` defaults to `application/octet-stream` unless an explicit `mimeType` is supplied.
5. **Given** a `property` form item with a name/value pair, **When** encoded, **Then** the value is included as a text part body with `Content-Disposition: form-data; name="<name>"`; `Content-Type` defaults to `text/plain` unless explicitly overridden.
6. **Given** an explicit `mimeType` on any form item, **When** the part is encoded, **Then** the `Content-Type` header for that part is set to the supplied value.
7. **Given** an empty form items list, **When** the multipart POST is called, **Then** a validation error is thrown; an empty multipart POST is treated as a programming error.
8. **Given** any form item with an empty `name` string, **When** the request is prepared, **Then** a validation error is thrown.

---

### Edge Cases

- What happens when a file URL points to a non-existent or unreadable file? → A typed error is thrown before the request is dispatched; no partial request is sent.
- What happens when an `Encodable` value fails JSON serialisation? → A typed encoding error is thrown before network activity begins.
- What happens when the server returns a non-2xx status code? → The status code is returned to the caller; the library does not throw for HTTP-level status errors.
- What happens when a network task is cancelled while in-flight? → `CancellationError` is propagated to the caller as per Swift Concurrency semantics.
- What happens when an empty form items list is supplied to multipart POST? → A precondition / validation error is thrown (see A-03).
- What happens when a form item `name` is an empty string? → A validation error is thrown before encoding begins.
- What happens when a caller-supplied header conflicts with a required library header (e.g., `Content-Type` on multipart)? → The library's value takes precedence.
- What happens when the `URLRequest` customisation callback overrides the HTTP method set by the library? → Behaviour is undefined / caller's responsibility; the library does not guard against this.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The library MUST expose a primary type named `HTTPClient` that serves as the entry point for all HTTP operations.
- **FR-002**: `HTTPClient` MUST provide operations for the GET, POST, PUT, and DELETE HTTP methods.
- **FR-003**: All HTTP method operations MUST accept a `URL` as the only required argument; all other parameters MUST be optional with sensible defaults.
- **FR-004**: All HTTP method operations MUST return a response value that includes the integer HTTP status code and an optional raw response body.
- **FR-005**: All HTTP method operations MUST be asynchronous; blocking the caller's execution context is prohibited.
- **FR-006**: All failure paths (network errors, encoding errors, file-read errors) MUST be surfaced as typed thrown errors; no failure path may silently discard an error or return a partial result.
- **FR-007**: The library MUST propagate task cancellation to the caller; a cancelled in-flight request MUST result in a cancellation error reaching the caller.
- **FR-008**: Non-2xx HTTP status codes MUST NOT cause the library to throw; the status code MUST be returned to the caller for caller-side interpretation.
- **FR-009**: All HTTP method operations MUST accept an optional dictionary of HTTP header name/value pairs; each entry MUST be transmitted as a header in the outbound request.
- **FR-010**: `HTTPClient` MUST accept an optional custom session object; all network operations MUST be routed through it when provided, falling back to a default session when absent.
- **FR-011**: `HTTPClient` MUST accept an optional `URLRequest` configuration callback; when provided, it MUST be invoked with the assembled request immediately before dispatch, and all mutations MUST be applied.
- **FR-012**: POST and PUT MUST accept an optional request body in one of three variants: plain text, raw binary data, or an `Encodable` value serialised as JSON.
- **FR-013**: DELETE MAY accept an optional request body using the same variants as POST/PUT.
- **FR-014**: GET MUST NOT accept a request body through the standard body parameter (see A-02).
- **FR-015**: POST MUST provide a separate multipart form-data operation that accepts a list of form items.
- **FR-016**: A form item MUST carry a `name` field (required, non-empty); `fileName` and `mimeType` MUST be optional.
- **FR-017**: Form items MUST support three variants: a `file` item (URL reference to a file on disk), a `data` item (raw bytes), and a `property` item (name/value string pair).
- **FR-018**: The multipart POST operation MUST automatically generate a unique boundary, encode all parts according to RFC 2046 multipart/form-data rules, and set the `Content-Type` request header accordingly.
- **FR-019**: When no explicit `mimeType` is supplied for a `file` or `data` item, the library MUST default to `application/octet-stream`; for a `property` item the default MUST be `text/plain`.
- **FR-020**: A multipart POST call with an empty form items list MUST throw a validation error.
- **FR-021**: A form item with an empty `name` string MUST cause a validation error before any encoding or network activity.

### Key Entities

- **HTTPClient**: The library's primary type. Holds the session reference and any default configuration. Provides GET, POST, PUT, DELETE, and multipart POST operations. Instances are reusable across multiple requests.
- **HTTPResponse**: The value returned by every HTTP operation. Carries: the integer HTTP status code; an optional `Data` value representing the raw response body.
- **FormItem**: A discriminated union representing one part of a multipart form-data upload. Has three variants:
  - **file** — References a file on disk. Fields: `name` (required String), file `URL` (required), `fileName` (optional String), `mimeType` (optional String, defaults to `application/octet-stream`).
  - **data** — Carries raw bytes. Fields: `name` (required String), body `Data` (required), `fileName` (optional String), `mimeType` (optional String, defaults to `application/octet-stream`).
  - **property** — A text name/value pair. Fields: `name` (required String), `value` String (required), `mimeType` (optional String, defaults to `text/plain`).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can issue a GET request by supplying only a URL — the call site requires no more than a single argument.
- **SC-002**: All four HTTP methods are exercised by a complete automated test suite that passes with zero failures and zero external network dependencies.
- **SC-003**: A multipart POST with at least one item of each type (`file`, `data`, `property`) produces a well-formed multipart/form-data payload that is accepted without error by a reference validator or mock test harness.
- **SC-004**: Cancellation of an in-flight request reliably surfaces a cancellation error to the caller in 100% of test runs.
- **SC-005**: Each subsequently added capability (body variants, multipart, header support) introduces zero breaking changes to the existing public API surface of prior stories.
- **SC-006**: The library builds with zero compiler warnings and all public API methods have corresponding passing unit tests.

---

## Assumptions

- **A-01**: `HTTPClient` is a concrete type (struct or class). An injectable session covers testability requirements; a protocol abstraction of the engine itself is deferred to a future version if needed.
- **A-02**: The `GET` operation does not accept a standard request body parameter. GET bodies are non-standard; callers requiring unusual GET semantics may use the `URLRequest` customisation callback.
- **A-03**: Supplying an empty form items list to the multipart POST operation is treated as a programmer error and results in a thrown validation error rather than an empty multipart body being sent.
- **A-04**: Form item `name` values must be non-empty strings; an empty `name` triggers a validation error before any encoding begins.
- **A-05**: The library does not decode response bodies; it returns raw `Data` and delegates JSON/text parsing to the caller.
- **A-06**: Redirect handling follows platform-default `URLSession` behaviour; the library does not add custom redirect logic.
- **A-07**: Concurrent use of the same `HTTPClient` instance across multiple Swift `Task`s is safe; individual request operations do not share mutable state between invocations.
- **A-08**: Platform target is macOS 14+, Swift 6.0, distributed exclusively via Swift Package Manager, per the project constitution. No third-party networking dependencies are introduced.
- **A-09**: The boundary string for multipart encoding is generated per-request (e.g., a UUID-derived string); callers cannot supply a custom boundary.
- **A-10**: When a caller-supplied `URLRequest` customisation callback overrides the HTTP method set by the library, the resulting behaviour is the caller's responsibility; the library does not guard against this.
