# Quickstart Validation Guide: Request Configuration Struct

**Feature**: `003-request-configuration` | **Date**: 2026-06-28 | **Phase 1**

This guide documents the runnable validation scenarios that prove Feature 003 works
end-to-end. Each scenario maps to one or more acceptance criteria in `spec.md`.
Use `swift test` from the repository root to execute all scenarios. No real network
connections are required — all scenarios use `MockURLProtocol`
(`Tests/HTTPClientLibTests/Helpers/MockURLProtocol.swift`).

For type definitions see `data-model.md`. For updated signatures and usage examples
see `contracts/public-api.md`.

---

## Prerequisites

```bash
# From repository root
swift build      # Must succeed with zero warnings (Constitution I, Quality Gate)
swift test       # Must pass with zero failures (Constitution II, Quality Gate)
```

The test target `HTTPClientLibTests` depends on `HTTPClientLib`. All tests run in-process with
`MockURLProtocol` intercepting every `URLRequest` before any network call is made.

---

## User Story 1 — Zero-Config Default Behaviour (P1)

**Goal**: Verify that creating an `HTTPClient` without a `configuration:` argument
and calling any HTTP method produces a `URLRequest` whose transport properties match
`URLRequest` platform defaults, and that all prior Feature 001/002 tests pass
unmodified.

### Scenario 1a — Default configuration properties match platform defaults

```swift
// Test file: HTTPClientConfigurationTests.swift
// Suite: HTTPClientConfigurationTests
// Test:  defaultConfigurationMatchesPlatformDefaults

let config = DefaultHTTPClient.Configuration.default
// Assert — all six properties match platform baseline
#expect(config.timeoutInterval == 60.0)
#expect(config.cachePolicy == .useProtocolCachePolicy)
#expect(config.allowsCellularAccess == true)
#expect(config.allowsExpensiveNetworkAccess == true)
#expect(config.allowsConstrainedNetworkAccess == true)
#expect(config.httpShouldHandleCookies == true)
```

**Expected**: All six `#expect` assertions pass.

### Scenario 1b — Default configuration applied when argument omitted

```swift
// Test file: HTTPClientConfigurationTests.swift
// Test: defaultConfigurationIsAppliedWhenNoArgumentSupplied

let (session, mock) = MockURLProtocol.makePair()
let engine = DefaultHTTPClient(session: session)   // ← no configuration: argument
mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())
_ = try await engine.get(url)
let captured = try #require(mock.capturedRequest)
#expect(captured.timeoutInterval == 60.0)
```

**Expected**: Captured `URLRequest.timeoutInterval` is `60.0` (platform default).

### Scenario 1c — Feature 001 and 002 regression suite passes

```bash
swift test --filter HTTPClientGetTests
swift test --filter HTTPClientPostTests
swift test --filter HTTPClientPutTests
swift test --filter HTTPClientDeleteTests
swift test --filter HTTPClientHeaderTests
swift test --filter HTTPClientDefaultHeaderTests
swift test --filter HTTPClientMultipartTests
swift test --filter HTTPClientCancellationTests
swift test --filter MultipartEncoderTests
```

**Expected**: All test suites report zero failures. This is SC-003.

> **Note**: Two tests are migrated (not removed) as part of this feature:
> - `HTTPClientGetTests.configuratorMutatesRequestBeforeDispatch` → renamed and
>   migrated to use `DefaultHTTPClient(session: session, configuration: DefaultHTTPClient.Configuration(timeoutInterval: 42))`.
> - `HTTPClientPostTests.configuratorIsInvokedForPostRequests` → renamed and
>   migrated to use `headers: ["X-Injected": "injected-value"]`.
> All other tests require zero modifications.

---

## User Story 2 — Custom Engine-Level Configuration (P2)

**Goal**: Verify that each supported `DefaultHTTPClient.Configuration` property is applied
to the assembled `URLRequest` when an engine is initialised with a non-default
configuration.

### Scenario 2a — Custom timeout

```swift
// Test: customTimeoutAppliedToRequest
let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 120.0))
_ = try await engine.get(url)
#expect(mock.capturedRequest?.timeoutInterval == 120.0)
```

**Expected**: `timeoutInterval` is `120.0`.

### Scenario 2b — Non-default cache policy

