import Foundation

// FR-016, FR-017, FR-019
// Unlabeled associated values avoid redeclaration conflict with factory methods.
// Use factory methods for construction; pattern match positionally on cases.
public enum FormItem: Sendable {
    /// A file from disk.      (name, url, fileName, mimeType)
    case file(String, URL, String?, String?)
    /// In-memory data.        (name, body, fileName, mimeType)
    case data(String, Data, String?, String?)
    /// A plain-text property. (name, value, mimeType)
    case property(String, String, String?)
}

// MARK: - Ergonomic factory methods (preferred call-site form — supplies nil defaults)

extension FormItem {

    public static func file(
        name: String,
        url: URL,
        fileName: String? = nil,
        mimeType: String? = nil
    ) -> FormItem {
        .file(name, url, fileName, mimeType)
    }

    public static func data(
        name: String,
        body: Data,
        fileName: String? = nil,
        mimeType: String? = nil
    ) -> FormItem {
        .data(name, body, fileName, mimeType)
    }

    public static func property(
        name: String,
        value: String,
        mimeType: String? = nil
    ) -> FormItem {
        .property(name, value, mimeType)
    }
}

// MARK: - Internal helpers

extension FormItem {

    /// The form field name for this item. Used for validation and encoding.
    internal var name: String {
        switch self {
        case .file(let name, _, _, _):     return name
        case .data(let name, _, _, _):     return name
        case .property(let name, _, _):    return name
        }
    }
}

