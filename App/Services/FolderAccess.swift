import Foundation
import LocalLibraryCore

/// Keep this object alive for the complete scan, decode or playback operation.
final class FolderLease: @unchecked Sendable {
    let url: URL
    let refreshedBookmark: Data?
    private let scoped: Bool

    init(source: FolderSource) throws {
        var stale = false
        let resolved = try URL(resolvingBookmarkData: source.bookmark,
                               options: [.withoutUI], relativeTo: nil,
                               bookmarkDataIsStale: &stale)
        guard resolved.isFileURL else { throw LibraryFailure.remoteSource }
        let started = resolved.startAccessingSecurityScopedResource()
        let ownContainer = resolved.standardizedFileURL.path.hasPrefix(NSHomeDirectory() + "/")
        guard started || ownContainer else { throw LibraryFailure.permissionDenied }
        do {
            let values = try resolved.resourceValues(forKeys: [.isUbiquitousItemKey, .volumeIsLocalKey])
            guard values.isUbiquitousItem != true, values.volumeIsLocal != false else {
                throw LibraryFailure.remoteSource
            }
        } catch {
            if started { resolved.stopAccessingSecurityScopedResource() }
            throw error
        }
        url = resolved
        scoped = started
        refreshedBookmark = stale ? try? resolved.bookmarkData(options: [.minimalBookmark],
                                        includingResourceValuesForKeys: nil, relativeTo: nil) : nil
    }

    deinit { if scoped { url.stopAccessingSecurityScopedResource() } }

    func fileURL(for item: VideoItem) throws -> URL {
        let file = try LocalMediaPath.resolve(item.relativePath, under: url)
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isUbiquitousItemKey])
        guard values.isUbiquitousItem != true else { throw LibraryFailure.remoteSource }
        guard values.isRegularFile == true,
              FileManager.default.isReadableFile(atPath: file.path) else { throw LibraryFailure.unavailable }
        return file
    }
}

enum CoordinatedRead {
    static func perform<T>(at url: URL, _ read: @escaping (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordinationError) { file in
            result = Result { try read(file) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw LibraryFailure.unavailable }
        return try result.get()
    }
}

actor LibraryDiskStore {
    private var latestRevision = -1
    private let url: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = base.appendingPathComponent("LocalFrame/library-v1.json")
    }

    func load() throws -> LibrarySnapshot {
        guard FileManager.default.fileExists(atPath: url.path) else { return LibrarySnapshot() }
        let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: url))
        guard snapshot.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
        return snapshot
    }

    func save(_ snapshot: LibrarySnapshot, revision: Int) throws {
        guard revision >= latestRevision else { return }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(excluded)
        try JSONEncoder().encode(snapshot).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        latestRevision = revision
    }
}
