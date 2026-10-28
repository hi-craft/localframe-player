import Foundation

public struct DirectoryScan: Sendable {
    public var videos: [VideoItem]
    public var unreadableCount: Int
    public var excludedCloudCount: Int
}

public enum DirectoryScanner {
    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
        .fileSizeKey, .contentModificationDateKey, .isUbiquitousItemKey
    ]

    /// Enumerates metadata only. Does not parse videos or request cloud downloads.
    public static func scan(sourceID: UUID, root: URL,
                            isCancelled: () -> Bool = { false }) throws -> DirectoryScan {
        guard root.isFileURL else { throw LibraryFailure.remoteSource }
        let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isUbiquitousItemKey, .volumeIsLocalKey])
        guard rootValues.isUbiquitousItem != true, rootValues.volumeIsLocal != false else {
            throw LibraryFailure.remoteSource
        }
        guard rootValues.isDirectory == true else { throw LibraryFailure.unavailable }
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        var failures = 0
        var cloudFiles = 0
        guard let enumerator = FileManager.default.enumerator(
            at: base, includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in failures += 1; return !isCancelled() }
        ) else { throw LibraryFailure.unavailable }
        var items: [VideoItem] = []
        for case let file as URL in enumerator {
            if isCancelled() { throw CancellationError() }
            do {
                let values = try file.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                if values.isUbiquitousItem == true {
                    enumerator.skipDescendants()
                    cloudFiles += 1
                    continue
                }
                guard values.isRegularFile == true,
                      LocalMediaPath.videoExtensions.contains(file.pathExtension.lowercased()),
                      file.path.hasPrefix(base.path + "/") else { continue }
                let relative = String(file.path.dropFirst(base.path.count + 1))
                items.append(VideoItem(sourceID: sourceID, relativePath: relative,
                                       byteCount: Int64(values.fileSize ?? 0),
                                       modifiedAt: values.contentModificationDate ?? .distantPast))
            } catch { failures += 1 }
        }
        // An unplugged device must never turn a cached library into an empty successful scan.
        guard FileManager.default.fileExists(atPath: root.path) else { throw LibraryFailure.unavailable }
        return DirectoryScan(videos: items, unreadableCount: failures, excludedCloudCount: cloudFiles)
    }
}

public struct CacheEntry: Sendable {
    public let key: String
    public let bytes: Int64
    public let accessedAt: Date

    public init(key: String, bytes: Int64, accessedAt: Date) {
        self.key = key; self.bytes = bytes; self.accessedAt = accessedAt
    }
}

public enum CacheBudget {
    public static func victims(entries: [CacheEntry], limit: Int64) -> [String] {
        var bytes = entries.reduce(Int64(0)) { $0 + max(0, $1.bytes) }
        var removed: [String] = []
        for entry in entries.sorted(by: {
            $0.accessedAt == $1.accessedAt ? $0.key < $1.key : $0.accessedAt < $1.accessedAt
        }) where bytes > max(0, limit) {
            removed.append(entry.key)
            bytes -= max(0, entry.bytes)
        }
        return removed
    }
}
