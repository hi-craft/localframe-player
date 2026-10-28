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
                            isCancelled: @escaping () -> Bool = { false }) throws -> DirectoryScan {
        if isCancelled() { throw CancellationError() }
        guard root.isFileURL else { throw LibraryFailure.remoteSource }
        let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isUbiquitousItemKey, .volumeIsLocalKey])
        guard rootValues.isUbiquitousItem != true, rootValues.volumeIsLocal != false else {
            throw LibraryFailure.remoteSource
        }
        guard rootValues.isDirectory == true else { throw LibraryFailure.unavailable }
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        let basePath = LocalMediaPath.directoryPath(base)
        let prefix = basePath == "/" ? "/" : basePath + "/"
        var failures = 0
        var cloudFiles = 0
        var items: [VideoItem] = []
        var pending = [base]
        var visited: Set<String> = []
        while let directory = pending.popLast() {
            if isCancelled() { throw CancellationError() }
            let directoryPath = LocalMediaPath.directoryPath(directory)
            guard directoryPath == basePath || directoryPath.hasPrefix(prefix),
                  visited.insert(directoryPath).inserted else { continue }
            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(at: directory,
                    includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
            } catch {
                if directoryPath == basePath { throw error }
                failures += 1
                continue
            }
            for file in children {
                if isCancelled() { throw CancellationError() }
                do {
                    let values = try file.resourceValues(forKeys: keys)
                    guard values.isSymbolicLink != true else { continue }
                    if values.isUbiquitousItem == true { cloudFiles += 1; continue }
                    if values.isDirectory == true { pending.append(file); continue }
                    guard values.isRegularFile == true,
                          LocalMediaPath.videoExtensions.contains(file.pathExtension.lowercased()) else { continue }
                    let filePath = file.standardizedFileURL.resolvingSymlinksInPath().path
                    guard filePath.hasPrefix(prefix) else { continue }
                    let relative = String(filePath.dropFirst(prefix.count))
                    items.append(VideoItem(sourceID: sourceID, relativePath: relative,
                                           byteCount: Int64(values.fileSize ?? 0),
                                           modifiedAt: values.contentModificationDate ?? .distantPast))
                } catch { failures += 1 }
            }
        }
        if isCancelled() { throw CancellationError() }
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
