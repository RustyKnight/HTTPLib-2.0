import Foundation
import SupportLib

/// Internal delegate for tracking upload and download progress during HTTP operations.
///
/// This delegate monitors `URLSession` task progress and updates child trackers
/// for request (upload) and response (download) phases.
final class HTTPProgressDelegate: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    let requestProgressTracker: ProgressTracker?
    let responseProgressTracker: ProgressTracker?

    init(
        requestProgressTracker: ProgressTracker? = nil,
        responseProgressTracker: ProgressTracker? = nil
    ) {
        self.requestProgressTracker = requestProgressTracker
        self.responseProgressTracker = responseProgressTracker
        super.init()
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard let tracker = requestProgressTracker, totalBytesExpectedToSend > 0 else { return }
        Task {
            await tracker.update(value: Double(totalBytesSent), total: Double(totalBytesExpectedToSend))
        }
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let tracker = responseProgressTracker, totalBytesExpectedToWrite > 0 else { return }
        Task {
            await tracker.update(value: Double(totalBytesWritten), total: Double(totalBytesExpectedToWrite))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Not used with data(for:delegate:) — data task completion is handled differently
    }
}
