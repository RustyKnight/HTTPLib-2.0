# Tasks: HTTPClient Library

**Feature**: `001-http-engine-library`

**Input**: `specs/001-http-engine-library/` — spec.md, plan.md, research.md, data-model.md,
contracts/public-api.md, quickstart.md

**TDD**: Per Constitution II and plan.md Complexity Tracking, **Swift Testing** (`import Testing`,
`@Test`, `@Suite`) replaces XCTest (justified deviation). Tests MUST be written and confirmed
**RED** before implementation code is written in every phase.

---

## Format: `[ID] [P?] [Story?] Description with file path`

- **[P]** — Parallelizable: operates on a separate file from other [P] tasks in the same group;
  no dependency on any incomplete task in the same phase
- **[US1–US5]** — Maps to spec.md user story priorities P1–P5
- All file paths are **relative to the repository root**

## Path Conventions

```
Sources/HTTPLib/            # Public API types — one type per file
Sources/HTTPLib/Internal/   # Internal helpers — not part of the public API
Tests/HTTPLibTests/         # One test suite file per concern area
Tests/HTTPLibTests/Helpers/ # Shared test infrastructure
```

---

## Phase 1: Setup

**Purpose**: Remove the SPM-generated placeholder struct and clear the test scaffold so the real
implementation files have a clean slate. plan.md §Structure Decision states the `HTTPLib` struct
"should be removed when `HTTPClient` is introduced".

- [X] T001 Replace the entire content of `Sources/HTTPLib/HTTPLib.swift` with the single comment line `// Superseded by HTTPClient — see Sources/HTTPLib/HTTPClient.swift` (removes the `public struct HTTPLib` and `static let version` property introduced by the SPM scaffold)
- [X] T002 Replace the entire content of `Tests/HTTPLibTests/HTTPLibTests.swift` with an empty Swift Testing suite: `import Testing`, `@testable import HTTPClientLib`, blank line, `@Suite("HTTPLib") struct HTTPLibTests {}` — removes the `versionIsDefined` test that references the now-deleted `HTTPLib.version`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Four shared types and the test-isolation infrastructure that every user story depends
on. Nothing in Phases 3–8 can compile until this phase is complete.

**⚠️ CRITICAL**: No user story work begins until all four tasks below are done.

- [X] T003 [P] Create `Tests/HTTPLibTests/Helpers/MockURLProtocol.swift` — `import Foundation`, `import Testing`, `@testable import HTTPClientLib`; define `final class MockURLProtocol: URLProtocol` with: (1) `nonisolated(unsafe) static var stub: (response: HTTPURLResponse, data: Data)? = nil` — the canned response to deliver; (2) `nonisolated(unsafe) static var capturedRequest: URLRequest? = nil` — stores the most recent intercepted `URLRequest` for assertion in tests; (3) `override class func canInit(with request: URLRequest) -> Bool { return true }`; (4) `override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }`; (5) `override func startLoading()` — sets `MockURLProtocol.capturedRequest = self.request`, then if `stub` is non-nil delivers `client?.urlProtocol(self, didReceive: stub!.response, cacheStoragePolicy: .notAllowed)`, `client?.urlProtocol(self, didLoad: stub!.data)`, `client?.urlProtocolDidFinishLoading(self)` (if stub is nil, calls `client?.urlProtocol(self, didFailWithError: URLError(.unknown))`); (6) `override func stopLoading() {}`; (7) `static func makeSession() -> URLSession` — returns `URLSession(configuration: { var c = URLSessionConfiguration.ephemeral; c.protocolClasses = [MockURLProtocol.self]; return c }())`; (8) `static func makeResponse(url: URL, statusCode: Int) -> HTTPURLResponse` — returns `HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!` (force-unwrap is acceptable in test helpers only, never in `Sources/`); (9) `static func reset()` — sets `stub = nil`, `capturedRequest = nil`; call `MockURLProtocol.reset()` in `setUp`-equivalent teardown inside each test suite

- [X] T004 [P] Create `Sources/HTTPLib/HTTPClientError.swift` — `import Foundation`; `// FR-006: All failure paths surface as typed throws`; `public enum HTTPClientError: Error` with five cases: `case jsonEncodingFailed(any Error)` (thrown when `JSONEncoder.encode` fails for a `.json` body), `case fileReadFailed(url: URL, underlying: any Error)` (thrown when a `.file` form item URL is unreadable), `case emptyFormItems` (thrown when multipart POST receives empty `formItems` array, FR-020), `case emptyFormItemName` (thrown when any `FormItem.name` is empty string, FR-021), `case networkError(any Error)` (wraps URLSession-level errors); add `extension HTTPClientError: @unchecked Sendable {}` — `any Error` payloads are consumed once and not shared across concurrency boundaries (research.md Decision 3 pattern); **note**: `CancellationError` is deliberately absent — it propagates directly per FR-007 and research Decision 8

- [X] T005 [P] Create `Sources/HTTPLib/HTTPResponse.swift` — `import Foundation`; `// FR-004, FR-008: status code + optional body; non-2xx never thrown`; `public struct HTTPResponse: Sendable` with `public let statusCode: Int` and `public let body: Data?`; add one internal initialiser `init(statusCode: Int, body: Data?)` — no `public` modifier (only `HTTPClient` constructs `HTTPResponse` values inside the module, never a caller)

