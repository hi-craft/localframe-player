import XCTest
import UIKit
import LocalLibraryCore
@testable import LocalFrame

@MainActor final class PlaybackTimelineTests: XCTestCase {
    func testPointerPreviewClampsAndNeverChangesPlaybackValue() {
        let slider = CinemaSlider(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        slider.maximumValue = 45
        slider.value = 8
        var positions: [TimelinePreviewPosition?] = []
        slider.previewChanged = { positions.append($0) }
        slider.preview(at: CGPoint(x: -50, y: 22))
        XCTAssertEqual(positions.last??.seconds, 0)
        slider.preview(at: CGPoint(x: 150, y: 22))
        XCTAssertEqual(positions.last??.seconds ?? -1, 22.5, accuracy: 0.1)
        slider.preview(at: CGPoint(x: 400, y: 22))
        XCTAssertEqual(positions.last??.seconds, 45)
        XCTAssertEqual(slider.value, 8, "Hovering must not seek")
        slider.preview(at: nil)
        XCTAssertNil(positions.last!)
        slider.isEnabled = false
        slider.preview(at: CGPoint(x: 150, y: 22))
        XCTAssertNil(positions.last!)
    }

    func testPreviewCancellationAndLatestVideoWins() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try XCTUnwrap(Bundle(for: PlaybackTests.self).url(forResource: "first-frame", withExtension: "mp4"))
        try FileManager.default.copyItem(at: fixture, to: directory.appendingPathComponent("clip.mp4"))
        let source = FolderSource(name: "Preview", bookmark: try directory.bookmarkData(options: [.minimalBookmark]), lastKnownPath: directory.path)
        let item = VideoItem(sourceID: source.id, relativePath: "clip.mp4", byteCount: 1, modifiedAt: .now)
        let previews = PlaybackPreviewService()
        previews.request(item: item, source: source, seconds: 0, duration: 2)
        try await Task.sleep(for: .milliseconds(150))
        // Replace an in-flight request, then verify the newest frame wins.
        previews.request(item: item, source: source, seconds: 1.5, duration: 2)
        for _ in 0..<150 {
            if previews.image != nil || previews.unavailable { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let image = try XCTUnwrap(previews.image?.cgImage)
        var rgba: [UInt8] = [0, 0, 0, 0]
        rgba.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        XCTAssertGreaterThan(Int(rgba[2]), 180)
        XCTAssertLessThan(Int(rgba[0]), 70)
        previews.request(item: item, source: source, seconds: 0, duration: 2)
        previews.cancel()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(previews.image, "A cancelled request must not republish a stale frame")
        XCTAssertFalse(previews.unavailable)
    }
}
