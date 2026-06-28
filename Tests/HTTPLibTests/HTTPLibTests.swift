import Testing

@testable import HTTPLib

@Suite
struct HTTPLibTests {
    @Test
    func versionIsDefined() {
        #expect(HTTPLib.version == "1.0.0")
    }
}