- [X] T006 [P] Create `Sources/HTTPLib/RequestBody.swift` — `import Foundation`; `// FR-012, FR-013: body variants for POST, PUT, DELETE`; `public enum RequestBody: @unchecked Sendable` — `@unchecked Sendable` required because `any Encodable` is not statically `Sendable` in Swift 6; JSON encoding occurs synchronously in `RequestBuilder` before the async boundary, so no data-race is possible in practice (research.md Decision 3); three cases: `case text(String)` (encoded as UTF-8, sets `Content-Type: text/plain; charset=utf-8`), `case binary(Data)` (raw bytes transmitted verbatim, library sets **no** `Content-Type`), `case json(any Encodable)` (serialised by `JSONEncoder`, sets `Content-Type: application/json`, throws `HTTPClientError.jsonEncodingFailed` on encode failure)

**Checkpoint**: Foundation is ready — `MockURLProtocol`, `HTTPClientError`, `HTTPResponse`, and
`RequestBody` all exist. Phases 3–8 may now proceed.

---

## Phase 3: User Story 1 — Basic HTTP Requests (Priority: P1) 🎯 MVP

**Goal**: GET, POST (no body), PUT (no body), DELETE (no body) each accept a URL-only call site,
return `HTTPResponse` carrying the server's status code, wrap URLSession errors in
`HTTPClientError.networkError`, return non-2xx status codes **without** throwing, call
`Task.checkCancellation()` at entry, and propagate `CancellationError` directly.

**Independent Test**:
```bash
swift test --filter HTTPClientGetTests
swift test --filter HTTPClientPostTests
swift test --filter HTTPClientPutTests
swift test --filter HTTPClientDeleteTests
```

### Tests for User Story 1 — Write FIRST, confirm RED before T011 ⚠️

- [X] T007 [P] [US1] Create `Tests/HTTPLibTests/HTTPClientGetTests.swift` — `@Suite("HTTPClient GET") struct HTTPClientGetTests`; add `private let url = URL(string: "https://example.com")!` and `private func makeEngine() -> HTTPClient { HTTPClient(session: MockURLProtocol.makeSession()) }`; implement four `@Test` async throws methods: (1) `getReturnsStatusCode()` — `MockURLProtocol.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())`; `let r = try await makeEngine().get(url)`; `#expect(r.statusCode == 200)`; (2) `getNonTwoXXStatusIsReturnedNotThrown()` — stub 404; assert `r.statusCode == 404` with no error thrown (FR-008); (3) `getReturnsBodyData()` — stub 200 + `Data("hello".utf8)`; assert `r.body == Data("hello".utf8)`; (4) `getReturnsNilBodyForEmptyResponse()` — stub 200 + `Data()`; assert `r.body == nil`; call `MockURLProtocol.reset()` at start of each test or use `init()` teardown

- [X] T008 [P] [US1] Create `Tests/HTTPLibTests/HTTPClientPostTests.swift` — `@Suite("HTTPClient POST") struct HTTPClientPostTests`; same `url` and `makeEngine()` helpers; two `@Test` async throws methods for US1 scope: (1) `postNoBodyReturnsStatusCode()` — stub 201; `let r = try await makeEngine().post(url)`; `#expect(r.statusCode == 201)`; (2) `postNoBodySetsHTTPMethodToPOST()` — stub 200; call `makeEngine().post(url)`; `#expect(MockURLProtocol.capturedRequest?.httpMethod == "POST")`; body-variant tests (US2) and session/configurator tests (US4) are appended to this file in later phases

- [X] T009 [P] [US1] Create `Tests/HTTPLibTests/HTTPClientPutTests.swift` — `@Suite("HTTPClient PUT") struct HTTPClientPutTests`; same helpers; two `@Test` async throws methods for US1 scope: (1) `putNoBodyReturnsStatusCode()` — stub 200; assert `r.statusCode == 200`; (2) `putNoBodySetsHTTPMethodToPUT()` — stub 200; assert `capturedRequest?.httpMethod == "PUT"`; body-variant tests (US2) are appended in Phase 4

- [X] T010 [P] [US1] Create `Tests/HTTPLibTests/HTTPClientDeleteTests.swift` — `@Suite("HTTPClient DELETE") struct HTTPClientDeleteTests`; same helpers; two `@Test` async throws methods for US1 scope: (1) `deleteNoBodyReturnsStatusCode()` — stub 200; assert `r.statusCode == 200`; (2) `deleteNoBodySetsHTTPMethodToDELETE()` — stub 200; assert `capturedRequest?.httpMethod == "DELETE"`; body tests (US2) are appended in Phase 4

### Implementation for User Story 1

