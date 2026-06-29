import Foundation

// FR-004, FR-008: status code + optional body; non-2xx never thrown
public struct HTTPResponse: Sendable {
    public let url: URL
    public let method: HTTPMethod
    public let headers: [String: String]
    public let statusCode: Int
    public let body: Data?

    // Only HTTPClient constructs HTTPResponse values inside the module, never a caller.
    init(url: URL, method: HTTPMethod, headers: [String: String], statusCode: Int, body: Data?) {
        self.url = url
        self.method = method
        self.headers = headers
        self.statusCode = statusCode
        self.body = body
    }
}


public extension HTTPResponse {
    
    /// Returns the `body` as `String` using `utf8` encoding.
    /// Should be considered for debugging only.
    var bodyString: String? {
        guard let body else { return nil }
        return String(data: body, encoding: .utf8)
    }
}
