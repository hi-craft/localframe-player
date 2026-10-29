import Foundation
import UIKit
import AVFoundation
import Combine
import LocalLibraryCore

enum PlaybackStatus: Equatable {
    case empty, opening, buffering, playing, paused, ended, failed
}

private struct PreparedVideo: @unchecked Sendable {
    let lease: FolderLease
    let url: URL
}

@MainActor final class PlayerController: ObservableObject {
    @Published private(set) var current: VideoItem?
    @Published private(set) var queue = PlaybackQueue()
    @Published private(set) var status: PlaybackStatus = .empty
    @Published private(set) var seconds = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var isSeekable = false
    @Published private(set) var rate: Float = 1
    @Published private(set) var failureMessage: String?
    @Published private(set) var isBusy = false
    @Published var isFullscreen = false
    @Published var showsPlaylist = false
    @Published private(set) var controlsLocked = false
    @Published private(set) var sleepDeadline: Date?
    let engine = LPPlaybackBridge()
    var isPlaying: Bool { status == .playing || status == .buffering }
    private let library: LibraryStore
    private var lease: FolderLease?
    private var currentURL: URL?
    private var loadTask: Task<Void, Never>?
    private var availabilityTask: Task<Void, Never>?
    private var loadingTask: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?
    private var activity = PlaybackActivity()
    private var requestID = UUID()
    private var engineLoaded = false
    private var appActive = true
    private var wantsPlayback = false
    private var observers: [NSObjectProtocol] = []
    private var originalBrightness: CGFloat?
    var currentSource: FolderSource? { current.flatMap { library.source(for: $0) } }
    var currentSourceStatus: String { currentSource.flatMap { library.statuses[$0.id]?.description } ?? "目录不可读" }

    init(library: LibraryStore) {
        self.library = library
        showsPlaylist = UIDevice.current.userInterfaceIdiom == .pad
        engine.stateChanged = { [weak self] state in self?.receive(state) }
        engine.progressChanged = { [weak self] seconds, duration, seekable in
            guard let self else { return }
            self.seconds = seconds
            self.duration = duration
            self.isSeekable = seekable
            let advanced = self.activity.update(seconds: seconds, at: ProcessInfo.processInfo.systemUptime)
            if advanced && self.appActive && self.wantsPlayback && self.status != .ended && self.status != .failed {
                if self.status != .playing { self.status = .playing }
                self.clearLoading()
            }
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if type == AVAudioSession.InterruptionType.began.rawValue {
                Task { @MainActor in self?.pause() }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                Task { @MainActor in self?.pause() }
            }
        })
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    func select(_ item: VideoItem, from visibleItems: [VideoItem]) {
        queue.select(item, from: visibleItems)
        openCurrent()
    }

    func next() { guard queue.advance() != nil else { return }; openCurrent() }
    func previous() { guard queue.previous() != nil else { return }; openCurrent() }

    func toggle() {
        guard current != nil else { return }
        if expireSleepTimerIfNeeded() { return }
        if isPlaying || status == .opening { pause() }
        else if status == .ended || status == .failed || !engineLoaded { openCurrent() }
        else {
            do { try AVAudioSession.sharedInstance().setActive(true) }
            catch { failureMessage = error.localizedDescription; return }
            wantsPlayback = true
            engine.play()
        }
    }

    func pause() {
        wantsPlayback = false
        clearLoading()
        engine.pause()
        if current != nil && status != .failed && status != .ended { status = .paused }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func seek(to value: Double) {
        guard isSeekable, duration > 0, value.isFinite else { return }
        let target = min(max(0, value), duration)
        seconds = target
        engine.seek(seconds: target)
    }

    func skip(by interval: Double) {
        guard interval.isFinite else { return }
        seek(to: seconds + interval)
    }

    func setControlsLocked(_ locked: Bool) {
        controlsLocked = current != nil && locked
    }

    func setSleepTimer(after interval: TimeInterval) {
        guard current != nil, interval.isFinite, interval > 0, interval <= 86400 else { return }
        cancelSleepTimer()
        sleepDeadline = Date().addingTimeInterval(interval)
        sleepTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(interval)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.finishSleepTimer()
        }
    }

    func cancelSleepTimer() {
        sleepTask?.cancel()
        sleepTask = nil
        sleepDeadline = nil
    }

    @discardableResult private func expireSleepTimerIfNeeded() -> Bool {
        guard let sleepDeadline, sleepDeadline <= Date() else { return false }
        finishSleepTimer()
        return true
    }

    private func finishSleepTimer() {
        cancelSleepTimer()
        controlsLocked = false
        pause()
    }

    func setRate(_ value: Float) {
        rate = min(3, max(0.25, value))
        engine.setRate(rate)
    }

    func setBrightness(_ value: CGFloat) {
        if originalBrightness == nil { originalBrightness = UIScreen.main.brightness }
        UIScreen.main.brightness = min(1, max(0.05, value))
    }

    func setAppActive(_ active: Bool) {
        appActive = active
        expireSleepTimerIfNeeded()
        if !active {
            controlsLocked = false
            pause()
            restoreBrightness()
        }
    }