- [X] T011 [US1] Create `Sources/HTTPLib/Internal/RequestBuilder.swift` — `import Foundation`; `// FR-009, FR-011: request assembly — headers, body, configurator`; `internal enum RequestBuilder` (caseless namespace for static functions); one static method: `static func buildRequest(url: URL, method: String, headers: [String: String]?, body: RequestBody?, configurator: RequestConfigurator?) throws -> URLRequest`; implementation steps in order: (1) `var request = URLRequest(url: url)`; `request.httpMethod = method`; (2) `// Step 1 — caller headers applied first (research Decision 6)`: iterate `headers ?? [:]` calling `request.setValue(value, forHTTPHeaderField: key)`; (3) `// Step 2 — library body encoding + Content-Type (overwrites conflicting caller header — FR-009/US3-AC-03)`: leave as `// TODO T016 (US2): switch on body to encode httpBody and set Content-Type` placeholder for now; (4) `// Step 3 — configurator runs last (FR-011)`: `configurator?(&request)`; return `request`

- [X] T012 [US1] Create `Sources/HTTPLib/HTTPClient.swift` — `import Foundation`; `public typealias RequestConfigurator = @Sendable (inout URLRequest) -> Void  // FR-011`; `// FR-001, FR-002, FR-005, FR-010: primary entry point; async operations; injectable session`; `public struct HTTPClient: Sendable` with `public let session: URLSession` and `public let configurator: RequestConfigurator?`; `public init(session: URLSession = .shared, configurator: RequestConfigurator? = nil)`; add a `private func dispatch(url: URL, method: String, headers: [String: String]?, body: RequestBody? = nil) async throws -> HTTPResponse` shared helper: (a) `try Task.checkCancellation()  // FR-007, research Decision 8`; (b) `let request = try RequestBuilder.buildRequest(url: url, method: method, headers: headers, body: body, configurator: self.configurator)  // FR-010: self.session, FR-011: self.configurator`; (c) `let (data, urlResponse): (Data, URLResponse)` from: `do { (data, urlResponse) = try await session.data(for: request)  // FR-010: routes through injected session } catch is CancellationError { throw  // FR-007: CancellationError escapes unwrapped } catch { throw HTTPClientError.networkError(error)  // FR-006 }`; (d) `guard let httpResponse = urlResponse as? HTTPURLResponse else { throw HTTPClientError.networkError(URLError(.badServerResponse)) }`; (e) `return HTTPResponse(statusCode: httpResponse.statusCode, body: data.isEmpty ? nil : data)  // FR-008: non-2xx returned, not thrown`; expose four public methods (all delegate to `dispatch`): `public func get(_ url: URL, headers: [String: String]? = nil) async throws -> HTTPResponse { try await dispatch(url: url, method: "GET", headers: headers) }`; same pattern for `post(_:headers:)` ("POST"), `put(_:headers:)` ("PUT"), `delete(_:headers:)` ("DELETE"); body overloads added in T017; multipart overload added in T027

**Checkpoint**: `swift test --filter HTTPClientGetTests` (and Post, Put, Delete) all GREEN.
MVP is functional — a developer can call any of the four methods with a URL only.

---

## Phase 4: User Story 2 — Request Body Variants (Priority: P2)

**Goal**: POST and PUT accept `.text`, `.binary`, and `.json` bodies with correct payloads and
`Content-Type` headers. DELETE accepts an optional body via the same variants. A `.json` body
whose `Encodable` value fails encoding throws `HTTPClientError.jsonEncodingFailed` before any
network activity begins (spec US2-AC-04, FR-006).

**Independent Test**:
```bash
swift test --filter HTTPClientPostTests
swift test --filter HTTPClientPutTests
swift test --filter HTTPClientDeleteTests
```

### Tests for User Story 2 — Write FIRST, confirm RED before T016 ⚠️

- [X] T013 [P] [US2] Extend `Tests/HTTPLibTests/HTTPClientPostTests.swift` — append five `@Test` async throws methods inside `HTTPClientPostTests`: (1) `postTextBodySetsHTTPBodyAndContentType()` — stub 200; call `makeEngine().post(url, body: .text("hello"))`; `#expect(MockURLProtocol.capturedRequest?.httpBody == Data("hello".utf8))`; `#expect(MockURLProtocol.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "text/plain; charset=utf-8")`; (2) `postBinaryBodySetsHTTPBodyWithNoContentType()` — `.binary(Data([0x01, 0x02]))`; assert `httpBody == Data([0x01, 0x02])`; assert `value(forHTTPHeaderField: "Content-Type") == nil` (library must NOT set Content-Type for binary, data-model.md §RequestBody); (3) `postJSONBodyEncodesEncodableAndSetsContentType()` — define `struct Payload: Encodable { let key: String }`; call `.json(Payload(key: "val"))`; assert `httpBody` is valid JSON with `#expect((try? JSONDecoder().decode([String: String].self, from: capturedRequest!.httpBody!)) == ["key": "val"])`; assert `Content-Type == "application/json"`; (4) `postJSONBodyThrowsJsonEncodingFailedBeforeNetworkActivity()` — define `struct FailEncoder: Encodable { func encode(to e: any Encoder) throws { throw URLError(.unknown) } }`; call `makeEngine().post(url, body: .json(FailEncoder()))`; assert it throws `HTTPClientError.jsonEncodingFailed`; assert `MockURLProtocol.capturedRequest == nil` (no request reached the session); (5) `postWithBodySetsHTTPMethodToPOST()` — `.text("x")`; assert `capturedRequest?.httpMethod == "POST"`

