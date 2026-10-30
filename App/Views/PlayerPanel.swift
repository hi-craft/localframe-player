import SwiftUI

struct PlayerPanel: View {
    @ObservedObject var player: PlayerController
    let volume: SystemVolume
    let expanded: Bool
    let chooseFolder: () -> Void
    let manageFolders: () -> Void
    let close: () -> Void
    let toggleFullscreen: () -> Void
    @State private var controlsVisible = true
    @State private var hud: String?
    @State private var hideTask: Task<Void, Never>?
    @State private var hudTask: Task<Void, Never>?
    @State private var scrubValue = 0.0
    @State private var scrubbing = false
    @State private var showsRates = false
    @State private var showsOptions = false
    @State private var controlRects: [CGRect] = []
    @StateObject private var previews = PlaybackPreviewService()
    @State private var previewPosition: TimelinePreviewPosition?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            VideoDrawable(player: player).allowsHitTesting(false)
            if player.current == nil {
                VStack(spacing: 14) {
                    Image(systemName: "play.rectangle").font(.system(size: 40, weight: .ultraLight))
                    Text("视频留在原处，打开即播放").font(.subheadline)
                    Button("选择视频目录", systemImage: "folder.badge.plus", action: chooseFolder)
                        .buttonStyle(.borderedProminent).tint(AppStyle.accent).foregroundStyle(.white).playbackControl()
                }
                .foregroundStyle(.white.opacity(0.7))
            } else {
                if player.controlsLocked { lockedControls }
                else if controlsVisible || !player.isPlaying { controls }
                if player.isBusy {
                    ProgressView().controlSize(.large).tint(.white)
                        .offset(y: controlsVisible ? -50 : 0).allowsHitTesting(false)
                }
                if let message = player.failureMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").font(.title2)
                        Text(message).font(.callout).multilineTextAlignment(.center)
                        Button("重新尝试", action: player.toggle).buttonStyle(.bordered).playbackControl()
                    }
                    .padding(20).frame(maxWidth: 360).background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
                }
                if let hud {
                    Text(hud).font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .offset(y: -35).allowsHitTesting(false)
                }
            }
            VideoSurface(player: player, volume: volume, onTap: toggleControls, onHUD: showHUD, controlRects: controlRects,
                         allowsPlaylistReveal: expanded && !player.showsPlaylist,
                         onRevealPlaylist: {
                             withAnimation(.easeOut(duration: 0.2)) { player.showsPlaylist = true }
                             scheduleHide()
                         })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .coordinateSpace(name: "playerControls")
        .onPreferenceChange(PlaybackControlFrames.self) { controlRects = $0 }
        .sheet(isPresented: $showsRates) { PlaybackRateView(player: player) }
        .onChange(of: showsRates) { _, shown in if shown { clearPreview() }; scheduleHide() }
        .sheet(isPresented: $showsOptions) { PlaybackOptionsView(player: player) }
        .onChange(of: showsOptions) { _, shown in if shown { clearPreview() }; scheduleHide() }
        .onChange(of: player.controlsLocked) { _, _ in
            clearPreview()
            hud = nil
            controlsVisible = true
            scheduleHide()
        }
        .onAppear { controlsVisible = true; scheduleHide() }
        .onChange(of: player.current?.id) { _, _ in clearPreview(); controlsVisible = true; scheduleHide() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { clearPreview() } }
        .onChange(of: expanded) { _, _ in clearPreview() }
        .onChange(of: player.isSeekable) { _, seekable in if !seekable { clearPreview() } }
        .onChange(of: player.status) { _, _ in
            if !player.isPlaying { controlsVisible = true }
            scheduleHide()
        }
        .onDisappear { hideTask?.cancel(); hudTask?.cancel(); clearPreview() }
    }

    private var controls: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(stops: [.init(color: .black.opacity(0.7), location: 0),
                                       .init(color: .black.opacity(0.12), location: 0.4),
                                       .init(color: .black.opacity(0.35), location: 0.6),
                                       .init(color: .black.opacity(0.9), location: 1)],
                               startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        control("chevron.down", label: "返回资料库", action: close)
                        Text(player.current?.fileName ?? "")
                            .font(.system(size: expanded ? 16 : 13, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 0)
                        if let deadline = player.sleepDeadline {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Label(PlaybackTime.string(max(0, deadline.timeIntervalSince(context.date))), systemImage: "moon.zzz")
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.8))
                                    .accessibilityLabel("定时暂停剩余时间")
                            }
                        }
                        control("ellipsis", label: "更多播放选项") { showsOptions = true }
                        control(expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                                label: expanded ? "退出全屏" : "全屏播放", action: toggleFullscreen)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: expanded ? 66 : 44) {
                        seekControl("gobackward.10", label: "后退10秒", interval: -10)
                        Button { player.toggle(); controlsVisible = true; scheduleHide() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: expanded ? 44 : 32, weight: .bold))
                                .offset(x: player.isPlaying ? 0 : 2)
                                .frame(width: expanded ? 76 : 60, height: expanded ? 76 : 60)
                        }
                        .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
                        .accessibilityIdentifier("playback.toggle").playbackControl()
                        seekControl("goforward.10", label: "前进10秒", interval: 10)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        Text(PlaybackTime.string(scrubbing ? scrubValue : player.seconds))
                            .frame(minWidth: 32, alignment: .leading)
                        PlaybackTimeline(value: Binding(get: { scrubbing ? scrubValue : player.seconds }, set: { scrubValue = $0 }),
                                         duration: player.duration, enabled: player.isSeekable, editingChanged: { editing, commit in
                            if editing { scrubValue = player.seconds }
                            scrubbing = editing
                            if !editing && commit { player.seek(to: scrubValue) }
                            scheduleHide()
                        }, previewChanged: updatePreview)
                        .frame(height: 44)
                        .overlay(alignment: .bottomLeading) {
                            if let previewPosition {
                                GeometryReader { timeline in
                                    let width = min(156.0, timeline.size.width)
                                    previewCard(seconds: previewPosition.seconds, width: width)
                                        .position(x: min(max(width / 2, timeline.size.width * previewPosition.fraction), timeline.size.width - width / 2),
                                                  y: -42)
                                }.allowsHitTesting(false)
                            }
                        }.playbackControl()
                        Text("−" + PlaybackTime.string(max(0, player.duration - (scrubbing ? scrubValue : player.seconds))))
                            .frame(minWidth: 36, alignment: .trailing)
                    }.font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                    HStack(spacing: expanded && geometry.size.width > 650 ? 24 : 8) {
                        control("backward.end.fill", label: "上一个视频", action: player.previous).disabled(!player.queue.hasPrevious)
                        Button { showsRates = true; hideTask?.cancel() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "speedometer").font(.system(size: 17))
                                Text(rateLabel(player.rate)).font(.system(size: 12, weight: .semibold))
                            }.frame(minWidth: 68, minHeight: 44)
                        }.accessibilityLabel(rateLabel(player.rate)).playbackControl()
                        Button { player.setControlsLocked(true) } label: {
                            Label("锁定", systemImage: "lock").font(.system(size: 12, weight: .medium)).frame(minHeight: 44)
                        }.accessibilityLabel("锁定播放控制").playbackControl()
                        Spacer(minLength: 0)
                        if expanded {
                            if geometry.size.width > 650 { control("folder", label: "目录管理", action: manageFolders) }
                            Button { player.showsPlaylist.toggle(); scheduleHide() } label: {
                                Label("选集", systemImage: "rectangle.stack").font(.system(size: 12, weight: .medium)).frame(minHeight: 44)
                            }.accessibilityLabel("显示或隐藏播放列表").playbackControl()
                        }
                        Button { player.next(); controlsVisible = true; scheduleHide() } label: {
                            Label("下一部", systemImage: "forward.end.fill").font(.system(size: 12, weight: .medium)).frame(minHeight: 44)
                        }.accessibilityLabel("下一个视频").disabled(!player.queue.hasNext).playbackControl()
                    }
                }
                .padding(.leading, expanded ? max(24, geometry.safeAreaInsets.leading + 8) : 12)
                .padding(.trailing, expanded ? max(24, geometry.safeAreaInsets.trailing + 8) : 12)
                .padding(.top, expanded ? max(8, geometry.safeAreaInsets.top) : 2)
                .padding(.bottom, expanded ? max(12, geometry.safeAreaInsets.bottom) : 0)
            }
        }.foregroundStyle(.white).buttonStyle(.plain)
            .accessibilityHidden(showsRates || showsOptions)
    }

    private func seekControl(_ symbol: String, label: String, interval: Double) -> some View {
        Button { skip(interval); controlsVisible = true; scheduleHide() } label: {
            Image(systemName: symbol).font(.system(size: expanded ? 34 : 27, weight: .regular))
                .frame(width: 52, height: 52)
        }.accessibilityLabel(label).disabled(!player.isSeekable).playbackControl()
    }

    private var lockedControls: some View {
        GeometryReader { geometry in
            VStack {
                HStack(spacing: 10) {
                    Button { player.setControlsLocked(false) } label: {
                        Label("解锁", systemImage: "lock.fill").font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14).frame(height: 44)
                            .background(.black.opacity(0.7), in: Capsule())
                    }.playbackControl().accessibilityLabel("解锁播放控制")
                    Text("已锁定，防止误触").font(.caption).foregroundStyle(.white.opacity(0.75))
                    Spacer()
                }
                Spacer()
            }
            .padding(.leading, expanded ? max(24, geometry.safeAreaInsets.leading + 8) : 14)
            .padding(.trailing, expanded ? max(24, geometry.safeAreaInsets.trailing + 8) : 14)
            .padding(.top, expanded ? max(14, geometry.safeAreaInsets.top) : 14)
        }.foregroundStyle(.white)
    }

    private func skip(_ interval: Double) {
        player.skip(by: interval)
        showHUD((interval > 0 ? "前进 " : "后退 ") + "10 秒")
        showHUD(nil)
    }

    private func previewCard(seconds: Double, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color(white: 0.12)
                if let image = previews.image {
                    Image(uiImage: image).resizable().scaledToFit().accessibilityIdentifier("playback.preview.image")
                } else if previews.unavailable {
                    Image(systemName: "film").foregroundStyle(.white.opacity(0.5))
                } else { ProgressView().tint(.white) }
            }.frame(width: width, height: width * 9 / 16).clipped()
            Text(PlaybackTime.string(seconds)).font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 5)
                .accessibilityIdentifier("playback.preview.time")
        }
        .frame(width: width).background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.65), lineWidth: 1))
        .accessibilityElement(children: .contain).accessibilityIdentifier("playback.preview")
    }

    private func updatePreview(_ position: TimelinePreviewPosition?) {
        previewPosition = position
        if let position, let item = player.current, let source = player.currentSource {
            previews.request(item: item, source: source, seconds: position.seconds, duration: player.duration)
        } else { previews.cancel() }
        scheduleHide()
    }

    private func clearPreview() {
        previewPosition = nil
        scrubbing = false
        previews.cancel()
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button { action(); controlsVisible = true; scheduleHide() } label: { Image(systemName: symbol).font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44) }
            .accessibilityLabel(label)
            .playbackControl()

    }

    private func toggleControls() {
        withAnimation(.easeOut(duration: 0.15)) { controlsVisible.toggle() }
        scheduleHide()
    }

    private func rateLabel(_ value: Float) -> String { String(format: "%g×", value) }

    private func showHUD(_ value: String?) {
        hudTask?.cancel()
        if let value { hud = value }
        else {
            hudTask = Task {
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                hud = nil
            }
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        guard player.isPlaying, controlsVisible, !player.controlsLocked, !scrubbing, previewPosition == nil, !showsRates, !showsOptions else { return }
        hideTask = Task {
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            withAnimation(.easeOut(duration: 0.2)) { controlsVisible = false }
        }
    }
}


private struct PlaybackControlFrames: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

private extension View {
    func playbackControl() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: PlaybackControlFrames.self,
                                       value: [geometry.frame(in: .named("playerControls"))])
            }.allowsHitTesting(false)
        }
    }
}