    func close() {
        cancelSleepTimer()
        controlsLocked = false
        requestID = UUID()
        loadTask?.cancel()
        availabilityTask?.cancel()
        clearLoading()
        activity.reset()
        let previousLease = lease
        lease = nil
        engineLoaded = false
        wantsPlayback = false
        engine.stop {
            withExtendedLifetime(previousLease) {}
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        current = nil
        currentURL = nil
        status = .empty
        queue = PlaybackQueue()
        seconds = 0; duration = 0; isSeekable = false
        failureMessage = nil
        isFullscreen = false
        UIApplication.shared.isIdleTimerDisabled = false
        restoreBrightness()
    }

    private func openCurrent() {
        guard let item = queue.current, let source = library.source(for: item) else { return }
        loadTask?.cancel()
        availabilityTask?.cancel()
        let token = UUID()
        requestID = token
        current = item
        failureMessage = nil
        status = .opening
        wantsPlayback = true
        clearLoading()
        activity.reset()
        scheduleLoading()
        seconds = 0; duration = 0; isSeekable = false
        engineLoaded = false
        let previousLease = lease
        lease = nil
        loadTask = Task {
            await withCheckedContinuation { continuation in engine.stop { continuation.resume() } }
            withExtendedLifetime(previousLease) {}
            guard !Task.isCancelled, token == requestID else { return }
            do {
                let prepared = try await Task.detached(priority: .userInitiated) { () throws -> PreparedVideo in
                    let lease = try FolderLease(source: source)
                    return try CoordinatedRead.perform(at: lease.url) { _ in
                        PreparedVideo(lease: lease, url: try lease.fileURL(for: item))
                    }
                }.value
                guard !Task.isCancelled, token == requestID else { return }
                lease = prepared.lease
                currentURL = prepared.url
                guard appActive, wantsPlayback else { status = .paused; return }
                let audio = AVAudioSession.sharedInstance()
                try audio.setCategory(.playback, mode: .moviePlayback)
                try audio.setActive(true)
                engine.setRate(rate)
                engine.open(fileURL: prepared.url)
                engineLoaded = true
                watchAvailability(item: item, prepared: prepared, token: token)
            } catch {
                guard token == requestID, !Task.isCancelled else { return }
                fail(error.localizedDescription, disconnected: true)
            }
        }
    }

    private func watchAvailability(item: VideoItem, prepared: PreparedVideo, token: UUID) {
        availabilityTask = Task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                let available = await Task.detached(priority: .utility) {
                    (try? prepared.lease.fileURL(for: item)) != nil
                }.value
                guard !Task.isCancelled, token == requestID else { return }
                if !available {
                    fail("文件或外接存储已断开。请重新连接后刷新目录，再手动开始播放。", disconnected: true)
                    return
                }
            }
        }
    }

    private func fail(_ message: String, disconnected: Bool = false) {
        controlsLocked = false
        wantsPlayback = false
        clearLoading()
        status = .failed
        failureMessage = message
        availabilityTask?.cancel()
        let previousLease = lease
        lease = nil
        engineLoaded = false
        engine.stop { withExtendedLifetime(previousLease) {} }
        if disconnected, let current {
            library.markUnavailable(current.sourceID, reason: "未连接或需要重新授权")
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func handlePlaybackError() {
        let token = requestID
        let checkedLease = lease
        let checkedItem = current
        fail("无法播放此视频。文件可能已移走、损坏或编码不受支持。")
        guard let checkedLease, let checkedItem else { return }
        // A decoder error can arrive before the two-second availability check. Diagnose it
        // after stopping so an unplugged device is still marked offline instead of losing the check.
        Task {
            let availability = await Task.detached(priority: .utility) {
                let directoryExists = FileManager.default.fileExists(atPath: checkedLease.url.path)
                let fileExists = (try? checkedLease.fileURL(for: checkedItem)) != nil
                return (directoryExists, fileExists)
            }.value
            guard token == requestID, status == .failed else { return }
            if !availability.0 {
                library.markUnavailable(checkedItem.sourceID, reason: "未连接或需要重新授权")
                failureMessage = "目录或外接存储已断开。请重新连接后刷新目录，再手动开始播放。"
            } else if !availability.1 {
                failureMessage = "视频已移走或暂时不可读。请刷新目录，或重新授权后再播放。"
            }
        }
    }

    private func receive(_ state: String) {
        guard current != nil else { return }
        switch state {
        case "opening":
            status = wantsPlayback ? .opening : .paused
            if wantsPlayback { scheduleLoading() }
        case "buffering":
            guard wantsPlayback else { status = .paused; clearLoading(); return }
            // VLC can report buffering after it has already started advancing the clock.
            guard !activity.hasRecentProgress(at: ProcessInfo.processInfo.systemUptime) else { return }
            status = .buffering
            scheduleLoading()
        case "playing":
            guard appActive, wantsPlayback else { pause(); return }
            status = .playing
            clearLoading()
        case "paused": status = .paused; clearLoading()
        case "ended":
            if expireSleepTimerIfNeeded() { return }
            status = .ended
            clearLoading()
            availabilityTask?.cancel()
            if appActive && wantsPlayback && queue.hasNext { next() }
        case "error": handlePlaybackError()
        default: break
        }
        UIApplication.shared.isIdleTimerDisabled = isPlaying
    }

    private func scheduleLoading() {
        guard loadingTask == nil else { return }
        loadingTask = Task {
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            loadingTask = nil
            guard wantsPlayback, status == .opening || status == .buffering else { return }
            isBusy = !activity.hasRecentProgress(at: ProcessInfo.processInfo.systemUptime)
        }
    }

    private func clearLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        if isBusy { isBusy = false }
    }

    private func restoreBrightness() {
        if let originalBrightness { UIScreen.main.brightness = originalBrightness }
        originalBrightness = nil
    }
}
