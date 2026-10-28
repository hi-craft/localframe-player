import Foundation
import CryptoKit
import LocalLibraryCore

actor ThumbnailDiskCache {
    static let limit: Int64 = 64 * 1024 * 1024
    private let directory: URL
    private var entries: [String: CacheEntry] = [:]
    private var prepared = false

    init() {
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalFrame/Thumbnails", isDirectory: true)
    }

    nonisolated static func key(for item: VideoItem) -> String {
        SHA256.hash(data: Data(item.cacheIdentity.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func prepare() throws {
        guard !prepared else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(values)
        for url in try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) where url.pathExtension == "jpg" {
            let resource = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let key = url.deletingPathExtension().lastPathComponent
            entries[key] = CacheEntry(key: key, bytes: Int64(resource?.fileSize ?? 0),
                                      accessedAt: resource?.contentModificationDate ?? .distantPast)
        }
        prepared = true
        prune()
    }

    func load(_ key: String) -> Data? {
        do {
            try prepare()
            let url = directory.appendingPathComponent(key + ".jpg")
            guard let entry = entries[key] else { return nil }
            let data = try Data(contentsOf: url)
            let now = Date()
            entries[key] = CacheEntry(key: key, bytes: entry.bytes, accessedAt: now)
            try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
            return data
        } catch { entries[key] = nil; return nil }
    }

    func save(_ data: Data, key: String) {
        do {
            try prepare()
            guard Int64(data.count) <= Self.limit else { return }
            try data.write(to: directory.appendingPathComponent(key + ".jpg"), options: .atomic)
            entries[key] = CacheEntry(key: key, bytes: Int64(data.count), accessedAt: Date())
            prune()
        } catch { /* A cache write never prevents playback. */ }
    }

    func removeAll() {
        // Delete only files in the fixed cache directory, never a selected source directory.
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for url in files where url.pathExtension == "jpg" { try? FileManager.default.removeItem(at: url) }
        }
        entries.removeAll()
        prepared = false
    }

    private func prune() {
        for key in CacheBudget.victims(entries: Array(entries.values), limit: Self.limit) {
            do {
                try FileManager.default.removeItem(at: directory.appendingPathComponent(key + ".jpg"))
                entries[key] = nil
            } catch { /* Keep failed removals accounted for in the budget. */ }
        }
    }
}
