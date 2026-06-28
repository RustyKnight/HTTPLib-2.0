# Feature Specification: Request Configuration Struct

**Feature Branch**: `003-request-configuration`

**Created**: 2026-06-28

**Status**: Draft

**Input**: Feature source: "Features/003-Configuration/Feature.md" — "Change the configuration workflow from a closure based workflow to a direct `struct` which carries the properties which are then applied to the `URLRequest` whenever it's created. Supply a default implementation which is applied automatically as a default parameter value when the user does not supply one. This should cover the configurable properties of the `URLRequest` which are not otherwise set up by the engine."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Zero-Config Default Behaviour (Priority: P1)

A developer using `HTTPClient` does not supply any configuration when making requests. The engine automatically applies a built-in default configuration to every outgoing request, giving requests predictable, sensible behaviour without any developer effort. From the call site, the API looks and behaves exactly as it did before this feature was introduced — the default configuration is invisible.

**Why this priority**: This is the migration safety baseline. Every existing call site must continue to work with no change. The built-in default must produce behaviour equivalent to the platform-standard `URLRequest` defaults. Without this, the feature breaks all existing consumers.

**Independent Test**: Can be fully tested by issuing any HTTP method call without a configuration argument and asserting the assembled `URLRequest` carries the property values encoded in the built-in default configuration. No real network required; a mock session captures the request for inspection.

**Acceptance Scenarios**:

1. **Given** any request method (GET, POST, PUT, DELETE, multipart POST) is called without a configuration argument, **When** the `URLRequest` is assembled, **Then** all configuration properties reflect the values defined by the built-in default configuration.
2. **Given** the built-in default configuration, **When** its property values are compared to the equivalent `URLRequest` platform defaults, **Then** they are identical; the default configuration introduces no observable behavioural change relative to the pre-feature baseline.
3. **Given** an `HTTPClient` instance created without any change to its existing initialiser parameters, **When** requests are made without a configuration argument, **Then** all existing tests from Feature 001 and Feature 002 pass unmodified.

---

### User Story 2 - Custom Engine-Level Configuration (Priority: P2)

A developer needs to tune specific transport parameters for all requests through an engine — for example, extending the timeout for a slow endpoint, disabling cellular access for a metered-connection policy, or adjusting cache behaviour. They construct a configuration value carrying their desired settings and pass it to `HTTPClient` at initialisation. The engine stores the configuration immutably and applies exactly those settings to every `URLRequest` it assembles.

**Why this priority**: This is the primary value of the feature. The struct replaces the previous closure-based mechanism and must cover the same configurable `URLRequest` properties with a simpler, more auditable API. Without this story, the feature delivers no capability beyond the status quo.

**Independent Test**: Can be tested independently by creating an `HTTPClient` with a configuration carrying a custom timeout duration, making a request against a mock session, and asserting the captured `URLRequest` carries that exact timeout duration.

**Acceptance Scenarios**:

1. **Given** an engine initialised with a configuration carrying a custom timeout duration, **When** any request is dispatched, **Then** the outgoing `URLRequest` carries that exact timeout duration.
2. **Given** an engine initialised with a configuration carrying a non-default cache policy, **When** any request is dispatched, **Then** the outgoing `URLRequest` carries that exact cache policy.
3. **Given** an engine initialised with a configuration with cellular access disabled, **When** any request is dispatched, **Then** the outgoing `URLRequest` carries the cellular access restriction.
4. **Given** an engine initialised with a configuration with expensive-network access disabled, **When** any request is dispatched, **Then** the outgoing `URLRequest` carries the expensive-network access restriction.
5. **Given** an engine initialised with a configuration with constrained-network access disabled, **When** any request is dispatched, **Then** the outgoing `URLRequest` carries the constrained-network access restriction.
6. **Given** an engine initialised with a configuration with cookie handling disabled, **When** any request is dispatched, **Then** the outgoing `URLRequest` carries the cookie handling restriction.
7. **Given** an engine initialised with a configuration carrying multiple non-default properties set simultaneously, **When** any request is dispatched, **Then** all of the non-default properties are applied to the outgoing `URLRequest`; none are silently ignored.

---

### User Story 3 - Configuration Is Consistent Across All Requests on an Engine (Priority: P3)

