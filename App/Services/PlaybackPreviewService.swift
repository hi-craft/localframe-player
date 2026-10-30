import Foundation
import UIKit
import Combine
import LocalLibraryCore

private final class PreviewCancellation: @unchecked Sendable {
    let token = LPFrameCancellation()
}

/// At most one silent background decoder and one pending position, independent
/// of the playback engine. Rapid motion replaces work instead of queuing frames.
@MainActor final class PlaybackPreviewService: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var unavailable = false
    private struct Request {
        let key: String
        let item: VideoItem
        let source: FolderSource
        let seconds: Double
    }
    private let cache = NSCache<NSString, UIImage>()
    private var desiredKey: String?
    private var pending: Request?
    private var task: Task<Void, Never>?
    private var cancellation: PreviewCancellation?

    init() {
        cache.countLimit = 32
        cache.totalCostLimit = 6 * 1024 * 1024
    }

    func request(item: VideoItem, source: FolderSource, seconds: Double, duration: Double) {
        guard seconds.isFinite, duration.isFinite, duration > 0 else { cancel(); return }
        // Half-second buckets bound the cache and avoid decoding every pointer pixel.
        let target = min(max(0, floor(seconds * 2) / 2), max(0, duration - 0.1))
        let key = item.cacheIdentity + ":preview:\(target):" + source.bookmark.base64EncodedString()
        guard desiredKey != key else { return }
        desiredKey = key
        cancellation?.token.cancel()
        pending = nil
        image = cache.object(forKey: key as NSString)
        unavailable = false
        guard image == nil else { return }
        pending = Request(key: key, item: item, source: source, seconds: target)
        pump()
    }

    func cancel() {
        desiredKey = nil
        pending = nil
        cancellation?.token.cancel()
        image = nil
        unavailable = false
    }

    private func pump() {
        guard task == nil, pending != nil else { return }
        task = Task { [weak self] in
            // Wait briefly for the finger / pointer to settle before opening media.
            try? await Task.sleep(for: .milliseconds(90))
            guard let self else { return }
            guard let request = self.pending else { self.task = nil; return }
            self.pending = nil
            let cancellation = PreviewCancellation()
            self.cancellation = cancellation
            let result = await Task.detached(priority: .utility) { () -> UIImage? in
                guard !cancellation.token.isCancelled else { return nil }
                do {
                    let lease = try FolderLease(source: request.source)
                    return try CoordinatedRead.perform(at: lease.url) { _ in
                        let url = try lease.fileURL(for: request.item)
                        return LPFirstFrameDecoder.image(fileURL: url, seconds: request.seconds,
                            cancellation: cancellation.token, maximumSize: CGSize(width: 320, height: 180))
                    }
                } catch { return nil }
            }.value
            if !cancellation.token.isCancelled {
                if let result {
                    self.cache.setObject(result, forKey: request.key as NSString,
                        cost: Int(result.size.width * result.size.height * 4))
                }
                if self.desiredKey == request.key {
                    self.image = result
                    self.unavailable = result == nil
                }
            }
            self.task = nil
            self.cancellation = nil
            self.pump()
        }
    }
}
