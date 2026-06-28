import Foundation

// FR-006: All failure paths surface as typed throws
public enum HTTPEngineError: Error {
    /// A `.json` body failed `JSONEncoder.encode`. Contains the underlying encoder error.
    case jsonEncodingFailed(any Error)
    /// A `.file` form item URL could not be read. Contains the file URL and underlying error.
    case fileReadFailed(url: URL, underlying: any Error)
    /// The `formItems` array supplied to a multipart POST was empty.
    case emptyFormItems
    /// A `FormItem.name` was the empty string.
    case emptyFormItemName
    /// URLSession threw a network-level error (typically `URLError`).
    case networkError(any Error)
}

// `any Error` payloads are consumed once and not shared across concurrency boundaries
// (research.md Decision 3 pattern). CancellationError is deliberately absent —
// it propagates directly per FR-007 and research Decision 8.
extension HTTPEngineError: @unchecked Sendable {}

// Equatable conformance: cases are compared by type; `any Error` payloads are not compared
// because `Error` is not itself Equatable. This is sufficient for test assertions.
extension HTTPEngineError: Equatable {
    public static func == (lhs: HTTPEngineError, rhs: HTTPEngineError) -> Bool {
        switch (lhs, rhs) {
        case (.jsonEncodingFailed, .jsonEncodingFailed):                   return true
        case (.fileReadFailed(let lURL, _), .fileReadFailed(let rURL, _)): return lURL == rURL
        case (.emptyFormItems, .emptyFormItems):                           return true
        case (.emptyFormItemName, .emptyFormItemName):                     return true
        case (.networkError, .networkError):                               return true
        default:                                                           return false
        }
    }
}