- [X] T014 [P] [US2] Extend `Tests/HTTPLibTests/HTTPClientPutTests.swift` — append three `@Test` async throws methods: (1) `putTextBodySetsHTTPBodyAndContentType()` — `.text("data")`; assert `httpBody == Data("data".utf8)` and `Content-Type == "text/plain; charset=utf-8"`; (2) `putBinaryBodySetsHTTPBodyWithNoContentType()` — `.binary(Data([0xFF]))`; assert `httpBody == Data([0xFF])` and `Content-Type == nil`; (3) `putJSONBodyEncodesEncodableAndSetsContentType()` — `.json(["a": 1])`; assert httpBody is valid JSON and `Content-Type == "application/json"`

- [X] T015 [P] [US2] Extend `Tests/HTTPLibTests/HTTPClientDeleteTests.swift` — append two `@Test` async throws methods: (1) `deleteWithTextBodyIncludesBodyAndContentType()` — stub 200; call `makeEngine().delete(url, body: .text("payload"))`; assert `httpBody == Data("payload".utf8)` and `Content-Type == "text/plain; charset=utf-8"`; (2) `deleteWithNilBodySendsNoBody()` — `makeEngine().delete(url)` (no-body overload from US1); assert `capturedRequest?.httpBody == nil`

### Implementation for User Story 2

- [X] T016 [US2] Update `Sources/HTTPLib/Internal/RequestBuilder.swift` — replace the `// TODO T016 (US2)` comment in `buildRequest` with body encoding logic: add `if let body` switch immediately after the caller-headers loop and before the configurator call: `case .text(let s): request.httpBody = Data(s.utf8); request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")  // FR-012`; `case .binary(let d): request.httpBody = d  // no Content-Type set, per data-model.md §RequestBody`; `case .json(let v): do { request.httpBody = try JSONEncoder().encode(v) } catch { throw HTTPClientError.jsonEncodingFailed(error) }; request.setValue("application/json", forHTTPHeaderField: "Content-Type")  // FR-012`; each `setValue` for Content-Type is applied **after** the caller-headers loop so it overwrites any conflicting caller-supplied `Content-Type` (research Decision 6, US3-AC-03); the configurator call remains the final step

- [X] T017 [US2] Add body overloads to `Sources/HTTPLib/HTTPClient.swift` — update the `dispatch` helper to accept `body: RequestBody? = nil` (if not already using `nil` default); add three new public methods: `public func post(_ url: URL, body: RequestBody, headers: [String: String]? = nil) async throws -> HTTPResponse { try await dispatch(url: url, method: "POST", headers: headers, body: body) }`; same pattern for `public func put(_ url: URL, body: RequestBody, headers: [String: String]? = nil) async throws -> HTTPResponse` and `public func delete(_ url: URL, body: RequestBody, headers: [String: String]? = nil) async throws -> HTTPResponse`; each new overload inherits `Task.checkCancellation()`, `CancellationError` pass-through, and `networkError` wrapping from `dispatch` — no duplication needed

**Checkpoint**: `swift test --filter HTTPClientPostTests` and `HTTPClientPutTests` GREEN with all
body-variant assertions passing, including the pre-network encoding-failure assertion.

---

## Phase 5: User Story 3 — Per-Request Custom Headers (Priority: P3)

**Goal**: Any headers dictionary supplied to any method appears verbatim in the outbound
`URLRequest`. When a caller-supplied header key conflicts with a library-required header (e.g.,
caller sets `Content-Type: text/xml` on a `.json` body request), the library value wins (FR-009,
US3-AC-03, research Decision 6). Omitting headers adds no unexpected headers beyond
library-managed ones.

**Independent Test**:
```bash
swift test --filter HTTPClientHeaderTests
```

### Tests for User Story 3 — Write FIRST, confirm RED before T019 ⚠️

- [X] T018 [US3] Create `Tests/HTTPLibTests/HTTPClientHeaderTests.swift` — `@Suite("HTTPClient Headers") struct HTTPClientHeaderTests`; same `url` and `makeEngine()` helpers; three `@Test` async throws methods covering all three acceptance scenarios from spec.md US3: (1) `customHeadersAreForwardedInOutboundRequest()` — call `makeEngine().get(url, headers: ["Authorization": "Bearer token", "X-Custom": "value"])`; assert `MockURLProtocol.capturedRequest!.value(forHTTPHeaderField: "Authorization") == "Bearer token"` and `value(forHTTPHeaderField: "X-Custom") == "value"` (US3-AC-01); (2) `nilHeadersProducesNoUnexpectedHeaders()` — call `makeEngine().get(url, headers: nil)`; assert `capturedRequest?.allHTTPHeaderFields` does not contain keys other than those the OS adds automatically (no custom keys: no "Authorization", no "X-Custom") (US3-AC-02); (3) `libraryContentTypeOverridesConflictingCallerHeader()` — call `makeEngine().post(url, body: .json(["k": "v"]), headers: ["Content-Type": "text/xml"])`; assert `capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json"` (library wins, US3-AC-03, research Decision 6)

### Verification for User Story 3

