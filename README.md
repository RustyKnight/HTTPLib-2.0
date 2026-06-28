# HTTPClientLib

A lightweight Swift HTTP library with async/await support for **GET**, **POST**, **PUT**, and **DELETE**.

This is intended as a lightweight HTTP engine for basic web service interactions when you want a reusable implementation without building one from scratch.

# Experimental

This is an experiment with Github SpecKit and Github Copilot.

# Highlights

- Async API (`async throws`) built on `URLSession`
- Engine-level default headers (applied to every request)
- Engine-level request transport configuration via `HTTPClient.Configuration`
- Per-request headers
- Optional custom `URLSession` injection (great for testing)
- Request bodies for `POST` / `PUT` / `DELETE`:
  - text (`.text`)
  - raw data (`.binary(Data, contentType:)`)
  - JSON (`.json(any Encodable)`)
- Multipart form-data upload support for `POST`
- Typed errors via `HTTPClientError`
- Non-2xx HTTP responses are returned (not thrown)

# Requirements

- Swift 6.0+
- macOS 14+

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

let engine = HTTPClient()
let response = try await engine.get(URL(string: "https://httpbin.org/get")!)

print(response.statusCode)
if let body = response.body {
    print(String(decoding: body, as: UTF8.self))
}
```

## Example: default headers + per-request override

```swift
import HTTPClientLib
import Foundation

let engine = HTTPClient(
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
import HTTPClientLib
import Foundation

struct CreateUser: Encodable {
    let name: String
    let email: String
}

let engine = HTTPClient()
let url = URL(string: "https://api.example.com/users")!

let response = try await engine.post(
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
let requestConfig = HTTPClient.Configuration(
    timeoutInterval: 15,
    cachePolicy: .reloadIgnoringLocalCacheData
)

let engine = HTTPClient(
    configuration: requestConfig,
    defaultHeaders: ["Accept": "application/json"]
)

let customSession = URLSession(configuration: sessionConfig)
let engineWithCustomSession = HTTPClient(
    session: customSession,
    configuration: requestConfig
)
```

## Example: binary request body

```swift
import HTTPClientLib
import Foundation

let engine = HTTPClient()
let payload = Data([0x01, 0x02, 0x03])

let response = try await engine.put(
    URL(string: "https://api.example.com/blob")!,
    body: .binary(payload, contentType: "application/octet-stream")
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

let response = try await HTTPClient().post(
    URL(string: "https://api.example.com/upload")!,
    formItems: items
)
```

## Error handling

```swift
import HTTPClientLib

do {
    _ = try await HTTPClient().get(URL(string: "https://example.com")!)
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