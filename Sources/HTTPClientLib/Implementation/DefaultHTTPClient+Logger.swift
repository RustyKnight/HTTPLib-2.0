import Foundation

public extension DefaultHTTPClient {
    /// Protocol for logging HTTP requests and responses.
    ///
    /// Implement this protocol to capture structured information about API requests and responses
    /// sent through a `DefaultHTTPClient`. The logger receives protocol objects containing
    /// the HTTP method, URL, status code (for responses), headers, and body.
    ///
    /// The `includeHeaders` and `includeBody` properties control what data is available in the
    /// log messages. When `includeHeaders` is `false`, the headers dictionary may be empty.
    /// When `includeBody` is `false`, the body may be `nil` even if data was present.
    ///
    /// ### Example implementation
    /// ```
    /// final class ConsoleLogger: DefaultHTTPClient.Logger {
    ///     let includeHeaders = true
    ///     let includeBody = true
    ///
    ///     func log(request: DefaultHTTPClient.HTTPRequestLogMessage) {
    ///         print("→ \(request.method) \(request.url)")
    ///         request.headers.forEach { key, value in
    ///             print("  \(key): \(value)")
    ///         }
    ///         if let body = request.body {
    ///             print("  Body: \(body)")
    ///         }
    ///     }
    ///
    ///     func log(response: DefaultHTTPClient.HTTPResponseLogMessage) {
    ///         print("← \(response.method) \(response.statusCode) \(response.url)")
    ///         response.headers.forEach { key, value in
    ///             print("  \(key): \(value)")
    ///         }
    ///         if let body = response.body {
    ///             print("  Body: \(body)")
    ///         }
    ///     }
    /// }
    /// ```
    protocol Logger: Sendable {
        /// Logs an outgoing HTTP request.
        ///
        /// Called after the request is constructed but before it's sent to the network.
        /// The message contains the HTTP method, URL, and optionally headers and body
        /// based on `includeHeaders` and `includeBody`.
        ///
        /// - Parameter request: Structured log message for the HTTP request
        func log(request: HTTPRequestLogMessage)

        /// Logs an incoming HTTP response.
        ///
        /// Called after the response is received from the network. The message contains
        /// the HTTP method, status code, URL, and optionally headers and body based on
        /// `includeHeaders` and `includeBody`.
        ///
        /// - Parameter response: Structured log message for the HTTP response
        func log(response: HTTPResponseLogMessage)
    }
}

public extension DefaultHTTPClient {
    /// Protocol for structured HTTP request log messages.
    ///
    /// Loggers receive this protocol type to access detailed information about outgoing HTTP requests.
    /// The properties provide raw structured data, giving the logger full control over formatting and output.
    protocol HTTPRequestLogMessage: Sendable {
        /// The complete URL of the request as a string.
        var url: String { get }
        
        /// The HTTP method (GET, POST, PUT, DELETE, etc.) as a string.
        var method: String { get }
        
        /// The HTTP headers as a dictionary. May be empty if `Logger.includeHeaders` is `false`.
        var headers: [String: String] { get }
        
        /// The request body, if present and `Logger.includeBody` is `true`.
        /// - Text bodies are represented as strings
        /// - Binary bodies are represented as `"[binary data]"`
        /// - Empty or missing bodies are `nil`
        var body: String? { get }
    }
    
    /// Protocol for structured HTTP response log messages.
    ///
    /// Loggers receive this protocol type to access detailed information about incoming HTTP responses.
    /// The properties provide raw structured data, giving the logger full control over formatting and output.
    protocol HTTPResponseLogMessage: Sendable {
        /// The complete URL of the response as a string.
        var url: String { get }
        
        /// The HTTP method (GET, POST, PUT, DELETE, etc.) as a string.
        var method: String { get }
        
        /// The HTTP headers as a dictionary. May be empty if `Logger.includeHeaders` is `false`.
        var headers: [String: String] { get }
        
        /// The HTTP status code (200, 404, 500, etc.).
        var statusCode: Int { get }
        
        /// The response body, if present and `Logger.includeBody` is `true`.
        /// - Text bodies are represented as strings
        /// - Binary bodies are represented as `"[binary data]"`
        /// - Empty or missing bodies are `nil`
        var body: String? { get }
    }
}

fileprivate struct DefaultRequestLogMessage: DefaultHTTPClient.HTTPRequestLogMessage {
    let url: String
    let method: String
    let headers: [String : String]
    let body: String?
}

fileprivate struct DefaultResponseLogMessage: DefaultHTTPClient.HTTPResponseLogMessage {
    let url: String
    let method: String
    let headers: [String : String]
    let statusCode: Int
    let body: String?
}

// MARK: - Helper functionality.

/// Dictionary extension providing header formatting for logging.
fileprivate extension [String: String] {
    
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
    func logMessage() -> DefaultHTTPClient.HTTPRequestLogMessage {
        let headers = (allHTTPHeaderFields ?? [:])
        let bodyText = httpBody?.logMessage(contentType: headers.contentType)
        
        return DefaultRequestLogMessage(
            url: url?.absoluteString ?? "[unknown]",
            method: method!.rawValue,
            headers: headers,
            body: bodyText
        )
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
    func logMessage() -> DefaultHTTPClient.HTTPResponseLogMessage {
        let bodyText = body?.logMessage(contentType: headers.contentType)

        return DefaultResponseLogMessage(
            url: url.absoluteString,
            method: method.rawValue,
            headers: headers,
            statusCode: statusCode,
            body: bodyText
        )
    }
}
