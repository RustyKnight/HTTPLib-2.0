# HTTPClientLib

A lightweight async/await HTTP library for Swift with a **protocol-first** public surface.

`HTTPClient` and `HTTPResponse` are public protocols so call sites can depend on behavior, not implementation. `DefaultHTTPClient` and `DefaultHTTPResponse` are the built-in implementations.

APIs can define HTTP expectations without needing to rely on the implementation and callers can implement the public surface in any way they want, falling back to the default implementation if they wish to.

# Experimental

<img src=".assets/github-copilot-icon.svg" alt="GitHub Copilot" width="128" height="128">

This is an experiment with Github SpecKit and Github Copilot.

# Highlights

- Protocol-based public API (`HTTPClient`, `HTTPResponse`)
- Built-in default implementation (`DefaultHTTPClient`)
- Async API (`async throws`) built on `URLSession`
- Engine-level default headers
- Engine-level transport configuration via `DefaultHTTPClient.Configuration`
- Optional custom `URLSession` injection
- **Fine-grained progress tracking** via optional `SupportLib.ProgressTracker` parameter
  - Per-byte upload progress tracking during request transmission
  - Per-byte download progress tracking during response reception
  - Hierarchical progress aggregation (parent = average of children)
  - `ProgressTracker` is `ObservableObject` for Combine integration
- Request bodies for `POST` / `PUT` / `DELETE`:
  - text (`.text`)
  - raw data (`.binary(Data, contentType:)`)
  - JSON (`.json(any Encodable)`)
- Multipart form-data upload support for `POST`
- Typed errors via `HTTPClientError`
- Non-2xx HTTP responses are returned (not thrown)
- Optional request and response logging via `DefaultHTTPClient.Logger`

# Requirements

- Swift 6.0+
- macOS 14.0+, iOS 15.0+, tvOS 15.0+, visionOS 1.0+

## Add to your package

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/HTTPClientLib.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["HTTPClientLib"]
    )
]
```

## Quick start

```swift
import HTTPClientLib
import Foundation

let client = DefaultHTTPClient()
let response = try await client.get(URL(string: "https://httpbin.org/get")!)

print(response.statusCode)
if let body = response.body {
    print(String(decoding: body, as: UTF8.self))
}
```

## Depending on the protocol surface

```swift
import HTTPClientLib

func fetchHealth(using client: any HTTPClient, url: URL) async throws -> Int {
    let response = try await client.get(url)
    return response.statusCode
}
```

## Convenience overloads

`HTTPClient` includes convenience overloads via protocol extension so common calls
can omit `nil` body/header arguments:

```swift
// GET
try await client.get(url)

// POST
try await client.post(url)
try await client.post(url, body: .json(payload))
try await client.post(url, headers: ["X-Trace": "123"])

// PUT
try await client.put(url)
try await client.put(url, body: .text("hello"))
try await client.put(url, headers: ["If-Match": etag])

// DELETE
try await client.delete(url)
try await client.delete(url, body: .text("reason"))
try await client.delete(url, headers: ["X-Soft-Delete": "true"])

// Multipart POST
try await client.post(url, formItems: items)
```

## Optional progress parameter

`HTTPClient` and `DefaultHTTPClient` expose an optional `progress:` parameter on all
`get`/`post`/`put`/`delete` method variants (including multipart `post`):

```swift
import HTTPClientLib
import SupportLib

let progress = SupportLib.Progress()
let response = try await DefaultHTTPClient().get(
    URL(string: "https://api.example.com/users")!,
    headers: nil,
    progress: progress
)
```

`progress` defaults to `nil`, so existing call sites do not need to change.

## Example: default headers + per-request override

```swift
import HTTPClientLib
import Foundation

let client = DefaultHTTPClient(
    defaultHeaders: [
        "Authorization": "Bearer <token>",
        "Accept": "application/json"
    ]
)

let me = try await client.get(URL(string: "https://api.example.com/me")!)

let users = try await client.get(
    URL(string: "https://api.example.com/users")!,
    headers: ["Accept": "application/vnd.api+json"]
)
```

## Example: JSON request body

```swift
import HTTPClientLib
import Foundation

struct CreateUser: Encodable {
    let name: String
    let email: String
}

let client = DefaultHTTPClient()
let url = URL(string: "https://api.example.com/users")!

let response = try await client.post(
    url,
    body: .json(CreateUser(name: "Test", email: "test@example.com")),
    headers: ["Authorization": "Bearer <token>"]
)
```

## Example: request configuration + custom session

```swift
import HTTPClientLib
import Foundation

let sessionConfig = URLSessionConfiguration.default
let requestConfig = DefaultHTTPClient.Configuration(
    timeoutInterval: 15,
    cachePolicy: .reloadIgnoringLocalCacheData
)

let client = DefaultHTTPClient(
    configuration: requestConfig,
    defaultHeaders: ["Accept": "application/json"]
)

let customSession = URLSession(configuration: sessionConfig)
let clientWithCustomSession = DefaultHTTPClient(
    session: customSession,
    configuration: requestConfig
)
```

## Example: multipart form-data POST

```swift
import HTTPClientLib
import Foundation

let fileURL = URL(fileURLWithPath: "/tmp/avatar.jpg")

let items: [FormItem] = [
    .property(name: "username", value: "test"),
    .file(name: "avatar", url: fileURL, fileName: "avatar.jpg", mimeType: "image/jpeg")
]

let response = try await DefaultHTTPClient().post(
    URL(string: "https://api.example.com/upload")!,
    formItems: items
)
```

## Example: monitoring progress with Combine

`ProgressTracker` is an `ObservableObject` that publishes progress updates. Use Combine to monitor and respond to progress changes:

```swift
import HTTPClientLib
import SupportLib
import Combine

