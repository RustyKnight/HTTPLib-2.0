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
- Request bodies for `POST` / `PUT` / `DELETE`:
  - text (`.text`)
  - raw data (`.binary(Data, contentType:)`)
  - JSON (`.json(any Encodable)`)
- Multipart form-data upload support for `POST`
- Typed errors via `HTTPClientError`
- Non-2xx HTTP responses are returned (not thrown)

# Requirements

- Swift 6.0+
- macOS 10.15+, iOS 13+, tvOS 13+, visionOS 1+

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