```swift
// Test: customCachePolicyAppliedToRequest
let (engine, mock) = makeEngine(configuration: .init(cachePolicy: .reloadIgnoringLocalCacheData))
_ = try await engine.post(url)
#expect(mock.capturedRequest?.cachePolicy == .reloadIgnoringLocalCacheData)
```

**Expected**: `cachePolicy` is `.reloadIgnoringLocalCacheData`.

### Scenario 2c — Cellular access disabled

```swift
// Test: cellularAccessDisabledAppliedToRequest
let (engine, mock) = makeEngine(configuration: .init(allowsCellularAccess: false))
_ = try await engine.get(url)
#expect(mock.capturedRequest?.allowsCellularAccess == false)
```

**Expected**: `allowsCellularAccess` is `false`.

### Scenario 2d — Expensive network access disabled

```swift
// Test: expensiveNetworkAccessDisabledAppliedToRequest
let (engine, mock) = makeEngine(configuration: .init(allowsExpensiveNetworkAccess: false))
_ = try await engine.get(url)
#expect(mock.capturedRequest?.allowsExpensiveNetworkAccess == false)
```

**Expected**: `allowsExpensiveNetworkAccess` is `false`.

### Scenario 2e — Constrained network access disabled

```swift
// Test: constrainedNetworkAccessDisabledAppliedToRequest
let (engine, mock) = makeEngine(configuration: .init(allowsConstrainedNetworkAccess: false))
_ = try await engine.get(url)
#expect(mock.capturedRequest?.allowsConstrainedNetworkAccess == false)
```

**Expected**: `allowsConstrainedNetworkAccess` is `false`.

### Scenario 2f — Cookie handling disabled

```swift
// Test: cookieHandlingDisabledAppliedToRequest
let (engine, mock) = makeEngine(configuration: .init(httpShouldHandleCookies: false))
_ = try await engine.get(url)
#expect(mock.capturedRequest?.httpShouldHandleCookies == false)
```

**Expected**: `httpShouldHandleCookies` is `false`.

### Scenario 2g — Multiple non-default properties simultaneously

```swift
// Test: multiplePropertiesAllAppliedSimultaneously
let config = DefaultHTTPClient.Configuration(
    timeoutInterval: 10.0,
    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
    allowsCellularAccess: false
)
let (engine, mock) = makeEngine(configuration: config)
_ = try await engine.get(url)
let captured = try #require(mock.capturedRequest)
#expect(captured.timeoutInterval == 10.0)
#expect(captured.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
#expect(captured.allowsCellularAccess == false)
```

**Expected**: All three non-default properties appear in the captured request.

### Scenario 2h — Custom configuration on all HTTP methods

Run the equivalent of Scenario 2a against GET, POST (body), POST (multipart), PUT,
and DELETE:

```bash
swift test --filter HTTPClientConfigurationTests/configurationApplied
```

**Expected**: All five method-specific tests pass, confirming that
`DefaultHTTPClient.Configuration` is applied uniformly across all HTTP methods (FR-004, FR-005).

---

## User Story 3 — Configuration Is Consistent Across All Requests on an Engine (P3)

**Goal**: Verify that every request dispatched through an engine consistently carries
that engine's configuration and that different engines with distinct configurations
do not contaminate each other.

### Scenario 3a — Sequential requests on same engine carry same configuration

```swift
// Test: configurationIsolatedAcrossSequentialRequests
let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 999.0))
_ = try await engine.get(url)
let timeoutA = mock.capturedRequest?.timeoutInterval   // 999.0

_ = try await engine.get(url)
let timeoutB = mock.capturedRequest?.timeoutInterval   // 999.0 — same engine

#expect(timeoutA == 999.0)
#expect(timeoutB == 999.0)
```