A developer creates an `HTTPClient` instance with a specific configuration. Every request dispatched through that engine — regardless of call order or concurrency — consistently carries that engine's configuration. No configuration state leaks between engines, and the configuration value is not mutated by any request call.

**Why this priority**: Consistency is a safety property that underpins correct concurrent use. Without it, developers cannot reliably reason about the transport settings applied to requests dispatched through a given engine instance, which violates the thread-safety guarantees established in the project constitution.

**Independent Test**: Can be tested by creating an engine with a custom configuration and issuing two sequential requests through it, asserting that each captured `URLRequest` carries the same custom configuration values.

**Acceptance Scenarios**:

1. **Given** an engine initialised with a custom timeout, **When** multiple sequential requests are dispatched through it, **Then** every captured `URLRequest` carries that exact custom timeout.
2. **Given** a configuration value is constructed once and used to initialise an engine, **When** multiple requests are dispatched through that engine, **Then** each carries the same settings; the configuration value is not mutated by any request call.
3. **Given** two `HTTPClient` instances each initialised with a different configuration, **When** concurrent requests are dispatched through each engine, **Then** each captured `URLRequest` carries only its own engine's configuration settings and no cross-engine contamination is present.

---

### User Story 4 - Configuration Does Not Override Engine-Managed Properties (Priority: P4)

A developer supplies a configuration value on a request call. The engine-managed properties of the `URLRequest` — the HTTP method, the URL, the request body, and the content-type and user-supplied headers — are always set by the engine and cannot be overridden by the configuration struct. The configuration struct is strictly scoped to the properties the engine does not otherwise control.

**Why this priority**: Clear ownership boundaries are essential to predictable behaviour. If the configuration struct could silently override the HTTP method or body, it would introduce subtle bugs and undermine the trust model of the library's public API.

**Independent Test**: Can be tested by constructing a configuration value (with any supported property set) and verifying that the HTTP method, URL, body, and headers on the captured `URLRequest` remain exactly as the engine assembled them — unchanged by the configuration.

**Acceptance Scenarios**:

1. **Given** a configuration value is supplied, **When** the `URLRequest` is assembled, **Then** the HTTP method, URL, HTTP body, and all headers set by the engine or by the caller's header parameter are unchanged.
2. **Given** any supported configuration property is set to a non-default value, **When** compared against the outgoing request's HTTP method and URL, **Then** neither is affected.

---

### Edge Cases

- What happens when a configuration property is set to a value outside the platform-valid range (e.g., a negative timeout)? → The engine passes the value through to the platform without validation; platform-defined behaviour applies.
- What happens when two configuration values are constructed with identical property values? → They are semantically equivalent and produce identical `URLRequest` output; the library does not require reference identity.
- What happens when a library-internal setting and a configuration property would target the same `URLRequest` field? → Library-internal settings always take precedence; the configuration struct is strictly scoped to the properties the engine does not otherwise set (see FR-007).
- What happens when the same configuration value is passed concurrently to multiple in-flight requests? → Each request applies its own copy of the settings independently; no mutable shared state exists between requests (see A-05, A-06).
- What happens when no configuration argument is supplied? → The built-in default configuration is applied automatically; the method signature carries the default value so no call site requires modification.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The library MUST define a dedicated configuration value type that carries `URLRequest` properties not otherwise set by the engine; HTTP method, URL, body, content-type (for body encoding), and caller-supplied headers are explicitly out of scope for this type.
- **FR-002**: The configuration type MUST carry, at minimum, the following properties: request timeout duration, cache policy, cellular network access permission, expensive network access permission, constrained network access permission, and cookie handling behaviour.
- **FR-003**: The configuration type MUST expose a built-in default value obtainable without supplying any constructor arguments; the default value's properties MUST be equivalent to the platform-standard `URLRequest` defaults for those same properties.
- **FR-004**: The `HTTPClient` initialiser MUST accept a `configuration` argument that defaults to the built-in default value when omitted; no existing call site that omits the `configuration` argument shall require any modification.
- **FR-005**: When a configuration argument is supplied, ALL properties carried by the configuration type MUST be applied to every `URLRequest` assembled by that engine; no configuration property may be silently ignored.
- **FR-006**: Configuration values MUST be immutable after construction; no engine operation or request method may mutate a caller-supplied configuration value.
- **FR-007**: Configuration application MUST NOT override properties set by the engine (HTTP method, URL, body, content-type for encoded bodies, caller-supplied headers); the engine's own property assignments MUST always take final precedence.
- **FR-008**: The prior closure-based `URLRequest` customisation mechanism introduced in Feature 001 (FR-011) is superseded by this feature; it MUST be removed or replaced by the configuration struct, with no closure-based parameter remaining on any public method or initialiser after this feature is complete.
- **FR-009**: The `HTTPClient` initialiser signature MUST remain syntactically compatible at all call sites that do not supply a `configuration` argument; the configuration parameter MUST be additive and opt-in.
- **FR-010**: The configuration type MUST be safe for concurrent use; the same configuration value MUST be passable to multiple simultaneous request calls without introducing a data race.

