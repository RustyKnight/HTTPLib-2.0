import Foundation

/// Default implementation of the `HTTPResponse` protocol.
public struct DefaultHTTPResponse: HTTPResponse {
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
