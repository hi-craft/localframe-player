import XCTest
@testable import LocalLibraryCore

final class LibraryTests: XCTestCase {
    private let source = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private func video(_ name: String) -> VideoItem {
        VideoItem(sourceID: source, relativePath: name, byteCount: 400, modifiedAt: .distantPast)
    }

    func testNaturalSortingAndDuplicateNameTieBreak() {
        let names = VideoItem.sorted([video("第10集.mp4"), video("B/第2集.mp4"),
                                      video("第1集.mp4"), video("A/第2集.mp4")]).map(\.relativePath)
        XCTAssertEqual(names, ["第1集.mp4", "A/第2集.mp4", "B/第2集.mp4", "第10集.mp4"])
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
        try manager.createDirectory(at: root.appendingPathComponent("season"), withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        for name in ["1.MP4", "season/2.mkv", ".hidden.mp4", "note.txt", "stream.m3u8"] {
            try Data([0]).write(to: root.appendingPathComponent(name))
        }
        try manager.createSymbolicLink(at: root.appendingPathComponent("shortcut.mp4"),
                                       withDestinationURL: root.appendingPathComponent("1.MP4"))
        let result = try DirectoryScanner.scan(sourceID: source, root: root)
        XCTAssertEqual(Set(result.videos.map(\.relativePath)), ["1.MP4", "season/2.mkv"])
        XCTAssertThrowsError(try LocalMediaPath.resolve("shortcut.mp4", under: root))
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
