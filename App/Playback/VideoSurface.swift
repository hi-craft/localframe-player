import SwiftUI
import UIKit
import AVFoundation
import MediaPlayer

@MainActor final class SystemVolume: ObservableObject {
    weak var slider: UISlider?
    var value: Float { AVAudioSession.sharedInstance().outputVolume }
    func set(_ value: Float) {
        guard let slider else { return }
        slider.setValue(min(1, max(0, value)), animated: false)
        slider.sendActions(for: .touchUpInside)
    }
}

private final class AttachedVolumeView: MPVolumeView {
    weak var volume: SystemVolume?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            showsRouteButton = false
            showsVolumeSlider = true
            volume?.slider = subviews.compactMap { $0 as? UISlider }.first
        }
    }
}

struct SystemVolumeView: UIViewRepresentable {
    let volume: SystemVolume
    func makeUIView(context: Context) -> MPVolumeView {
        let view = AttachedVolumeView(frame: .zero)
        view.volume = volume
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

struct VideoSurface: UIViewRepresentable {
    let player: PlayerController
    let volume: SystemVolume
    let onTap: () -> Void
    let onHUD: (String?) -> Void

    func makeUIView(context: Context) -> VideoGestureContainer {
        VideoGestureContainer(player: player, volume: volume)
    }
    func updateUIView(_ view: VideoGestureContainer, context: Context) {
        view.onTap = onTap
        view.onHUD = onHUD
        if view.videoID != player.current?.id {
            view.videoID = player.current?.id
            view.resetZoom()
        }
    }
}

final class VideoGestureContainer: UIView, UIGestureRecognizerDelegate {
    var onTap: (() -> Void)?
    var onHUD: ((String?) -> Void)?
    var videoID: String?
    private let player: PlayerController
    private let volume: SystemVolume
    private var zoom: CGFloat = 1
    private var pinchStart: CGFloat = 1
    private var offset = CGPoint.zero
    private var panStart = CGPoint.zero
    private var gestureSeconds = 0.0
    private var previewSeconds = 0.0
    private var brightnessStart: CGFloat = 0
    private var volumeStart: Float = 0
    private var startsOnLeft = false
    private enum Axis: Equatable { case none, seek, brightness, volume }
    private var axis: Axis = .none

    init(player: PlayerController, volume: SystemVolume) {
        self.player = player
        self.volume = volume
        super.init(frame: .zero)
        backgroundColor = .black
        clipsToBounds = true
        // One persistent drawable follows layout changes; the decoding session is never replaced by rotation.
        player.engine.videoView.removeFromSuperview()
        addSubview(player.engine.videoView)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        doubleTap.numberOfTapsRequired = 2
        singleTap.require(toFail: doubleTap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(oneFinger(_:)))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        let move = UIPanGestureRecognizer(target: self, action: #selector(twoFingers(_:)))
        move.minimumNumberOfTouches = 2
        move.maximumNumberOfTouches = 2
        let recognizers: [UIGestureRecognizer] = [singleTap, doubleTap, pan, pinch, move]
        for recognizer in recognizers {
            recognizer.delegate = self
            addGestureRecognizer(recognizer)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let surface = player.engine.videoView
        surface.transform = .identity
        surface.frame = bounds
        applyTransform()
    }

    func resetZoom() { zoom = 1; offset = .zero; setNeedsLayout() }

    private func applyTransform() {
        let maxX = bounds.width * (zoom - 1) / 2
        let maxY = bounds.height * (zoom - 1) / 2
        offset.x = min(maxX, max(-maxX, offset.x))
        offset.y = min(maxY, max(-maxY, offset.y))
        player.engine.videoView.transform = CGAffineTransform(translationX: offset.x, y: offset.y)
            .scaledBy(x: zoom, y: zoom)
    }

    @objc private func tapped() { onTap?() }
    @objc private func doubleTapped() { player.toggle(); onTap?() }

    @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began { pinchStart = zoom }
        zoom = min(4, max(1, pinchStart * gesture.scale))
        if zoom < 1.03 { zoom = 1; offset = .zero }
        applyTransform()
        onHUD?(String(format: "画面 %.1f×", zoom))
        if gesture.state == .ended || gesture.state == .cancelled { onHUD?(nil) }
    }

    @objc private func twoFingers(_ gesture: UIPanGestureRecognizer) {
        guard zoom > 1 else { return }
        if gesture.state == .began { panStart = offset }
        let translation = gesture.translation(in: self)
        offset = CGPoint(x: panStart.x + translation.x, y: panStart.y + translation.y)
        applyTransform()
    }

    @objc private func oneFinger(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .began:
            axis = .none
            gestureSeconds = player.seconds
            previewSeconds = gestureSeconds
            brightnessStart = UIScreen.main.brightness
            volumeStart = volume.value
            startsOnLeft = gesture.location(in: self).x < bounds.midX
        case .changed:
            if axis == .none && hypot(translation.x, translation.y) > 10 {
                axis = abs(translation.x) > abs(translation.y) ? .seek : (startsOnLeft ? .brightness : .volume)
            }
            switch axis {
            case .seek:
                guard player.isSeekable else { return }
                previewSeconds = min(player.duration, max(0, gestureSeconds + Double(translation.x / max(1, bounds.width)) * 120))
                onHUD?("定位 " + PlaybackTime.string(previewSeconds) + " / " + PlaybackTime.string(player.duration))
            case .brightness:
                let value = min(1, max(0.05, brightnessStart - translation.y / max(1, bounds.height)))
                player.setBrightness(value)
                onHUD?("亮度 \(Int(value * 100))%")
            case .volume:
                let value = min(1, max(0, volumeStart - Float(translation.y / max(1, bounds.height))))
                volume.set(value)
                onHUD?("音量 \(Int(value * 100))%")
            case .none: break
            }
        case .ended:
            if axis == .seek { player.seek(to: previewSeconds) }
            onHUD?(nil)
            axis = .none
        case .cancelled, .failed:
            onHUD?(nil)
            axis = .none
        default: break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        player.current != nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        (gestureRecognizer is UIPinchGestureRecognizer && (otherGestureRecognizer as? UIPanGestureRecognizer)?.minimumNumberOfTouches == 2)
        || (otherGestureRecognizer is UIPinchGestureRecognizer && (gestureRecognizer as? UIPanGestureRecognizer)?.minimumNumberOfTouches == 2)
    }
}

enum PlaybackTime {
    static func string(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = max(0, Int(seconds))
        if total >= 3600 { return String(format: "%d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60) }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
