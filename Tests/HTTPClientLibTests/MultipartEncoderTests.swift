import Testing
import Foundation
@testable import HTTPClientLib

@Suite("MultipartEncoder") struct MultipartEncoderTests {

    // MARK: - Boundary structure

    @Test func encodedBodyOpensWith_boundary_marker() throws {
        let (body, _) = try MultipartEncoder.encode([FormItem.property(name: "k", value: "v")])
        let bodyString = try #require(String(data: body, encoding: .utf8))
        // Each part opens with "--" + boundary (2 + 4 dashes prefix = "------Boundary-...")
        #expect(bodyString.hasPrefix("------Boundary-"))
    }

    @Test func encodedBodyClosesWith_final_boundary_and_CRLF() throws {
        let (body, _) = try MultipartEncoder.encode([FormItem.property(name: "k", value: "v")])
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.hasSuffix("--\r\n"))
    }

    // MARK: - .property part

    @Test func propertyPartContainsDispositionAndValue() throws {
        let (body, _) = try MultipartEncoder.encode([FormItem.property(name: "field", value: "hello")])
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("Content-Disposition: form-data; name=\"field\""))
        #expect(bodyString.contains("hello"))
    }

    // MARK: - .data part

    @Test func dataPartBodyMatchesInputBytes() throws {
        let input = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let (body, _) = try MultipartEncoder.encode([FormItem.data(name: "blob", body: input)])
        // The encoded body Data should contain the input subsequence
        let inputArray = [UInt8](input)
        let bodyArray = [UInt8](body)
        let found = bodyArray.windows(ofCount: inputArray.count).contains { Array($0) == inputArray }
        #expect(found)
    }

    // MARK: - .file part

    @Test func filePartBodyMatchesFileContentOnDisk() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let fileContent = Data("file-content".utf8)
        try fileContent.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let (body, _) = try MultipartEncoder.encode([FormItem.file(name: "upload", url: tempURL)])
        let bodyArray = [UInt8](body)
        let contentArray = [UInt8](fileContent)
        let found = bodyArray.windows(ofCount: contentArray.count).contains { Array($0) == contentArray }
        #expect(found)
    }

    // MARK: - mimeType override

    @Test func explicitMimeTypeIsUsedInsteadOfDefault() throws {
        let (body, _) = try MultipartEncoder.encode(
            [FormItem.property(name: "p", value: "v", mimeType: "text/csv")]
        )
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("Content-Type: text/csv"))
    }

    // MARK: - Validation

    @Test func emptyItemNameThrows() {
        #expect(throws: HTTPClientError.emptyFormItemName) {
            try MultipartEncoder.encode([FormItem.property(name: "", value: "x")])
        }
    }
}

// MARK: - Sequence window helper (local utility for subsequence search)

private extension Array {
    func windows(ofCount count: Int) -> [[Element]] {
        guard count > 0, self.count >= count else { return [] }
        return (0...(self.count - count)).map { Array(self[$0..<$0 + count]) }
    }
}
