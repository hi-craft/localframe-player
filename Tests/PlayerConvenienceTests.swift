import XCTest
import UIKit
import LocalLibraryCore
@testable import LocalFrame

@MainActor final class PlayerConvenienceTests: XCTestCase {
    private func playingFixture() async throws -> (PlayerController, URL) {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let media = base.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        let fixture = try XCTUnwrap(Bundle(for: PlaybackTests.self).url(forResource: "first-frame", withExtension: "mp4"))
        try FileManager.default.copyItem(at: fixture, to: media.appendingPathComponent("clip.mp4"))
        let source = FolderSource(name: "Test", bookmark: try media.bookmarkData(options: [.minimalBookmark]), lastKnownPath: media.path)
        let disk = LibraryDiskStore(url: base.appendingPathComponent("index.json"))
        try await disk.save(LibrarySnapshot(sources: [source]), revision: 0)
        let store = LibraryStore(disk: disk)
        for _ in 0..<300 {
            if !store.isLoading && !store.isScanning { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let item = try XCTUnwrap(store.videos.first)
        let player = PlayerController(library: store)
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow })
        player.engine.videoView.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        window.rootViewController?.view.addSubview(player.engine.videoView)
        player.select(item, from: [item])
        for _ in 0..<300 {
            if player.status == .playing && player.isSeekable && player.duration > 0 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(player.status, .playing)
        XCTAssertTrue(player.isSeekable)
        return (player, base)
    }

    private func cleanUp(_ player: PlayerController, _ base: URL) {
        player.close()
        player.engine.videoView.removeFromSuperview()
        try? FileManager.default.removeItem(at: base)
    }

    func testQuickSkipClampsToVideoBoundsAndKeepsPause() async throws {
        let (player, base) = try await playingFixture()
        defer { cleanUp(player, base) }
        player.pause()
        player.skip(by: 10)
        XCTAssertEqual(player.seconds, player.duration)
        XCTAssertEqual(player.status, .paused)
        player.skip(by: -10)
        XCTAssertEqual(player.seconds, 0)
        player.skip(by: .nan)
        XCTAssertEqual(player.seconds, 0)
    }

    func testSleepTimerReplacementPausesPlaybackAndUnlocks() async throws {
        let (player, base) = try await playingFixture()
        defer { cleanUp(player, base) }
        player.setControlsLocked(true)
        player.setSleepTimer(after: 0.05)
        player.setSleepTimer(after: 0.35)
        try await Task.sleep(for: .milliseconds(130))
        XCTAssertNotNil(player.sleepDeadline, "Replacing the timer must cancel the earlier deadline")
        XCTAssertTrue(player.controlsLocked)
        for _ in 0..<100 {
            if player.sleepDeadline == nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNil(player.sleepDeadline)
        XCTAssertEqual(player.status, .paused)
        XCTAssertFalse(player.controlsLocked)
        player.toggle()
        for _ in 0..<100 {
            if player.status == .playing { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(player.status, .playing, "A timer expiry must allow manual resume")
    }

    func testTimerCancellationAndClosingDoNotAffectLaterPlayback() async throws {
        let (player, base) = try await playingFixture()
        defer { cleanUp(player, base) }
        player.setSleepTimer(after: 0.05)
        player.cancelSleepTimer()
        try await Task.sleep(for: .milliseconds(130))
        XCTAssertNil(player.sleepDeadline)
        XCTAssertEqual(player.status, .playing)
        player.setControlsLocked(true)
        player.setAppActive(false)
        XCTAssertFalse(player.controlsLocked)
        XCTAssertEqual(player.status, .paused)
        player.setSleepTimer(after: 60)
        player.close()
        XCTAssertNil(player.sleepDeadline)
        XCTAssertFalse(player.controlsLocked)
        XCTAssertNil(player.current)
    }
}
