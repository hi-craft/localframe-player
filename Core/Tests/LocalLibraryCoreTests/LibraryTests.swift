import XCTest
@testable import LocalLibraryCore

final class LibraryTests: XCTestCase {
    private let source = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private func video(_ name: String) -> VideoItem {
        VideoItem(sourceID: source, relativePath: name, byteCount: 400, modifiedAt: .distantPast)
    }

    func testScanOrderIsPreservedAcrossRootRefreshes() {
        let second = UUID()
        let other = VideoItem(sourceID: second, relativePath: "second.mp4", byteCount: 1, modifiedAt: .distantPast)
        let scanned = [video("第10集.mp4"), video("B/第2集.mp4"), video("第1集.mp4")]
        let result = LibraryReadOrder.merging(scanned, sourceID: source, into: [other, video("old.mp4")],
            sourceOrder: [source, second], keepUnseen: false)
        XCTAssertEqual(result, scanned + [other])
        XCTAssertEqual(LibraryReadOrder.merging([other], sourceID: second, into: result,
            sourceOrder: [source, second], keepUnseen: false), result)
    }

    func testPartialScanKeepsUnseenEntriesAfterTheReadSequence() {
        let existing = [video("old.mp4"), video("updated.mp4")]
        let scanned = [video("new.mp4"), video("updated.mp4")]
        XCTAssertEqual(LibraryReadOrder.merging(scanned, sourceID: source, into: existing,
            sourceOrder: [source], keepUnseen: true), scanned + [video("old.mp4")])
    }

    func testFolderBrowsingPreservesOrderAndDirectoryBoundaries() {
        let otherRoot = UUID()
        let items = [video("root.mp4"), video("Season 10/ten.mp4"), video("Season 1/deep/two.mkv"),
                     video("Season 1/one.mp4"), video("Season 1/deep/three.mp4"),
                     VideoItem(sourceID: otherRoot, relativePath: "Season 1/foreign.mp4", byteCount: 1, modifiedAt: .distantPast)]
        let root = FolderListing(sourceID: source, items: items)
        XCTAssertEqual(root.folders.map(\.path), ["Season 10", "Season 1"])
        XCTAssertEqual(root.folders.map(\.videoCount), [1, 3])
        XCTAssertEqual(root.videos.map(\.relativePath), ["root.mp4"])
        let season = FolderListing(sourceID: source, path: "Season 1", items: items)
        XCTAssertEqual(season.folders.map(\.path), ["Season 1/deep"])
        XCTAssertEqual(season.videos.map(\.relativePath), ["Season 1/one.mp4"])
        XCTAssertEqual(season.descendants.map(\.relativePath), ["Season 1/deep/two.mkv", "Season 1/one.mp4", "Season 1/deep/three.mp4"])
        XCTAssertTrue(FolderListing(sourceID: source, path: "missing", items: items).descendants.isEmpty)
    }

    func testAdvancingPlaybackClearsBufferingUntilItActuallyStalls() {
        var activity = PlaybackActivity()
        XCTAssertFalse(activity.hasRecentProgress(at: 1))
        XCTAssertTrue(activity.update(seconds: 0.2, at: 1))
        XCTAssertTrue(activity.hasRecentProgress(at: 1.8))
        XCTAssertFalse(activity.update(seconds: 0.2, at: 2))
        XCTAssertFalse(activity.hasRecentProgress(at: 2.1))
        XCTAssertTrue(activity.update(seconds: 0.4, at: 2.2))
        XCTAssertTrue(activity.hasRecentProgress(at: 2.3))
        activity.reset()
        XCTAssertFalse(activity.hasRecentProgress(at: 2.4))
    }

    func testQueueStopsAtEndAndDoesNotWrap() {
        let items = [video("1.mp4"), video("2.mp4")]
        var queue = PlaybackQueue()
        queue.select(items[0], from: items)
        XCTAssertFalse(queue.hasPrevious)
        XCTAssertEqual(queue.advance(), items[1])
        XCTAssertNil(queue.advance())
        XCTAssertEqual(queue.current, items[1])
        XCTAssertEqual(queue.previous(), items[0])
    }

    func testTraversalAndRemotePathsAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for path in ["../outside.mp4", "/outside.mp4", "a/../b.mp4", "a//b.mp4", "a/list.m3u8"] {
            XCTAssertThrowsError(try LocalMediaPath.resolve(path, under: root))
        }
        XCTAssertThrowsError(try LocalMediaPath.resolve("a.mp4", under: URL(string: "https://example.com")!))
        XCTAssertEqual(try LocalMediaPath.resolve("剧集/1.MP4", under: root).lastPathComponent, "1.MP4")
    }

    func testRecursiveScanSkipsHiddenFilesAndSymlinks() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: root.appendingPathComponent("season/deep"), withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        for name in ["1.MP4", "season/2.mkv", "season/deep/3.mov", ".hidden.mp4", "note.txt", "stream.m3u8"] {
            try Data([0]).write(to: root.appendingPathComponent(name))
        }
        try manager.createSymbolicLink(at: root.appendingPathComponent("shortcut.mp4"),
                                       withDestinationURL: root.appendingPathComponent("1.MP4"))
        try manager.createSymbolicLink(at: root.appendingPathComponent("season/deep/cycle"), withDestinationURL: root)
        var progress: [DirectoryScanProgress] = []
        let result = try DirectoryScanner.scan(sourceID: source, root: root, onProgress: { progress.append($0) })
        XCTAssertEqual(Set(result.videos.map(\.relativePath)), ["1.MP4", "season/2.mkv", "season/deep/3.mov"],
                       "root=\(root.path), canonical=\(LocalMediaPath.directoryPath(root)), errors=\(result.unreadableCount), cloud=\(result.excludedCloudCount)")
        XCTAssertThrowsError(try LocalMediaPath.resolve("shortcut.mp4", under: root))
        XCTAssertEqual(progress.first?.inspectedItemCount, 0)
        XCTAssertEqual(progress.last?.videoCount, result.videos.count)
        XCTAssertEqual(progress.last?.inspectedItemCount, result.inspectedItemCount)
        XCTAssertGreaterThan(result.inspectedItemCount, result.videos.count)
        XCTAssertTrue(zip(progress, progress.dropFirst()).allSatisfy {
            $0.inspectedItemCount <= $1.inspectedItemCount && $0.videoCount <= $1.videoCount
        })
    }

    func testFailedOrCancelledScansDoNotReturnEmptySuccess() {
        XCTAssertThrowsError(try DirectoryScanner.scan(sourceID: source,
            root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        XCTAssertThrowsError(try DirectoryScanner.scan(sourceID: source,
            root: FileManager.default.temporaryDirectory, isCancelled: { true }))
    }

    func testCacheEvictsLeastRecentlyUsedUntilWithinLimit() {
        let entries = [CacheEntry(key: "old", bytes: 30, accessedAt: .distantPast),
                       CacheEntry(key: "new", bytes: 50, accessedAt: .distantFuture)]
        XCTAssertEqual(CacheBudget.victims(entries: entries, limit: 60), ["old"])
        XCTAssertEqual(CacheBudget.victims(entries: entries, limit: 0), ["old", "new"])
    }

    func testPersistedSnapshotContainsNoPlaybackState() throws {
        let snapshot = LibrarySnapshot(videos: [video("1.mp4")])
        let data = try JSONEncoder().encode(snapshot)
        let roundTrip = try JSONDecoder().decode(LibrarySnapshot.self, from: data)
        XCTAssertEqual(roundTrip.videos, snapshot.videos)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schemaVersion", "sources", "videos"])
    }
}
