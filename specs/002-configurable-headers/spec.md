# Feature Specification: Configurable Default Headers

**Feature Branch**: `002-configurable-headers`

**Created**: 2026-06-28

**Status**: Draft

**Input**: User description: "Add support for the user to supply default header values via the initialiser, which are applied automatically with each request, in addition to any headers passed to the method functions." (Features/002-ConfigurableHeaders/Feature-ConfigurableHeaders.md)

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Default Headers Applied to Every Request (Priority: P1)

A developer configures an `HTTPEngine` instance with a set of default HTTP headers at construction time (for example, `Authorization`, `X-API-Key`, or `User-Agent`). Every request subsequently issued through that instance automatically carries those headers without the developer repeating them on each call.

**Why this priority**: This is the entire value proposition of the feature. Without it the feature does not exist. It is fully self-contained and independently testable without any other story.

**Independent Test**: Can be fully tested by constructing an engine with a non-empty default headers dictionary, issuing any request method against a mock session, and asserting that the captured outbound request contains each default header key/value pair.

**Acceptance Scenarios**:

1. **Given** an engine initialised with default headers `{X-API-Key: "abc123"}`, **When** a GET request is made, **Then** the outbound request contains the header `X-API-Key: abc123`.
2. **Given** an engine initialised with default headers, **When** a POST, PUT, or DELETE request is made, **Then** the outbound request contains those same default headers.
3. **Given** an engine initialised with an empty default headers dictionary, **When** any request is made, **Then** no additional headers are added beyond those the library sets internally.
4. **Given** an engine initialised without a default headers argument, **When** any request is made, **Then** behaviour is identical to the pre-feature baseline (no default headers are present).

---

### User Story 2 - Default Headers and Per-Request Headers Are Both Applied (Priority: P2)

A developer uses an engine configured with default headers, but also supplies per-request headers on individual method calls. Both sets appear in the outbound request whenever their key sets do not overlap.

**Why this priority**: The feature description explicitly states headers are applied "in addition to any headers passed to the method functions." Verified merge behaviour is the feature's second most critical contract — it is the mechanism that makes the feature composable with the existing per-request header capability.

**Independent Test**: Can be tested by constructing an engine with default header `X-Default: "d"` and issuing a request with per-request header `X-Request: "r"`, then asserting both keys appear in the captured outbound request.

**Acceptance Scenarios**:

1. **Given** an engine with default headers `{A: "1"}` and a request call with per-request headers `{B: "2"}`, **When** the request is assembled, **Then** the outbound request contains both `A: 1` and `B: 2`.
2. **Given** an engine with default headers and a request call with no per-request headers, **When** the request is assembled, **Then** the outbound request contains the full default headers set.
3. **Given** an engine with no default headers and a request call with per-request headers, **When** the request is assembled, **Then** the outbound request contains only the per-request headers (prior behaviour is unchanged).

---

### User Story 3 - Per-Request Headers Override Default Headers on Conflict (Priority: P3)

A developer needs to override one default header for a single request — for example, swap a general authorisation token for a narrowly scoped one — without reconstructing the engine. The per-request value takes precedence for that call only; all other defaults and all future requests remain unaffected.

**Why this priority**: Conflict resolution is a necessary consequence of merging two header sets. Without a defined and predictable rule the feature is unreliable in any real-world integration scenario.

**Independent Test**: Can be tested by constructing an engine with default `Authorization: default-token`, issuing one request with per-request `Authorization: scoped-token` and asserting the outbound request carries `scoped-token`; then issuing a second request with no per-request `Authorization` and asserting it carries `default-token`.

**Acceptance Scenarios**:

1. **Given** an engine with default header `Authorization: default-token` and a request call with per-request header `Authorization: scoped-token`, **When** the request is assembled, **Then** the outbound request carries `Authorization: scoped-token`.
2. **Given** the same engine immediately after the scenario above, **When** a subsequent request is made with no per-request `Authorization` header, **Then** the outbound request carries `Authorization: default-token` (the stored default is unmodified).
3. **Given** a conflicting header name where the default and per-request entries differ only in casing (e.g., `content-type` vs `Content-Type`), **When** the request is assembled, **Then** the conflict is detected case-insensitively and the per-request value prevails.

