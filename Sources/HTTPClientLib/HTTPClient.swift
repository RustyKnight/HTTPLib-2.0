//
//  HTTPClient.swift
//  HTTPClientLib
//
//  Created by Shane Whitehead on 30/6/2026.
//
import Foundation

/// Protocol-first public HTTP client surface.
///
/// `HTTPClient` defines request/response behavior without coupling callers to a concrete implementation.
/// Use `DefaultHTTPClient` when you want the built-in implementation provided by this module.
public protocol HTTPClient: Sendable {

    // MARK: - GET (FR-002, FR-014 — no body parameter)

    func get(
        _ url: URL,
        headers: [String: String]?
    ) async throws -> HTTPResponse

    // MARK: - POST (FR-002)

    /// Sends a `POST` request with an optional body.
    func post(
        _ url: URL,
        body: RequestBody?,
        headers: [String: String]?
    ) async throws -> HTTPResponse

    // MARK: - PUT (FR-002)

    /// Sends a `PUT` request with an optional body.
    func put(
        _ url: URL,
        body: RequestBody?,
        headers: [String: String]?
    ) async throws -> HTTPResponse

    // MARK: - POST multipart (FR-015, US5)

    /// Sends a multipart `POST` request. `formItems` must be non-empty and all items must have
    /// non-empty names. Throws before any network activity on validation or encoding failure.
    func post(
        _ url: URL,
        formItems: [FormItem],
        headers: [String: String]?
    ) async throws -> HTTPResponse

    // MARK: - DELETE (FR-002)

    /// Sends a `DELETE` request with an optional body.
    func delete(
        _ url: URL,
        body: RequestBody?,
        headers: [String: String]?
    ) async throws -> HTTPResponse
}

public extension HTTPClient {

    // MARK: - GET

    /// Convenience overload for requests with no per-request headers.
    func get(_ url: URL) async throws -> HTTPResponse {
        try await get(url, headers: nil)
    }

    // MARK: - POST

    /// Convenience overload for a request body with no per-request headers.
    func post(
        _ url: URL,
        body: RequestBody
    ) async throws -> HTTPResponse {
        try await post(url, body: body, headers: nil)
    }
    
    /// Convenience overload for headers-only requests.
    func post(
        _ url: URL,
        headers: [String: String]
    ) async throws -> HTTPResponse {
        try await post(url, body: nil, headers: headers)
    }

    /// Convenience overload for body-less requests with no per-request headers.
    func post(_ url: URL) async throws -> HTTPResponse {
        try await post(url, body: nil, headers: nil)
    }

    // MARK: - PUT

    /// Convenience overload for a request body with no per-request headers.
    func put(
        _ url: URL,
        body: RequestBody
    ) async throws -> HTTPResponse {
        try await put(url, body: body, headers: nil)
    }
    
    /// Convenience overload for headers-only requests.
    func put(
        _ url: URL,
        headers: [String: String]
    ) async throws -> HTTPResponse {
        try await put(url, body: nil, headers: headers)
    }

    /// Convenience overload for body-less requests with no per-request headers.
    func put(_ url: URL) async throws -> HTTPResponse {
        try await put(url, body: nil, headers: nil)
    }

    // MARK: - POST multipart

    /// Convenience overload for multipart requests with no per-request headers.
    func post(
        _ url: URL,
        formItems: [FormItem]
    ) async throws -> HTTPResponse {
        try await post(url, formItems: formItems, headers: nil)
    }

    // MARK: - DELETE

    /// Convenience overload for a request body with no per-request headers.
    func delete(
        _ url: URL,
        body: RequestBody
    ) async throws -> HTTPResponse {
        try await delete(url, body: body, headers: nil)
    }
    
    /// Convenience overload for headers-only requests.
    func delete(
        _ url: URL,
        headers: [String: String]
    ) async throws -> HTTPResponse {
        try await delete(url, body: nil, headers: headers)
    }

    /// Convenience overload for body-less requests with no per-request headers.
    func delete(_ url: URL) async throws -> HTTPResponse {
        try await delete(url, body: nil, headers: nil)
    }
}
