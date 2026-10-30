import SwiftUI
import UIKit

struct TimelinePreviewPosition: Equatable {
    let seconds: Double
    let fraction: CGFloat
}

/// Retains UISlider accessibility while allowing a touch anywhere on its 44pt rail.
struct PlaybackTimeline: UIViewRepresentable {
    @Binding var value: Double
    let duration: Double
    let enabled: Bool
    let editingChanged: (_ editing: Bool, _ commit: Bool) -> Void
    let previewChanged: (TimelinePreviewPosition?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> CinemaSlider {
        let slider = CinemaSlider()
        slider.minimumTrackTintColor = UIColor(red: 229 / 255, green: 9 / 255, blue: 20 / 255, alpha: 1)
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.35)
        let thumb = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
            slider.minimumTrackTintColor?.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        slider.setThumbImage(thumb, for: .normal)
        slider.setThumbImage(thumb, for: .highlighted)
        slider.semanticContentAttribute = .forceLeftToRight
        slider.accessibilityLabel = "播放进度"
        slider.accessibilityHint = "轻点跳转，按住或拖动预览；鼠标悬停仅预览"
        slider.accessibilityIdentifier = "playback.progress"
        slider.editingBegan = { [weak coordinator = context.coordinator] in coordinator?.begin() }
        slider.editingEnded = { [weak coordinator = context.coordinator, weak slider] commit in
            if let slider { coordinator?.end(slider, commit: commit) }
        }
        slider.previewChanged = { [weak coordinator = context.coordinator] in
            coordinator?.parent.previewChanged($0)
        }
        slider.addTarget(context.coordinator, action: #selector(Coordinator.change(_:)), for: .valueChanged)
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return slider
    }
    func updateUIView(_ slider: CinemaSlider, context: Context) {
        context.coordinator.parent = self
        slider.maximumValue = Float(max(1, duration))
        slider.isEnabled = enabled
        if !slider.isTracking { slider.value = Float(value) }
        slider.accessibilityValue = String(format: "%.1f", value)
    }
    static func dismantleUIView(_ slider: CinemaSlider, coordinator: Coordinator) {
        slider.editingBegan = nil
        slider.editingEnded = nil
        slider.previewChanged = nil
    }

    final class Coordinator: NSObject {
        var parent: PlaybackTimeline
        private var tracking = false
        init(_ parent: PlaybackTimeline) { self.parent = parent }
        func begin() { tracking = true; parent.editingChanged(true, false) }
        @objc func change(_ slider: UISlider) {
            // VoiceOver adjustments do not enter touch tracking.
            if !tracking { parent.editingChanged(true, false) }
            parent.value = Double(slider.value)
            if !tracking { parent.editingChanged(false, true) }
        }
        func end(_ slider: UISlider, commit: Bool) {
            parent.value = Double(slider.value)
            tracking = false
            parent.editingChanged(false, commit)
        }
    }
}

final class CinemaSlider: UISlider {
    var editingBegan: (() -> Void)?
    var editingEnded: ((Bool) -> Void)?
    var previewChanged: ((TimelinePreviewPosition?) -> Void)?
    private var touchActive = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(touchFinished), for: [.touchUpInside, .touchUpOutside])
        addTarget(self, action: #selector(touchCancelled), for: .touchCancel)
        if UIDevice.current.userInterfaceIdiom == .pad {
            let hover = UIHoverGestureRecognizer(target: self, action: #selector(hover(_:)))
            // Direct finger input belongs exclusively to slider tracking.
            hover.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue),
                                       NSNumber(value: UITouch.TouchType.pencil.rawValue)]
            addGestureRecognizer(hover)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.trackRect(forBounds: bounds)
        return CGRect(x: rect.minX, y: bounds.midY - 1.5, width: rect.width, height: 3)
    }

    /// Uses the actual thumb centers so clicks at both ends reach 0 / duration.
    func position(at point: CGPoint) -> TimelinePreviewPosition {
        let rail = trackRect(forBounds: bounds)
        let start = thumbRect(forBounds: bounds, trackRect: rail, value: minimumValue).midX
        let end = thumbRect(forBounds: bounds, trackRect: rail, value: maximumValue).midX
        let fraction = min(1, max(0, (point.x - start) / max(1, end - start)))
        return TimelinePreviewPosition(seconds: Double(minimumValue) + Double(fraction) * Double(maximumValue - minimumValue),
                                       fraction: min(1, max(0, point.x / max(1, bounds.width))))
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard isEnabled else { return false }
        touchActive = true
        editingBegan?()
        // Put the thumb under the finger before asking UISlider to establish its
        // own tracking state. Skipping super can omit its touch-up completion.
        value = Float(position(at: touch.location(in: self)).seconds)
        _ = super.beginTracking(touch, with: event)
        updateTouch(touch)
        return true
    }
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard touchActive else { return false }
        _ = super.continueTracking(touch, with: event)
        updateTouch(touch)
        return true
    }
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        if touchActive, let touch { updateTouch(touch) }
        finish(commit: true)
    }
    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        finish(commit: false)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if touchActive, let touch = touches.first { updateTouch(touch) }
        finish(commit: true)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        finish(commit: false)
    }
    @objc private func touchFinished() { finish(commit: true) }
    @objc private func touchCancelled() { finish(commit: false) }
    private func finish(commit: Bool) {
        guard touchActive else { return }
        touchActive = false
        previewChanged?(nil)
        editingEnded?(commit)
    }
    private func updateTouch(_ touch: UITouch) {
        let target = position(at: touch.location(in: self))
        value = Float(target.seconds)
        sendActions(for: .valueChanged)
        previewChanged?(target)
    }
    @objc private func hover(_ gesture: UIHoverGestureRecognizer) {
        guard !isTracking else { return }
        switch gesture.state {
        case .began, .changed: preview(at: gesture.location(in: self))
        default: preview(at: nil)
        }
    }
    // Shared path for pointer movement and touch preview; never commits a seek.
    func preview(at point: CGPoint?) {
        previewChanged?(isEnabled ? point.map(position(at:)) : nil)
    }
}