---

### Edge Cases

- What happens when default headers and per-request headers share a key? → The per-request value takes precedence for that request; the stored default is never mutated.
- What happens when a default header name matches a library-internal required header (e.g., the `Content-Type` set automatically for JSON body encoding)? → The library's internally required value takes precedence, consistent with the existing policy from Feature 001.
- What happens when a default header value is an empty string? → The header is transmitted in the request with an empty value; empty-value headers are valid per HTTP and are not stripped.
- What happens when the default headers dictionary is nil or empty? → No additional headers are added; behaviour is identical to a pre-feature engine instance.
- What happens when header keys in the two dictionaries differ only by letter casing? → The conflict is detected case-insensitively; the per-request value wins regardless of casing differences.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `HTTPEngine` MUST accept an optional default headers parameter at initialisation; when omitted or supplied as an empty dictionary, all request behaviour MUST be identical to the pre-feature baseline.
- **FR-002**: When `HTTPEngine` is initialised with a non-empty default headers dictionary, EVERY request dispatched through that instance MUST include those headers in the outbound request.
- **FR-003**: Default headers MUST be merged with per-request headers supplied on any individual method call; when no key conflict exists, both sets MUST appear in the outbound request.
- **FR-004**: When a per-request header and a default header share the same header name (compared case-insensitively), the per-request value MUST take precedence for that request; the stored default headers MUST NOT be mutated.
- **FR-005**: When a default header name conflicts with a library-internal required header (such as the `Content-Type` set automatically for body encoding), the library's internally required value MUST take precedence, consistent with the precedence policy established in Feature 001.
- **FR-006**: The default headers parameter type MUST match the existing per-request headers parameter type; no new public types are introduced by this feature.
- **FR-007**: Default headers stored on an `HTTPEngine` instance MUST be immutable after initialisation; this feature MUST NOT introduce any method or property for mutating stored default headers post-construction.
- **FR-008**: The public API signatures of all existing HTTP method operations (GET, POST, PUT, DELETE, multipart POST) MUST remain unchanged; default headers MUST be applied transparently inside the engine without altering any method call site.

### Key Entities

- **HTTPEngine** (updated): Gains a stored default headers property populated at initialisation and immutable thereafter. No other change to its public surface is required by this feature.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can configure shared headers once at engine construction and have them transmitted on every subsequent request without any per-call repetition at the call site.
- **SC-002**: An automated test suite covering all three user stories passes with zero failures and zero external network dependencies.
- **SC-003**: No existing tests from Feature 001 regress as a result of this feature; the default headers parameter is purely additive and fully backward-compatible (opt-in via an optional parameter with a safe default).
- **SC-004**: The conflict resolution policy (per-request overrides default; library-internal overrides both) is verified by at least three distinct automated test cases.
- **SC-005**: The library builds with zero compiler warnings after this feature is added, per the project constitution Quality Gates.

---

## Assumptions

- **A-01**: The header precedence order, from highest to lowest, is: library-internal required headers → per-request caller headers → instance default headers. This "most-specific wins" rule is consistent with the internal-vs-caller precedence already established in Feature 001 (US-3, A-03).
- **A-02**: Default headers are immutable after `HTTPEngine` initialisation. Dynamic mutation of default headers after construction (add, remove, update) is out of scope for this feature; it may be addressed separately if needed.
- **A-03**: Header name comparison for conflict detection uses case-insensitive matching, consistent with RFC 7230 §3.2. The implementation may normalise header names at the point of merging.
- **A-04**: An `HTTPEngine` instance configured with default headers remains safe for concurrent use across multiple requests because the default headers value is fixed at construction and never mutated (see A-02), which prevents any data race on the stored headers.
- **A-05**: The default headers parameter uses the same type as the per-request headers parameter introduced in Feature 001. No new public type is introduced for default headers.
- **A-06**: A default header with an empty string value is treated as a valid header and is transmitted in the request. The library does not strip or reject empty-value headers.
