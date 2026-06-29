//
//  HTTPResponse.swift
//  HTTPClientLib
//
//  Created by Shane Whitehead on 30/6/2026.
//

import Foundation

/// Protocol-first HTTP response surface returned by `HTTPClient`.
///
/// This protocol decouples response handling from any concrete implementation.
/// `DefaultHTTPResponse` is the module's built-in response type.
public protocol HTTPResponse: Sendable {
    var url: URL { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var statusCode: Int { get }
    var body: Data? { get }
}


public extension HTTPResponse {
    
    /// Returns the `body` as `String` using `utf8` encoding.
    /// Should be considered for debugging only.
    var bodyString: String? {
        guard let body else { return nil }
        return String(data: body, encoding: .utf8)
    }
}
