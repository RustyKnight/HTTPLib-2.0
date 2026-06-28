import Testing
import Foundation
@testable import HTTPLib

@Suite("HTTPEngine Cancellation") struct HTTPEngineCancellationTests {

    private let url = URL(string: "https://example.com")!

    private func makeEngine() -> (HTTPEngine, MockURLProtocol.MockContext) {
        let (session, mock) = MockURLProtocol.makePair()
        return (HTTPEngine(session: session), mock)
    }

    // FR-007, research Decision 8: pre-flight cancellation throws CancellationError, not networkError
    @Test func preFlightCancellationThrowsCancellationErrorNotNetworkError() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        let task = Task { try await engine.get(url) }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // PASS — correct error type
        } catch {
            Issue.record("Caught \(error) instead of CancellationError")
        }
    }

    // Explicitly verifies the error is never wrapped in HTTPEngineError
    @Test func cancellationErrorIsNeverWrappedInHTTPEngineError() async throws {
        let (engine, mock) = makeEngine()
        mock.stub = (MockURLProtocol.makeResponse(url: url, statusCode: 200), Data())

        let task = Task { try await engine.get(url) }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // PASS — raw CancellationError, not wrapped
        } catch let e as HTTPEngineError {
            Issue.record("CancellationError was incorrectly wrapped in HTTPEngineError: \(e)")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
