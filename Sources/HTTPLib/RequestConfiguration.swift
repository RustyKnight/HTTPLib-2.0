import Foundation


public extension HTTPEngine {
    // FR-001, FR-002, FR-003, FR-005, FR-006, FR-010: typed, immutable per-request transport configuration
    // Replaces the closure-based RequestConfigurator mechanism from Feature 001 (FR-011)
    // Sendable conformance is synthesised automatically — all stored properties are `let` and Sendable.
    struct Configuration: Sendable {
        
        // MARK: - Stored Properties (FR-002)
        
        /// Request timeout in seconds. Negative values are passed through to the platform without
        /// validation (edge case — behaviour is platform-defined).
        public let timeoutInterval: TimeInterval
        
        /// Cache policy applied to every request using this configuration.
        public let cachePolicy: URLRequest.CachePolicy
        
        /// When `false`, requests are not sent over a cellular network connection.
        public let allowsCellularAccess: Bool
        
        /// When `false`, requests are not sent over expensive network interfaces (e.g., personal hotspot).
        /// Available macOS 10.15+; no availability guard required at macOS 14+.
        public let allowsExpensiveNetworkAccess: Bool
        
        /// When `false`, requests are not sent when Low Data Mode is active.
        /// Available macOS 10.15+; no availability guard required at macOS 14+.
        public let allowsConstrainedNetworkAccess: Bool
        
        /// When `false`, the URL loading system does not send or accept cookies for this request.
        public let httpShouldHandleCookies: Bool
        
        // MARK: - Initialiser (FR-003, FR-009)
        
        /// Creates a `HTTPEngine.Configuration` value.
        ///
        /// All parameters default to the platform-standard `URLRequest` defaults, so calling
        /// `HTTPEngine.Configuration()` produces the same transport settings that `URLRequest` applies
        /// when none of these properties are set explicitly.
        ///
        /// - Parameters:
        ///   - timeoutInterval: Request timeout in seconds. Default: `60.0`.
        ///   - cachePolicy: Cache policy. Default: `.useProtocolCachePolicy`.
        ///   - allowsCellularAccess: Allow cellular network. Default: `true`.
        ///   - allowsExpensiveNetworkAccess: Allow expensive network (e.g., hotspot). Default: `true`.
        ///   - allowsConstrainedNetworkAccess: Allow constrained network (Low Data Mode). Default: `true`.
        ///   - httpShouldHandleCookies: Enable cookie handling. Default: `true`.
        public init(
            timeoutInterval: TimeInterval = 60.0,
            cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
            allowsCellularAccess: Bool = true,
            allowsExpensiveNetworkAccess: Bool = true,
            allowsConstrainedNetworkAccess: Bool = true,
            httpShouldHandleCookies: Bool = true
        ) {
            self.timeoutInterval = timeoutInterval
            self.cachePolicy = cachePolicy
            self.allowsCellularAccess = allowsCellularAccess
            self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
            self.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
            self.httpShouldHandleCookies = httpShouldHandleCookies
        }
        
        // MARK: - Built-in Default Instance (FR-003)
        
        /// The canonical built-in default configuration whose property values match the
        /// platform-standard `URLRequest` defaults.
        ///
        /// This instance is used as the default parameter value on every HTTP method:
        /// `configuration: HTTPEngine.Configuration = .default`
        ///
        /// Using `.default` at a call site is optional — omitting the `configuration:` argument
        /// is equivalent (FR-009, A-08).
        public static let `default` = Configuration()
    }
}