### Key Entities

- **`HTTPClient.Configuration`** *(new)*: A value type nested inside `HTTPClient` (declared via `public extension HTTPClient`) carrying `URLRequest`-level settings not managed by the engine. Properties: timeout duration, cache policy, cellular access flag, expensive-network access flag, constrained-network access flag, cookie-handling flag. Provides a built-in default instance whose property values match platform `URLRequest` defaults. Immutable after construction.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can make any HTTP request with no configuration argument and observe behaviour identical to platform-standard `URLRequest` defaults — confirmed by automated test with zero real network calls.
- **SC-002**: A developer can specify a custom timeout, cache policy, or network-access restriction for a specific engine without writing a closure or callback — the custom value is confirmed in the assembled `URLRequest` by an automated test for each supported property.
- **SC-003**: All existing automated tests from Feature 001 and Feature 002 pass with zero modifications after this feature is merged; the new configuration parameter is fully additive at all existing call sites.
- **SC-004**: Concurrent use of two engines with distinct configurations produces no cross-engine contamination in the assembled `URLRequest` instances — verified by a concurrent test with at least two simultaneous requests through separate engine instances.
- **SC-005**: The library builds with zero compiler warnings after the closure-based mechanism is removed and replaced, per the constitution Quality Gates.

---

## Assumptions

- **A-01**: This feature supersedes the closure-based `URLRequest` customisation mechanism from Feature 001 (FR-011). The closure offered open-ended mutation; the struct provides a defined, auditable property surface. Any `URLRequest` property not exposed on the configuration struct is intentionally out of scope for this feature; callers with exotic requirements may request additions in a future iteration.
- **A-02**: The minimum set of configurable properties is: request timeout duration, cache policy, cellular access permission, expensive network access permission, constrained network access permission, and cookie-handling behaviour. Network service type classification is excluded from the initial scope as its use cases are narrow; it may be added in a follow-up if needed.
- **A-03**: Configuration is applied at engine-initialisation level via a `configuration: HTTPClient.Configuration = .default` parameter on `HTTPClient.init`. The engine stores the value as an immutable `public let configuration: Configuration` property and applies it to every `URLRequest` it assembles. This provides uniform transport settings across all requests through a given engine instance; callers that need different transport settings for different requests should create separate engine instances.
- **A-04**: The default configuration value produces property values that match `URLRequest`'s platform-defined defaults (e.g., 60-second timeout, use-protocol cache policy, cellular access enabled, cookie handling enabled). If platform defaults change in future OS versions, the library's default configuration should be updated to match.
- **A-05**: The configuration type is a value type (struct), consistent with the Swift API Design Guidelines preference for value semantics for configuration data and with the constitution's requirement that all types crossing concurrency boundaries conform to `Sendable` (Principle V).
- **A-06**: Configuration values are applied to each request's `URLRequest` independently; the engine does not retain or share any per-request configuration state between calls.
- **A-07**: Library-managed properties (HTTP method, URL, HTTP body, content-type for encoded bodies, caller-supplied headers) are always applied after the configuration struct's properties, ensuring the engine's own assignments can never be overridden by the configuration. This ordering is consistent with the precedence hierarchy established in Features 001–002.
- **A-08**: Backward compatibility is fully maintained for all callers that do not supply a configuration argument; the default parameter value ensures no valid existing call site is broken by this change.
- **A-09**: The removal of the closure-based mechanism (FR-011) is a breaking change at the API level. This feature MUST be accompanied by a MAJOR version bump in `Package.swift`, consistent with the constitution's versioning policy for breaking public API changes.
