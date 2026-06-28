import Foundation

// FR-004, FR-008: status code + optional body; non-2xx never thrown
public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let body: Data?

    // Only HTTPClient constructs HTTPResponse values inside the module, never a caller.
    init(statusCode: Int, body: Data?) {
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