- [X] T019 [US3] Verify `Sources/HTTPLib/Internal/RequestBuilder.swift` enforces the header priority from research Decision 6 — confirm that (a) caller headers loop runs BEFORE the body-encoding `if let body` switch, and (b) the body-encoding switch's `setValue` calls use `forHTTPHeaderField:` to overwrite any conflicting caller value; if the tests from T018 pass with no code change, mark this task done with a comment; if any test fails, fix the ordering so the sequence is: **1. caller headers → 2. library Content-Type → 3. configurator**

**Checkpoint**: `swift test --filter HTTPClientHeaderTests` GREEN. All three US3 acceptance
scenarios validated.

---

## Phase 6: User Story 4 — URLSession and URLRequest Customisation (Priority: P4)

**Goal**: `HTTPClient(session: customSession)` routes all network calls through `customSession`
(not `URLSession.shared`). `HTTPClient()` uses a sensible default. A `RequestConfigurator`
callback receives the fully assembled request immediately before dispatch and its mutations are
reflected in the outbound request (FR-010, FR-011).

**Independent Test**:
```bash
swift test --filter HTTPClientGetTests
swift test --filter HTTPClientPostTests
```

### Tests for User Story 4 — Write FIRST, confirm RED before T022 ⚠️

- [X] T020 [P] [US4] Extend `Tests/HTTPLibTests/HTTPClientGetTests.swift` — append two `@Test` async throws methods: (1) `customSessionIsUsedForAllRequests()` — create a dedicated `URLSession` via `MockURLProtocol.makeSession()`; construct `HTTPClient(session: dedicatedSession)`; set stub; call `engine.get(url)`; assert `MockURLProtocol.capturedRequest != nil` (proves the custom session intercepted the request, not a default session) (US4-AC-01); (2) `configuratorMutatesRequestBeforeDispatch()` — construct `HTTPClient(session: MockURLProtocol.makeSession(), configurator: { $0.timeoutInterval = 42 })`; stub 200; call `engine.get(url)`; assert `MockURLProtocol.capturedRequest?.timeoutInterval == 42` (US4-AC-03)

- [X] T021 [P] [US4] Extend `Tests/HTTPLibTests/HTTPClientPostTests.swift` — append one `@Test` async throws method: `configuratorIsInvokedForPostRequests()` — construct `HTTPClient(session: MockURLProtocol.makeSession(), configurator: { $0.addValue("injected-value", forHTTPHeaderField: "X-Injected") })`; stub 200; call `engine.post(url)`; assert `capturedRequest?.value(forHTTPHeaderField: "X-Injected") == "injected-value"` (US4-AC-03)

### Verification for User Story 4

- [X] T022 [US4] Audit `Sources/HTTPLib/HTTPClient.swift` — confirm every execution path (the shared `dispatch` helper covering all method variants) calls `session.data(for: request)` as `self.session.data(for:)` (never `URLSession.shared.data(for:)`) and passes `configurator: self.configurator` to `RequestBuilder.buildRequest`; add inline comments `// FR-010: routes through injected session` and `// FR-011: configurator applied in RequestBuilder` at the relevant sites if not already present; fix any method body that bypasses `self.session` or omits `self.configurator`

**Checkpoint**: `swift test --filter HTTPClientGetTests` (including US4 additions) and
`swift test --filter HTTPClientPostTests` both GREEN.

---

## Phase 7: User Story 5 — Multipart Form-Data POST (Priority: P5)

**Goal**: `engine.post(url, formItems: [...])` encodes items as RFC 2046 multipart/form-data
with a UUID-derived boundary per request (A-09); supports `.file`, `.data`, and `.property`
variants; sets `Content-Type: multipart/form-data; boundary=<boundary>` (FR-018); throws
`HTTPClientError.emptyFormItems` for an empty list (FR-020) and
`HTTPClientError.emptyFormItemName` for any item with an empty `name` (FR-021), both before any
encoding or network activity begins.

**Independent Test**:
```bash
swift test --filter MultipartEncoderTests
swift test --filter HTTPClientMultipartTests
```

### Tests for User Story 5 — Write FIRST, confirm RED before T025 ⚠️

- [X] T023 [P] [US5] Create `Tests/HTTPLibTests/MultipartEncoderTests.swift` — `@Suite("MultipartEncoder") struct MultipartEncoderTests`; tests call `MultipartEncoder.encode` directly (no URLSession); seven `@Test` throws methods: (1) `encodedBodyOpensWith_boundary_marker()` — encode `[FormItem.property(name: "k", value: "v")]`; convert `body` to a UTF-8 String; assert string starts with `"----Boundary-"`; (2) `encodedBodyClosesWith_final_boundary_and_CRLF()` — same; assert string ends with `"--\r\n"` (RFC 2046 final boundary); (3) `propertyPartContainsDispositionAndValue()` — encode `.property(name: "field", value: "hello")`; assert the body String contains `Content-Disposition: form-data; name="field"` and `hello`; (4) `dataPartBodyMatchesInputBytes()` — encode `.data(name: "blob", body: Data([0xDE, 0xAD, 0xBE, 0xEF]))`; assert the encoded `body` Data contains the subsequence `[0xDE, 0xAD, 0xBE, 0xEF]`; (5) `filePartBodyMatchesFileContentOnDisk()` — write `Data("file-content".utf8)` to a temp file at `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)`; encode `.file(name: "upload", url: tempURL)`; assert body Data contains `Data("file-content".utf8)`; remove the temp file in a `defer` block; (6) `explicitMimeTypeIsUsedInsteadOfDefault()` — encode `.property(name: "p", value: "v", mimeType: "text/csv")`; assert body String contains `Content-Type: text/csv` (FR-019); (7) `emptyItemNameThrows()` — assert `#expect(throws: HTTPClientError.emptyFormItemName) { try MultipartEncoder.encode([FormItem.property(name: "", value: "x")]) }`; import `Testing`, `Foundation`, `@testable import HTTPClientLib`

