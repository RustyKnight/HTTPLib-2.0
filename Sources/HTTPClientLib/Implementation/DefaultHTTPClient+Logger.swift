import Foundation

public extension DefaultHTTPClient {
    protocol Logger: Sendable {
        var includeHeaders: Bool { get }
        var includeBody: Bool { get }
        func log(_ message: String)
    }
}

internal extension URLRequest {
    func httpClientLogDescription(
        method: HTTPMethod,
        includeHeaders: Bool,
        includeBody: Bool
    ) -> String {
        var lines: [String] = ["[\(method.httpClientLogLabel)] \(url?.absoluteString ?? "")"]

        if includeHeaders {
            let headerLines = (allHTTPHeaderFields ?? [:])
                .sorted { lhs, rhs in
                    let lhsKey = lhs.key.lowercased()
                    let rhsKey = rhs.key.lowercased()
                    if lhsKey == rhsKey {
                        return lhs.value < rhs.value
                    }
                    return lhsKey < rhsKey
                }
                .map { "\($0.key): \($0.value)" }
            lines.append(contentsOf: headerLines)
        }

        if includeBody, let bodyLine = httpClientLogBodyLine {
            lines.append("Body: \(bodyLine)")
        }

        return lines.joined(separator: "\n")
    }

    private var httpClientLogBodyLine: String? {
        guard let body = httpBody, !body.isEmpty else { return nil }

        if let contentType = value(forHTTPHeaderField: "Content-Type"),
           Self.httpClientShouldRenderBodyAsText(contentType: contentType),
           let bodyString = String(data: body, encoding: .utf8) {
            return bodyString
        }

        return "[binary data]"
    }

    private static func httpClientShouldRenderBodyAsText(contentType: String) -> Bool {
        let normalized = contentType.lowercased()
        return normalized.hasPrefix("text/")
            || normalized.contains("json")
            || normalized.contains("xml")
            || normalized.contains("x-www-form-urlencoded")
            || normalized.contains("javascript")
    }
}

private extension HTTPMethod {
    var httpClientLogLabel: String {
        rawValue.padding(toLength: 4, withPad: " ", startingAt: 0)
    }
}
