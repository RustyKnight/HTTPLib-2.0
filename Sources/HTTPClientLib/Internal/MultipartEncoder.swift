import Foundation

// FR-018, FR-019, research Decision 5
// RFC 2046 multipart/form-data encoder. Internal — not part of the public API surface.
internal enum MultipartEncoder {

    /// Encodes an array of `FormItem`s as RFC 2046 multipart/form-data.
    ///
    /// - Returns: A tuple of the encoded body `Data` and the complete `Content-Type` header value
    ///            (e.g. `"multipart/form-data; boundary=----Boundary-XXXX"`).
    /// - Throws: `HTTPClientError.emptyFormItemName` if any item has an empty `name`.
    ///           `HTTPClientError.fileReadFailed` if a `.file` item cannot be read.
    static func encode(_ items: [FormItem]) throws -> (body: Data, contentType: String) {
        // A-09: boundary is UUID-derived, unique per call
        let boundary = "----Boundary-\(UUID().uuidString)"

        var bodyData = Data()

        func append(_ string: String) {
            if let d = string.data(using: .utf8) {
                bodyData.append(d)
            }
        }

        for item in items {
            // Defence-in-depth guard — HTTPClient validates first (FR-021)
            guard !item.name.isEmpty else {
                throw HTTPClientError.emptyFormItemName
            }

            // Opening boundary (RFC 2046 §4.1: CRLF line endings mandatory)
            append("--\(boundary)\r\n")

            switch item {

            case .file(let name, let url, let fileName, let mimeType):
                // Content-Disposition header
                var disposition = "Content-Disposition: form-data; name=\"\(name)\""
                if let fn = fileName { disposition += "; filename=\"\(fn)\"" }
                append(disposition + "\r\n")

                // Content-Type header (default: application/octet-stream — FR-019)
                append("Content-Type: \(mimeType ?? "application/octet-stream")\r\n")
                append("\r\n")

                // Part body — read file from disk
                do {
                    let fileData = try Data(contentsOf: url)
                    bodyData.append(fileData)
                } catch {
                    throw HTTPClientError.fileReadFailed(url: url, underlying: error)
                }
                append("\r\n")

            case .data(let name, let partBody, let fileName, let mimeType):
                // Content-Disposition header
                var disposition = "Content-Disposition: form-data; name=\"\(name)\""
                if let fn = fileName { disposition += "; filename=\"\(fn)\"" }
                append(disposition + "\r\n")

                // Content-Type header (default: application/octet-stream — FR-019)
                append("Content-Type: \(mimeType ?? "application/octet-stream")\r\n")
                append("\r\n")

                // Part body — raw bytes verbatim
                bodyData.append(partBody)
                append("\r\n")

            case .property(let name, let value, let mimeType):
                // Content-Disposition header
                append("Content-Disposition: form-data; name=\"\(name)\"\r\n")

                // Content-Type header (default: text/plain — FR-019)
                append("Content-Type: \(mimeType ?? "text/plain")\r\n")
                append("\r\n")

                // Part body — UTF-8 encoded string value
                if let valueData = value.data(using: .utf8) {
                    bodyData.append(valueData)
                }
                append("\r\n")
            }
        }

        // Final boundary (RFC 2046: terminates with "--")
        append("--\(boundary)--\r\n")

        let contentType = "multipart/form-data; boundary=\(boundary)"
        return (body: bodyData, contentType: contentType)
    }
}
