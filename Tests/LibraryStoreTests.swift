import XCTest
import LocalLibraryCore
@testable import LocalFrame

final class LibraryStoreTests: XCTestCase {
    @MainActor func testRebuildingRefreshReplacesConnectedIndexAndKeepsOfflineIndex() async throws {
        let manager = FileManager.default
        let base = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = base.appendingPathComponent("connected")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: base) }
        try Data([1]).write(to: root.appendingPathComponent("old.mp4"))
        let connected = FolderSource(name: "Connected", bookmark: try root.bookmarkData(options: [.minimalBookmark]), lastKnownPath: root.path)
        let offline = FolderSource(name: "Offline", bookmark: Data(), lastKnownPath: base.appendingPathComponent("offline").path)
        let kept = VideoItem(sourceID: offline.id, relativePath: "kept.mp4", byteCount: 7, modifiedAt: .distantPast)
        let disk = LibraryDiskStore(url: base.appendingPathComponent("index/library.json"))
        try await disk.save(LibrarySnapshot(sources: [connected, offline], videos: [kept]), revision: 0)
        let store = LibraryStore(disk: disk)
        for _ in 0..<200 where store.isLoading { try await Task.sleep(for: .milliseconds(20)) }
        await store.refreshAndWait()
        XCTAssertTrue(store.videos.contains { $0.relativePath == "old.mp4" })

        try manager.removeItem(at: root.appendingPathComponent("old.mp4"))
        try Data([2, 3]).write(to: root.appendingPathComponent("new.mp4"))
        // An old offline status must not prevent a newly reconnected root being read.
        store.markUnavailable(connected.id, reason: "Previously disconnected")
        store.refresh()
        await store.refreshAndWait(rebuilding: true)
        XCTAssertEqual(store.videos.filter { $0.sourceID == connected.id }.map(\.relativePath), ["new.mp4"])
        XCTAssertEqual(store.videos.filter { $0.sourceID == offline.id }, [kept])
        XCTAssertEqual(store.statuses[connected.id], .ready)
        XCTAssertFalse(store.isScanning)
        XCTAssertTrue(store.readingProgress.rebuilding)
        XCTAssertEqual(store.readingProgress.completedSources, 2)
        XCTAssertEqual(store.readingProgress.totalSources, 2)
        XCTAssertEqual(store.readingProgress.offlineSources, 1)
        XCTAssertEqual(store.readingProgress.foundVideos, 1)
        XCTAssertEqual(store.readingProgress.inspectedItems, 1)

        // A connected but now empty root must clear stale entries, without deleting its files.
        try manager.removeItem(at: root.appendingPathComponent("new.mp4"))
        try Data([9]).write(to: root.appendingPathComponent("note.txt"))
        await store.refreshAndWait(rebuilding: true)
        XCTAssertEqual(store.videos, [kept])
        XCTAssertTrue(manager.fileExists(atPath: root.appendingPathComponent("note.txt").path))
    }

    @MainActor func testDisconnectedRootKeepsIndexAndReauthorizationKeepsIdentity() async throws {
        let manager = FileManager.default
        let base = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = base.appendingPathComponent("old")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: base) }
        let source = FolderSource(name: "External", bookmark: try root.bookmarkData(options: [.minimalBookmark]), lastKnownPath: root.path)
        let indexed = VideoItem(sourceID: source.id, relativePath: "season/kept.mp4", byteCount: 42, modifiedAt: .distantPast)
        let disk = LibraryDiskStore(url: base.appendingPathComponent("index/library.json"))
        try await disk.save(LibrarySnapshot(sources: [source], videos: [indexed]), revision: 0)
        try manager.removeItem(at: root)
        let store = LibraryStore(disk: disk)
        for _ in 0..<200 where store.isLoading { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(store.isLoading)
        await store.refreshAndWait()
        XCTAssertEqual(store.videos, [indexed])
        XCTAssertEqual(store.sources.map(\.id), [source.id])
        XCTAssertFalse(store.isAvailable(indexed))
        if case .offline = store.statuses[source.id] {} else { XCTFail("Disconnected source must be offline") }

        let replacement = base.appendingPathComponent("reconnected")
        try manager.createDirectory(at: replacement, withIntermediateDirectories: true)
        try Data([1]).write(to: replacement.appendingPathComponent("new.mp4"))
        store.reauthorize(source.id, with: [replacement])
        for _ in 0..<200 {
            if store.statuses[source.id]?.isAvailable == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(store.sources.map(\.id), [source.id])
        XCTAssertEqual(store.videos.map(\.relativePath), ["new.mp4"])
        XCTAssertEqual(store.statuses[source.id], .ready)
    }
}
