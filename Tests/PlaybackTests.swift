import XCTest
import UIKit

/// Exercises the same libVLC bridge used by the app with generated, offline test media.
final class PlaybackTests: XCTestCase {
    private func fixture(_ extensionName: String) throws -> URL {
        try XCTUnwrap(Bundle(for: PlaybackTests.self).url(forResource: "first-frame", withExtension: extensionName))
    }

    func testMP4CoverIsTheOpeningRedFrame() async throws {
        try await verifyFirstFrame("mp4")
    }

    func testMKVCoverIsTheOpeningRedFrame() async throws {
        try await verifyFirstFrame("mkv")
    }

    private func verifyFirstFrame(_ extensionName: String) async throws {
        let url = try fixture(extensionName)
        let result = await Task.detached {
            LPFirstFrameDecoder.image(fileURL: url, cancellation: LPFrameCancellation())
        }.value
        let image = try XCTUnwrap(result?.cgImage)
        XCTAssertLessThanOrEqual(image.width, 320)
        XCTAssertLessThanOrEqual(image.height, 180)
        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        try pixel.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: colorSpace, bitmapInfo: info))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        // The second half is blue: this also rejects a thumbnail taken from the middle/end.
        XCTAssertGreaterThan(Int(pixel[0]), 180, "Opening frame must be red")
        XCTAssertLessThan(Int(pixel[1]), 70)
        XCTAssertLessThan(Int(pixel[2]), 70)
    }

    func testCancelledAndRemoteThumbnailRequestsAreRejected() async throws {
        let localURL = try fixture("mp4")
        let results = await Task.detached { () -> [Bool] in
            let cancellation = LPFrameCancellation()
            cancellation.cancel()
            let cancelled = LPFirstFrameDecoder.image(fileURL: localURL, cancellation: cancellation)
            let remote = LPFirstFrameDecoder.image(fileURL: URL(string: "https://example.invalid/video.mp4")!,
                                                   cancellation: LPFrameCancellation())
            return [cancelled == nil, remote == nil]
        }.value
        XCTAssertEqual(results, [true, true])
    }

    @MainActor func testPlaybackProducesProgressAndDuration() async throws {
        let url = try fixture("mp4")
        let bridge = LPPlaybackBridge()
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow })
        bridge.videoView.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        try XCTUnwrap(window.rootViewController?.view).addSubview(bridge.videoView)
        let playing = expectation(description: "VLC enters playing state")
        let progressing = expectation(description: "VLC reports playable local media progress")
        var sawPlaying = false
        var sawProgress = false
        bridge.stateChanged = { state in
            if state == "playing" && !sawPlaying { sawPlaying = true; playing.fulfill() }
        }
        bridge.progressChanged = { seconds, duration, seekable in
            if seconds >= 0.2 && duration >= 1.5 && seekable && !sawProgress {
                sawProgress = true
                progressing.fulfill()
            }
        }
        bridge.open(fileURL: url)
        await fulfillment(of: [playing, progressing], timeout: 15)
        await withCheckedContinuation { continuation in bridge.stop { continuation.resume() } }
        bridge.videoView.removeFromSuperview()
    }
}