let client = DefaultHTTPClient()
let progress = ProgressTracker()
var cancellables: Set<AnyCancellable> = []

// Monitor overall progress and log updates
progress.$value
    .sink { progressValue in
        let percentage = Int(progressValue * 100)
        print("Overall progress: \(percentage)%")
    }
    .store(in: &cancellables)

// Start the HTTP request with progress tracking
Task {
    let response = try await client.get(
        URL(string: "https://api.example.com/large-file")!,
        progress: progress
    )
}
```

### Monitoring individual phases

`ProgressTracker` creates hierarchical progress tracking with child trackers for request (upload) and response (download) phases. Monitor phases separately:

```swift
import HTTPClientLib
import SupportLib
import Combine

let client = DefaultHTTPClient()
let progress = ProgressTracker()
var cancellables: Set<AnyCancellable> = []

// Access children after creation by triggering the HTTP call
Task {
    // Start request in background
    let responseTask = Task {
        try await client.post(
            URL(string: "https://api.example.com/upload")!,
            body: .binary(largeData, contentType: "application/octet-stream"),
            progress: progress
        )
    }
    
    // Give time for child trackers to be created
    try? await Task.sleep(nanoseconds: 10_000_000)
    
    // Monitor both phases
    if let uploadTracker = progress.children.first {
        uploadTracker.$value
            .sink { uploadProgress in
                print("Upload: \(Int(uploadProgress * 100))%")
            }
            .store(in: &cancellables)
    }
    
    if let downloadTracker = progress.children.last {
        downloadTracker.$value
            .sink { downloadProgress in
                print("Download: \(Int(downloadProgress * 100))%")
            }
            .store(in: &cancellables)
    }
    
    let response = try await responseTask.value
}
```

### SwiftUI integration example

Use `@StateObject` to track progress in SwiftUI views:

```swift
import HTTPClientLib
import SupportLib
import SwiftUI

struct FileDownloadView: View {
    @StateObject private var progress = ProgressTracker()
    @State private var isLoading = false
    @State private var statusMessage = "Ready"
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress.value)
            
            Text("\(Int(progress.value * 100))% complete")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(statusMessage)
                .font(.body)
            
            if !isLoading {
                Button("Download") {
                    downloadFile()
                }
            }
        }
        .padding()
    }
    
    private func downloadFile() {
        isLoading = true
        statusMessage = "Downloading..."
        
        Task {
            do {
                let client = DefaultHTTPClient()
                let response = try await client.get(
                    URL(string: "https://api.example.com/large-file")!,
                    progress: progress
                )
                
                statusMessage = response.statusCode == 200
                    ? "Download complete"
                    : "Error: \(response.statusCode)"
                isLoading = false
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
```

## Error handling

```swift
import HTTPClientLib

do {
    _ = try await DefaultHTTPClient().get(URL(string: "https://example.com")!)
} catch is CancellationError {
    // Task was cancelled
} catch let error as HTTPClientError {
    switch error {
    case .jsonEncodingFailed:
        break
    case .fileReadFailed:
        break
    case .emptyFormItems, .emptyFormItemName:
        break
    case .networkError:
        break
    }
}
```

## Logging requests and responses

Implement the `DefaultHTTPClient.Logger` protocol to capture detailed logs of HTTP requests and responses. The logger receives structured `HTTPRequestLogMessage` and `HTTPResponseLogMessage` protocol objects, giving you full control over formatting and output:

```swift
import HTTPClientLib

final class ConsoleLogger: DefaultHTTPClient.Logger {
    func log(request: DefaultHTTPClient.HTTPRequestLogMessage) {
        print("🔵 REQUEST: \(request.method) \(request.url)")
        request.headers.forEach { key, value in
            print("  \(key): \(value)")
        }
        if let body = request.body {
            print("  Body: \(body)")
        }
    }
    
    func log(response: DefaultHTTPClient.HTTPResponseLogMessage) {
        print("🟢 RESPONSE: \(response.method) \(response.statusCode) \(response.url)")
        response.headers.forEach { key, value in
            print("  \(key): \(value)")
        }
        if let body = response.body {
            print("  Body: \(body)")
        }
    }
}

let client = DefaultHTTPClient(logger: ConsoleLogger())

let response = try await client.get(URL(string: "https://api.example.com/users")!)
```

### HTTPRequestLogMessage protocol

```swift
public protocol HTTPRequestLogMessage: Sendable {
    var url: String { get }
    var method: String { get }
    var headers: [String: String] { get }
    var body: String? { get }
}
```

### HTTPResponseLogMessage protocol

```swift
public protocol HTTPResponseLogMessage: Sendable {
    var url: String { get }
    var method: String { get }
    var headers: [String: String] { get }
    var statusCode: Int { get }
    var body: String? { get }
}
```

### Log output example

Request:
```
🔵 REQUEST: GET https://api.example.com/users
  Accept: application/json
  Authorization: Bearer token123
```

Response:
```
🟢 RESPONSE: GET 200 https://api.example.com/users
  Content-Type: application/json
  Transfer-Encoding: chunked
  Body: [{"id": 1, "name": "John"}, ...]
```

### Logger message content

- Request and response headers are always provided via `headers`
- `body` is `nil` when no body is present; otherwise:
  - Text-based content (JSON, XML, HTML, form-encoded, JavaScript) is provided as-is
  - Binary data is represented as `"[binary data]"`
  - Empty body data is represented as `"[no data]"`
