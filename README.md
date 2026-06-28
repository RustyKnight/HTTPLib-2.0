# HTTPLib

A lightweight Swift HTTP library with async/await support for **GET**, **POST**, **PUT**, and **DELETE**.

This is intended as a lightweight HTTP engine for basic web service interactions when you want a reusable implementation without building one from scratch.

# Experimental

This is an experiment with Github SpecKit and Github Copilot.

# Highlights

- Async API (`async throws`) built on `URLSession`
- Engine-level default headers (applied to every request)
- Per-request headers
- Optional request configurator for low-level `URLRequest` customization
- Optional custom `URLSession` injection (great for testing)
- Request bodies for `POST` / `PUT` / `DELETE`:
  - text (`.text`)
  - raw data (`.binary`)
  - JSON (`.json(any Encodable)`)
- Multipart form-data upload support for `POST`
- Typed errors via `HTTPEngineError`
- Non-2xx HTTP responses are returned (not thrown)

# Requirements

- Swift 6.0+
- macOS 14+

## Add to your package

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/HTTPLib.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["HTTPLib"]
    )
]
```

## Quick start

```swift
import HTTPLib
import Foundation

let engine = HTTPEngine()
let response = try await engine.get(URL(string: "https://httpbin.org/get")!)

print(response.statusCode)
if let body = response.body {
    print(String(decoding: body, as: UTF8.self))
}
```

## Example: default headers + per-request override

```swift
import HTTPLib
import Foundation

let engine = HTTPEngine(
    defaultHeaders: [
        "Authorization": "Bearer <token>",
        "Accept": "application/json"
    ]
)

// Uses default headers
let me = try await engine.get(URL(string: "https://api.example.com/me")!)

// Per-request header overrides default "Accept"
let users = try await engine.get(
    URL(string: "https://api.example.com/users")!,
    headers: ["Accept": "application/vnd.api+json"]
)
```

## Example: JSON request body

```swift
import HTTPLib
import Foundation

struct CreateUser: Encodable {
    let name: String
    let email: String
}

let engine = HTTPEngine()
let url = URL(string: "https://api.example.com/users")!

let response = try await engine.post(
    url,
    body: .json(CreateUser(name: "Test", email: "test@example.com")),
    headers: ["Authorization": "Bearer <token>"]
)
```

## Example: request configurator + custom session

```swift
import HTTPLib
import Foundation

let config = URLSessionConfiguration.default
let session = URLSession(configuration: config)

let engine = HTTPEngine(session: session) { request in
    request.timeoutInterval = 15
    request.cachePolicy = .reloadIgnoringLocalCacheData
}
```

## Example: multipart form-data POST

```swift
import HTTPLib
import Foundation

let fileURL = URL(fileURLWithPath: "/tmp/avatar.jpg")

let items: [FormItem] = [
    .property(name: "username", value: "test"),
    .file(name: "avatar", url: fileURL, fileName: "avatar.jpg", mimeType: "image/jpeg")
]

let response = try await HTTPEngine().post(
    URL(string: "https://api.example.com/upload")!,
    formItems: items
)
```

## Error handling

```swift
import HTTPLib

do {
    _ = try await HTTPEngine().get(URL(string: "https://example.com")!)
} catch is CancellationError {
    // Task was cancelled
} catch let error as HTTPEngineError {
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