- [X] T024 [P] [US5] Create `Tests/HTTPLibTests/HTTPClientMultipartTests.swift` — `@Suite("HTTPClient Multipart POST") struct HTTPClientMultipartTests`; same `url` and `makeEngine()` helpers; three `@Test` async throws methods: (1) `emptyFormItemsThrowsBeforeNetworkActivity()` — `#expect(throws: HTTPClientError.emptyFormItems) { try await makeEngine().post(url, formItems: []) }`; additionally assert `MockURLProtocol.capturedRequest == nil` (nothing reached the session) (FR-020); (2) `emptyItemNameThrowsBeforeNetworkActivity()` — `#expect(throws: HTTPClientError.emptyFormItemName) { try await makeEngine().post(url, formItems: [FormItem.property(name: "", value: "x")]) }`; assert `capturedRequest == nil` (FR-021); (3) `validMultipartRequestSetsMultipartContentTypeHeader()` — stub 200; call `makeEngine().post(url, formItems: [FormItem.property(name: "key", value: "value")])`; assert `capturedRequest?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=----Boundary-") == true` (FR-018)

### Implementation for User Story 5

- [X] T025 [P] [US5] Create `Sources/HTTPLib/FormItem.swift` — `import Foundation`; `// FR-016, FR-017, FR-019`; `public enum FormItem: Sendable` with three cases: `case file(name: String, url: URL, fileName: String?, mimeType: String?)`, `case data(name: String, body: Data, fileName: String?, mimeType: String?)`, `case property(name: String, value: String, mimeType: String?)`; add `extension FormItem` with three `public static func` factory methods supplying `nil` defaults for all optional fields: `public static func file(name: String, url: URL, fileName: String? = nil, mimeType: String? = nil) -> FormItem { .file(name: name, url: url, fileName: fileName, mimeType: mimeType) }`, same pattern for `data` and `property`; add `internal var name: String` computed property returning the `name` associated value from all three cases (used by validation in HTTPClient and as defence-in-depth in MultipartEncoder)

- [X] T026 [US5] Create `Sources/HTTPLib/Internal/MultipartEncoder.swift` — `import Foundation`; `// FR-018, FR-019, research Decision 5`; `internal enum MultipartEncoder` with one static method `static func encode(_ items: [FormItem]) throws -> (body: Data, contentType: String)`; implementation: (1) `let boundary = "----Boundary-\(UUID().uuidString)"` (A-09: unique per call, UUID-derived); (2) for each item validate `guard !item.name.isEmpty else { throw HTTPClientError.emptyFormItemName }` (defence-in-depth — HTTPClient validates first, encoder is a second guard); (3) build body using `var bodyData = Data()` and a helper `func append(_ string: String) { bodyData.append(Data(string.utf8)) }`; (4) for each item emit: `--<boundary>\r\n`, `Content-Disposition: form-data; name="<name>"` plus `; filename="<fileName>"` if `fileName != nil`, then `\r\n`, `Content-Type: <mimeType or default>\r\n` where default is `application/octet-stream` for `.file` and `.data`, `text/plain` for `.property` (FR-019), then `\r\n`, then the part body bytes, then `\r\n`; for `.file` items read data with `Data(contentsOf: url)` inside `do { } catch { throw HTTPClientError.fileReadFailed(url: url, underlying: error) }`; for `.data` items use `body` directly; for `.property` items use `Data(value.utf8)`; (5) append final boundary `--<boundary>--\r\n`; (6) return `(body: bodyData, contentType: "multipart/form-data; boundary=\(boundary)")`; use `\r\n` string literals throughout (RFC 2046 §4.1, research Decision 5 — never `\n`-only)

