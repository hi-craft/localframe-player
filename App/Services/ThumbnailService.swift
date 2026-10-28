import Foundation
import UIKit
import Combine
import LocalLibraryCore

private final class DecodeCancellation: @unchecked Sendable {
    let token = LPFrameCancellation()
}

@MainActor final class ThumbnailService: ObservableObject {
    @Published private(set) var epoch = 0
    private struct Request {
        let item: VideoItem
        let source: FolderSource
        let continuation: CheckedContinuation<UIImage?, Never>
    }
    private let memory = NSCache<NSString, UIImage>()
    private let disk = ThumbnailDiskCache()
    private var pending: [UUID] = []
    private var requests: [UUID: Request] = [:]
    private var activeID: UUID?
    private var activeTask: Task<Void, Never>?
    private var activeCancellation: DecodeCancellation?
    private var clearing = false
    private var memoryObserver: NSObjectProtocol?

    init() {
        memory.totalCostLimit = 8 * 1024 * 1024
        memory.countLimit = 80
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.memory.removeAllObjects() }
        }
    }

    deinit { if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) } }

    func image(for item: VideoItem, source: FolderSource) async -> UIImage? {
        let key = ThumbnailDiskCache.key(for: item)
        if let image = memory.object(forKey: key as NSString) { return image }
        let id = UUID()
        return await withTaskCancellationHandler(operation: {
            guard !Task.isCancelled else { return nil }
            return await withCheckedContinuation { continuation in
                requests[id] = Request(item: item, source: source, continuation: continuation)
                pending.append(id)
                pump()
            }
        }, onCancel: { Task { @MainActor [weak self] in self?.cancel(id) } })
    }

    private func cancel(_ id: UUID) {
        if activeID == id {
            activeCancellation?.token.cancel()
            activeTask?.cancel()
        } else if let request = requests.removeValue(forKey: id) {
            pending.removeAll { $0 == id }
            request.continuation.resume(returning: nil)
        }
    }

    private func pump() {
        guard activeID == nil, !clearing else { return }
        while !pending.isEmpty {
            let id = pending.removeFirst()
            guard let request = requests[id] else { continue }
            activeID = id
            let cancellation = DecodeCancellation()
            activeCancellation = cancellation
            let key = ThumbnailDiskCache.key(for: request.item)
            activeTask = Task {
                var image: UIImage?
                if let data = await disk.load(key), !Task.isCancelled { image = UIImage(data: data) }
                if image == nil && !Task.isCancelled {
                    let worker = Task.detached(priority: .utility) { () -> UIImage? in
                        do {
                            let lease = try FolderLease(source: request.source)
                            return try CoordinatedRead.perform(at: lease.url) { _ in
                                let url = try lease.fileURL(for: request.item)
                                return LPFirstFrameDecoder.image(fileURL: url, cancellation: cancellation.token)
                            }
                        } catch { return nil }
                    }
                    image = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: {
                        cancellation.token.cancel()
                        worker.cancel()
                    })
                    if let image, !Task.isCancelled, let data = image.jpegData(compressionQuality: 0.72) {
                        await disk.save(data, key: key)
                    }
                }
                if Task.isCancelled { image = nil }
                if let image {
                    memory.setObject(image, forKey: key as NSString,
                                     cost: Int(image.size.width * image.size.height * 4))
                }
                requests.removeValue(forKey: id)?.continuation.resume(returning: image)
                activeID = nil
                activeTask = nil
                activeCancellation = nil
                pump()
            }
            return
        }
    }

    func clear() async {
        clearing = true
        activeCancellation?.token.cancel()
        activeTask?.cancel()
        for id in pending {
            requests.removeValue(forKey: id)?.continuation.resume(returning: nil)
        }
        pending.removeAll()
        await activeTask?.value
        await disk.removeAll()
        memory.removeAllObjects()
        epoch += 1
        clearing = false
        pump()
    }
}