**Expected**: Both requests carry `timeoutInterval` 999.0 (the engine's configuration).

### Scenario 3b — Reused configuration value is not mutated

```swift
// Test: configurationValueNotMutatedByRequestCall
let sharedConfig = DefaultHTTPClient.Configuration(timeoutInterval: 30.0)
let (engine, mock) = makeEngine(configuration: sharedConfig)
_ = try await engine.get(url)
_ = try await engine.post(url)
// sharedConfig is still 30.0 — value type cannot be mutated externally
#expect(sharedConfig.timeoutInterval == 30.0)
```

**Expected**: `sharedConfig.timeoutInterval` remains `30.0` after both calls
(FR-006; value type semantics guarantee this at compile time).

### Scenario 3c — Concurrent requests through distinct engines carry independent configurations

```swift
// Test: concurrentRequestsCarryOwnConfiguration
// Two independent mock pairs — each engine has its own session and config
let (sessionA, mockA) = MockURLProtocol.makePair()
let engineA = DefaultHTTPClient(session: sessionA, configuration: .init(timeoutInterval: 10.0))
mockA.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

let (sessionB, mockB) = MockURLProtocol.makePair()
let engineB = DefaultHTTPClient(session: sessionB)   // default config
mockB.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

async let responseA = engineA.get(url)
async let responseB = engineB.get(url)
_ = try await (responseA, responseB)
#expect(mockA.capturedRequest?.timeoutInterval == 10.0)
#expect(mockB.capturedRequest?.timeoutInterval == 60.0)
```

**Expected**: Each captured request carries only its own engine's configuration. No
cross-contamination between the concurrent calls (SC-004).

---

## User Story 4 — Configuration Does Not Override Engine-Managed Properties (P4)

**Goal**: Verify that `DefaultHTTPClient.Configuration` has no effect on the HTTP method,
URL, HTTP body, or caller-supplied headers.

### Scenario 4a — HTTP method is unaffected by configuration

```swift
// Test: configurationDoesNotOverrideHTTPMethod
let config = DefaultHTTPClient.Configuration(timeoutInterval: 999.0, allowsCellularAccess: false)
let (engine, mock) = makeEngine(configuration: config)
_ = try await engine.get(url)
#expect(mock.capturedRequest?.httpMethod == "GET")

_ = try await engine.post(url)
#expect(mock.capturedRequest?.httpMethod == "POST")
```

**Expected**: HTTP method is exactly what the engine sets, unaffected by any
configuration property.

### Scenario 4b — URL is unaffected by configuration

```swift
// Test: configurationDoesNotOverrideURL
let (engine, mock) = makeEngine(configuration: .init(cachePolicy: .reloadIgnoringLocalCacheData))
_ = try await engine.get(url)
#expect(mock.capturedRequest?.url == url)
```

**Expected**: Captured URL equals the URL passed to the method.

### Scenario 4c — Body and Content-Type are unaffected by configuration

```swift
// Test: configurationDoesNotOverrideHTTPBody
let (engine, mock) = makeEngine(configuration: .init(timeoutInterval: 5.0))
_ = try await engine.post(url, body: .json(["key": "value"]))
let captured = try #require(mock.capturedRequest)
#expect(captured.value(forHTTPHeaderField: "Content-Type") == "application/json")
let decoded = try JSONDecoder().decode([String: String].self, from: captured.httpBody!)
#expect(decoded == ["key": "value"])
```

**Expected**: Body and `Content-Type` are exactly what the engine assembled; the
`timeoutInterval: 5.0` configuration setting does not interfere with them.

### Scenario 4d — Caller-supplied headers are unaffected by configuration

```swift
// Test: configurationDoesNotOverrideCallerHeaders
let (engine, mock) = makeEngine(configuration: .init(allowsCellularAccess: false))
_ = try await engine.get(url, headers: ["X-Caller": "value"])
#expect(mock.capturedRequest?.value(forHTTPHeaderField: "X-Caller") == "value")
```

**Expected**: The `X-Caller` header set by the caller is present and unchanged.

---

## Build Validation (Quality Gates)

```bash
# Quality Gate 1 — zero-warning build
swift build 2>&1 | grep -E "warning:|error:"
# Expected: no output (zero warnings, zero errors)

# Quality Gate 2 — all tests pass
swift test
# Expected: Test Suite 'All tests' passed; 0 failures

# Quality Gate 3 — no force-unwraps introduced in Sources/
grep -r "!\." Sources/ --include="*.swift" | grep -v "// "
# Expected: no new occurrences in Sources/HTTPClientLib/Implementation/DefaultHTTPClient+Configuration.swift
#           or in modified sections of HTTPClient.swift / RequestBuilder.swift
```

---

## Scope Boundaries

The following are **not** validated in this guide (they belong in `tasks.md` and
the implementation phase):

- Specific test file implementations (test bodies are sketched above for reference,
  not as final code)
- Migration steps for `configuratorMutatesRequestBeforeDispatch` and
  `configuratorIsInvokedForPostRequests` (documented in `data-model.md` Migrated
  Tests section)
- Internal `RequestBuilder` implementation details beyond assembly order
- git tag `1.0.0` creation (documented in `contracts/public-api.md`)