- [X] T027 [US5] Add `post(_:formItems:headers:)` to `Sources/HTTPLib/HTTPClient.swift` — add: `public func post(_ url: URL, formItems: [FormItem], headers: [String: String]? = nil) async throws -> HTTPResponse`; implementation: (1) `try Task.checkCancellation()  // FR-007`; (2) `guard !formItems.isEmpty else { throw HTTPClientError.emptyFormItems }  // FR-020`; (3) `guard formItems.allSatisfy({ !$0.name.isEmpty }) else { throw HTTPClientError.emptyFormItemName }  // FR-021`; (4) `let (multipartBody, contentType) = try MultipartEncoder.encode(formItems)`; (5) build request: `var request = URLRequest(url: url); request.httpMethod = "POST"`; apply caller `headers`: `headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }`; then `request.setValue(contentType, forHTTPHeaderField: "Content-Type")  // library header overwrites any caller conflict (FR-009, US3-AC-03)`; then `self.configurator?(&request)  // FR-011`; `request.httpBody = multipartBody`; (6) dispatch: `do { let (data, urlResponse) = try await self.session.data(for: request); guard let httpResponse = urlResponse as? HTTPURLResponse else { throw HTTPClientError.networkError(URLError(.badServerResponse)) }; return HTTPResponse(statusCode: httpResponse.statusCode, body: data.isEmpty ? nil : data) } catch is CancellationError { throw } catch let e as HTTPClientError { throw e } catch { throw HTTPClientError.networkError(error) }  // CancellationError and HTTPClientError propagate directly; all other errors wrapped`

**Checkpoint**: `swift test --filter MultipartEncoderTests` and `HTTPClientMultipartTests` GREEN.
RFC 2046 encoding, validation errors, and the multipart Content-Type header all confirmed.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Cancellation testing, completeness audit, and the two hard quality gates from
`quickstart.md` and the constitution.

- [X] T028 Create `Tests/HTTPLibTests/HTTPClientCancellationTests.swift` — `@Suite("HTTPClient Cancellation") struct HTTPClientCancellationTests`; two `@Test` async throws methods: (1) `preFlightCancellationThrowsCancellationErrorNotNetworkError()` — configure `MockURLProtocol.stub` with a 200 response; create `let task = Task { try await makeEngine().get(url) }`; immediately call `task.cancel()`; `do { _ = try await task.value; Issue.record("Expected CancellationError") } catch is CancellationError { /* PASS */ } catch { Issue.record("Caught \(error) instead of CancellationError") }`; assert the caught error is `CancellationError`, NOT `HTTPClientError` (FR-007, research Decision 8); (2) `cancellationErrorIsNeverWrappedInHTTPClientError()` — same setup, same flow; explicitly assert `!(error is HTTPClientError)` inside the unexpected-catch branch to confirm the library never wraps `CancellationError`; import `Testing`, `Foundation`, `@testable import HTTPClientLib`

- [X] T029 Audit `Sources/HTTPLib/HTTPClient.swift` for complete cancellation coverage — confirm `try Task.checkCancellation()` appears at the top of every public method implementation (get, post no-body, post body, post formItems, put no-body, put body, delete no-body, delete body — eight methods total) and that every `do/catch` block wrapping `session.data(for:)` contains `catch is CancellationError { throw }` as its **first** catch clause so `CancellationError` escapes before the generic `catch { throw HTTPClientError.networkError(error) }` clause; add any missing calls or re-throw guards; annotate each with `// FR-007: CancellationError propagates directly`

- [X] T030 [P] Run `swift build 2>&1` from the repository root and resolve **every** compiler warning — zero warnings is a hard gate per Constitution I and the Quality Gates section of `constitution.md`; common sources in this codebase: unused variables (prefix with `_`), `any Protocol` existentials not marked `sending`, missing `@Sendable` on stored closures, implicit type coercions; **do not suppress warnings** with `#if` or `@_silgen_name` — fix the underlying cause; `swift build` must exit with `Build complete!` and no `warning:` lines

- [X] T031 [P] Run `swift test 2>&1` from the repository root — all test suites must pass with zero failures; if any test fails, run `swift test --filter <SuiteName>` to isolate and fix the failing implementation; the final output must show `Test Suite 'All tests' passed` (or the Swift Testing equivalent) with 0 failures; confirm `swift build 2>&1 | grep -c warning` returns `0` (quickstart.md §Full Test Suite Run)

**Checkpoint**: `swift build` — zero warnings ✅ | `swift test` — zero failures ✅ |
Feature complete per quickstart.md success criteria SC-001 through SC-006.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup           — no prerequisites; start immediately
Phase 2: Foundational    — depends on Phase 1 completion; BLOCKS Phases 3–8
Phase 3: User Story 1    — depends on Phase 2; no other story prerequisites
Phase 4: User Story 2    — depends on Phase 3 (body overloads extend HTTPClient.swift and RequestBuilder.swift from US1)
Phase 5: User Story 3    — depends on Phase 4 (conflict-resolution test requires body variants to exist)
Phase 6: User Story 4    — depends on Phase 3 (test extensions reference US1 test files and HTTPClient signatures)
Phase 7: User Story 5    — depends on Phase 2 and Phase 3 (MockURLProtocol + HTTPClient.swift both required)
Phase 8: Polish          — depends on Phases 3–7 all complete
```

### User Story Dependencies (spec.md SC-005: no breaking changes between stories)

| Story | Prerequisite | Rationale |
|-------|-------------|-----------|
| US1 (P1) | Phase 2 | Foundational types must exist |
| US2 (P2) | US1 | Body overloads extend `HTTPClient.swift` and `RequestBuilder.swift` from US1 |
| US3 (P3) | US2 | Conflict-resolution test (AC-03) requires `.json` body to produce a library-managed Content-Type |
| US4 (P4) | US1 | Session and configurator tests extend US1 test suites |
| US5 (P5) | US1 + Phase 2 | `HTTPClientMultipartTests` uses `MockURLProtocol`; multipart overload calls `self.session.data(for:)` |

### Within Each Phase

- [P]-marked tasks operate on separate files — safe to run concurrently
- Test tasks **must precede** implementation tasks within the same story (TDD — Constitution II)
- Verify tests FAIL (compilation error counts as RED if the type doesn't exist yet) before writing implementation
- Commit after each phase checkpoint once `swift build && swift test` both pass

---

## Parallel Execution Examples

### Phase 2 — All four foundation files in parallel

```
Task A: Tests/HTTPLibTests/Helpers/MockURLProtocol.swift    (T003)
Task B: Sources/HTTPLib/HTTPClientError.swift               (T004)
Task C: Sources/HTTPLib/HTTPResponse.swift                  (T005)
Task D: Sources/HTTPLib/RequestBody.swift                   (T006)
```

### Phase 3 US1 — Tests in parallel, then sequential implementation

```
# Parallel RED — write tests first:
Task A: Tests/HTTPLibTests/HTTPClientGetTests.swift         (T007)
Task B: Tests/HTTPLibTests/HTTPClientPostTests.swift        (T008)
Task C: Tests/HTTPLibTests/HTTPClientPutTests.swift         (T009)
Task D: Tests/HTTPLibTests/HTTPClientDeleteTests.swift      (T010)

