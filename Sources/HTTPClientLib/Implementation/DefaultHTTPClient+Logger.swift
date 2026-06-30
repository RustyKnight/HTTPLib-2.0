import Foundation

public extension DefaultHTTPClient {
    /// Protocol for logging HTTP requests and responses.
    ///
    /// Implement this protocol to capture detailed information about API requests and responses
    /// sent through a `DefaultHTTPClient`. The logger receives formatted strings containing
    /// the HTTP method, URL, status code, headers (optional), and body (optional).
    ///
    /// ### Logging Format
    /// - **Request**: `[{METHOD}] {url}` with optional headers and body
    /// - **Response**: `[{METHOD}] {statusCode} {url}` with optional headers and body
    ///
    /// Example request log:
    /// ```
    /// [GET ] https://api.example.com/users
    /// Authorization: Bearer token123
    /// Accept: application/json
    /// ```
    ///
    /// Example response log:
    /// ```
    /// [GET ] 200 https://api.example.com/users
    /// Content-Type: application/json
    /// Body: {"users": [...]}
    /// ```
    protocol Logger: Sendable {
        /// Whether to include HTTP headers in logged messages.
        ///
        /// When `true`, request and response headers are included in the log output,
        /// sorted alphabetically by key (case-insensitive).
        var includeHeaders: Bool { get }

        /// Whether to include request and response bodies in logged messages.
        ///
        /// When `true`, request and response bodies are included in the log output.
        /// - Text, JSON, XML, and form-encoded bodies are rendered as-is
        /// - Binary bodies are represented as `"[binary data]"`
        /// - Empty or missing bodies are represented as `"[no data]"`
        var includeBody: Bool { get }

        /// Logs an outgoing HTTP request.
        ///
        /// Called after the request is constructed but before it's sent to the network.
        /// The formatted string includes the HTTP method, URL, and optionally headers and body
        /// based on `includeHeaders` and `includeBody`.
        ///
        /// - Parameter request: Formatted log message for the HTTP request
        func log(request: String)

        /// Logs an incoming HTTP response.
        ///
        /// Called after the response is received from the network. The formatted string includes
        /// the HTTP method, status code, URL, and optionally headers and body based on
        /// `includeHeaders` and `includeBody`.
        ///
        /// - Parameter response: Formatted log message for the HTTP response
        func log(response: String)
    }
}

// MARK: - Helper functionality.

/// Dictionary extension providing header formatting for logging.
fileprivate extension [String: String] {
    
    /// Returns HTTP headers formatted as log messages, sorted alphabetically by key.
    var logMessages: [String] {
        sorted { lhs, rhs in
            let lhsKey = lhs.key.lowercased()
            let rhsKey = rhs.key.lowercased()
            if lhsKey == rhsKey {
                return lhs.value < rhs.value
            }
            return lhsKey < rhsKey
        }
        .map { "\($0.key): \($0.value)" }
    }
    
    /// Returns the Content-Type header value, if present (case-insensitive lookup).
    var contentType: String? {
        first(where: { $0.key.lowercased() == "content-type" })?.value
    }
}

/// String extension providing content-type detection for text representation.
fileprivate extension String {
    
    /// Returns true if this content-type should be rendered as text in logs.
    ///
    /// Includes: text/*, application/json, application/xml, form-encoded, and JavaScript.
    var isContentTypeRepresentableAsText: Bool {
        let normalized = lowercased()
        return normalized.hasPrefix("text/")
        || normalized.contains("json")
        || normalized.contains("xml")
        || normalized.contains("x-www-form-urlencoded")
        || normalized.contains("javascript")
    }
}

/// Data extension providing body formatting for logging.
fileprivate extension Data {
    
    /// Returns a formatted log representation of this data.
    ///
    /// - Returns text content for text-based content-types (JSON, XML, etc.)
    /// - Returns `"[binary data]"` for binary content-types
    /// - Returns `"[no data]"` for empty data
    func logMessage(contentType: String?) -> String {
        guard !isEmpty else { return "[no data]" }
        
        guard let contentType, contentType.isContentTypeRepresentableAsText,
                let bodyString = String(data: self, encoding: .utf8) else {
            return "[binary data]"
        }
        return bodyString
    }
}

private extension HTTPMethod {
    /// Formats the HTTP method for logging (4-character width, left-aligned).
    /// Used to align request and response log output.
    var logLabel: String {
        rawValue.padding(toLength: 4, withPad: " ", startingAt: 0)
    }
}

// MARK: - Logging support

/// URLRequest extension providing formatted logging output.
internal extension URLRequest {
    /// Generates a formatted log message for this HTTP request.
    ///
    /// The log message includes:
    /// - HTTP method and URL (always)
    /// - Headers (if `includeHeaders` is true), sorted alphabetically
    /// - Request body (if `includeBody` is true), with text/binary detection
    ///
    /// Example output:
    /// ```
    /// [POST] https://api.example.com/users
    /// Accept: application/json
    /// Content-Type: application/json
    /// Body: {"name": "John"}
    /// ```
    ///
    /// - Parameters:
    ///   - method: The HTTP method being used
    ///   - includeHeaders: Whether to include headers in the output
    ///   - includeBody: Whether to include the request body in the output
    /// - Returns: A multi-line string with the formatted request details
    func httpClientLogDescription(
        method: HTTPMethod,
        includeHeaders: Bool,
        includeBody: Bool
    ) -> String {
        var lines: [String] = ["[\(method.logLabel)] \(url?.absoluteString ?? "")"]

        let headers = allHTTPHeaderFields ?? [:]
        if includeHeaders {
            lines.append(contentsOf: headers.logMessages)
        }
        
        if includeBody {
            let bodyLine = httpBody?.logMessage(contentType: headers.contentType) ?? "[no data]"
            lines.append("Body: \(bodyLine)")
        }

        return lines.joined(separator: "\n")
    }
}

internal extension HTTPResponse {    
    /// Generates a formatted log message for this HTTP response.
    ///
    /// The log message includes:
    /// - HTTP method, status code, and URL (always)
    /// - Headers (if `includeHeaders` is true), sorted alphabetically
    /// - Response body (if `includeBody` is true), with text/binary detection
    ///
    /// Example output:
    /// ```
    /// [GET ] 200 https://api.example.com/users
    /// Content-Type: application/json
    /// Transfer-Encoding: chunked
    /// Body: [{"id": 1, "name": "John"}, ...]
    /// ```
    ///
    /// - Parameters:
    ///   - includeHeaders: Whether to include headers in the output
    ///   - includeBody: Whether to include the response body in the output
    /// - Returns: A multi-line string with the formatted response details
    func logMessage(
        includeHeaders: Bool,
        includeBody: Bool
    ) -> String {
        var lines: [String] = ["[\(method.logLabel)] \(statusCode) \(url.absoluteString)"]

        if includeHeaders {
            lines.append(contentsOf: headers.logMessages)
        }

        if includeBody {
            let bodyLine = body?.logMessage(contentType: headers.contentType) ?? "[no data]"
            lines.append("Body: \(bodyLine)")
        }

        return lines.joined(separator: "\n")
    }
}