# Sequential GREEN — make tests pass:
Step 1: Sources/HTTPLib/Internal/RequestBuilder.swift       (T011)
Step 2: Sources/HTTPLib/HTTPClient.swift                    (T012)
```

### Phase 4 US2 — Test extensions in parallel, then sequential implementation

```
# Parallel RED:
Task A: Extend Tests/HTTPLibTests/HTTPClientPostTests.swift   (T013)
Task B: Extend Tests/HTTPLibTests/HTTPClientPutTests.swift    (T014)
Task C: Extend Tests/HTTPLibTests/HTTPClientDeleteTests.swift (T015)

# Sequential GREEN:
Step 1: Update Sources/HTTPLib/Internal/RequestBuilder.swift  (T016)
Step 2: Extend Sources/HTTPLib/HTTPClient.swift               (T017)
```

### Phase 7 US5 — Tests and FormItem in parallel, then encoder, then engine

```
# Parallel RED + FormItem:
Task A: Tests/HTTPLibTests/MultipartEncoderTests.swift           (T023)
Task B: Tests/HTTPLibTests/HTTPClientMultipartTests.swift        (T024)
Task C: Sources/HTTPLib/FormItem.swift                           (T025)

# Sequential GREEN:
Step 1: Sources/HTTPLib/Internal/MultipartEncoder.swift          (T026)
Step 2: Extend Sources/HTTPLib/HTTPClient.swift (multipart POST) (T027)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete **Phase 1** (Setup) + **Phase 2** (Foundational)
2. Complete **Phase 3** (US1) — basic GET/POST/PUT/DELETE, no-body
3. **STOP AND VALIDATE**: Run `swift test --filter HTTPClientGetTests` (and Post, Put, Delete)
4. MVP is shippable — a developer can issue any HTTP request by supplying only a URL (SC-001)

### Incremental Delivery

1. Setup + Foundational → types exist, package builds clean
2. **+US1** → basic requests work → validate → shippable increment
3. **+US2** → body variants work → validate → shippable increment
4. **+US3** → custom headers verified → validate (pure test coverage, no API change)
5. **+US4** → session injection verified → validate (pure test coverage, no API change)
6. **+US5** → multipart upload works → validate → shippable increment
7. **+Polish** → cancellation tested, zero warnings, full suite green → feature complete

### Single-Developer Sequential Order

```
T001 → T002 → T003 → T004 → T005 → T006 →
T007 → T008 → T009 → T010 → T011 → T012 →
T013 → T014 → T015 → T016 → T017 →
T018 → T019 →
T020 → T021 → T022 →
T023 → T024 → T025 → T026 → T027 →
T028 → T029 → T030 → T031
```

---

## Notes

- **[P]** tasks operate on different files with no intra-phase dependencies — safe to parallelise
- **[US1–US5]** labels map each task to spec.md priorities P1–P5 for SC-005 traceability (no
  breaking changes to prior stories when adding new ones)
- **TDD gate**: A test task is not done until the test compiles AND fails (RED). An implementation
  task is not done until all story tests pass (GREEN). This is Constitution II, non-negotiable.
- **Swift Testing**: `import Testing`, `@Test`, `@Suite`, `#expect`, `Issue.record` — not XCTest.
  This is a justified deviation documented in plan.md Complexity Tracking and research.md Decision 1.
- **Zero force-unwraps in `Sources/`**: `!` in `Tests/` helpers (e.g., `HTTPURLResponse(…)!`) is
  acceptable. Any `!` in `Sources/HTTPLib/` is a Constitution I violation and must be fixed.
- **Zero compiler warnings**: Constitution I / Quality Gates — `swift build` must produce no
  `warning:` lines. Fix causes; never suppress.
- **Commit cadence**: Run `swift build && swift test` after each phase checkpoint and commit if
  both pass.
