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

    var body: some View {
        VideoSurface(player: player, volume: volume, onTap: toggleControls,
                     onHUD: showHUD) {
          ZStack {
            if player.current == nil {
                VStack(spacing: 14) {
                    Image(systemName: "play.rectangle").font(.system(size: 40, weight: .ultraLight))
                    Text("视频留在原处，打开即播放").font(.subheadline)
                    Button("选择视频目录", systemImage: "folder.badge.plus", action: chooseFolder)
                        .buttonStyle(.borderedProminent).tint(AppStyle.accent).foregroundStyle(.black).playbackControl()
                }
                .foregroundStyle(.white.opacity(0.7))
            } else {
                if controlsVisible || !player.isPlaying { controls }
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
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
        .onAppear { controlsVisible = true; scheduleHide() }
        .onChange(of: player.current?.id) { _, _ in controlsVisible = true; scheduleHide() }
        .onChange(of: player.status) { _, _ in scheduleHide() }
        .onDisappear { hideTask?.cancel(); hudTask?.cancel() }
    }

    private var controls: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.65), .clear, .clear, .black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    if expanded { control("folder", label: "目录管理", action: manageFolders) }
                    Text(player.current?.fileName ?? "").font(.subheadline.weight(.medium)).lineLimit(1)
                    Spacer(minLength: 0)
                    control("chevron.down", label: "返回资料库", action: close)
                }
                Spacer(minLength: 12)
                HStack(spacing: expanded ? 44 : 32) {
                    control("backward.end.fill", label: "上一个视频", action: player.previous)
                        .disabled(!player.queue.hasPrevious)
                    Button(action: player.toggle) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: expanded ? 32 : 26, weight: .semibold))
                            .frame(width: 64, height: 58)
                    }
                    .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
                    .playbackControl()
                    control("forward.end.fill", label: "下一个视频", action: player.next)
                        .disabled(!player.queue.hasNext)
                }
                Spacer(minLength: 12)
                VStack(spacing: 2) {
                    Slider(value: Binding(get: { scrubbing ? scrubValue : player.seconds }, set: { scrubValue = $0 }),
                           in: 0...max(1, player.duration), onEditingChanged: { editing in
                        if editing { scrubValue = player.seconds }
                        scrubbing = editing
                        if !editing { player.seek(to: scrubValue) }
                        scheduleHide()
                    })
                    .tint(AppStyle.accent).disabled(!player.isSeekable)
                    .accessibilityLabel("播放进度")
                    .playbackControl()
                    HStack(spacing: 12) {
                        Text(PlaybackTime.string(scrubbing ? scrubValue : player.seconds) + " / " + PlaybackTime.string(player.duration))
                            .font(.system(.caption, design: .monospaced)).monospacedDigit()
                        Spacer(minLength: 0)
                        Menu {
                            ForEach([Float(0.5), 0.75, 1, 1.25, 1.5, 2, 2.5, 3], id: \.self) { value in
                                Button { player.setRate(value) } label: {
                                    if player.rate == value { Label(rateLabel(value), systemImage: "checkmark") }
                                    else { Text(rateLabel(value)) }
                                }
                            }
                        } label: { Text(rateLabel(player.rate)).font(.subheadline.weight(.semibold)).frame(minWidth: 36, minHeight: 36) }
                        .playbackControl()
                        if expanded {
                            control(player.showsPlaylist ? "list.bullet.rectangle.fill" : "list.bullet.rectangle",
                                    label: "显示或隐藏播放列表") { player.showsPlaylist.toggle(); scheduleHide() }
                        }
                        control(expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                                label: expanded ? "退出全屏" : "全屏播放", action: toggleFullscreen)
                    }
                }
            }
            .padding(.horizontal, expanded ? 24 : 14).padding(.vertical, 10)
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 17, weight: .medium)).frame(width: 40, height: 40) }
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
        guard player.isPlaying, controlsVisible, !scrubbing else { return }
        hideTask = Task {
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            withAnimation(.easeOut(duration: 0.2)) { controlsVisible = false }
        }
    }
}

private extension View {
    func playbackControl() -> some View {
        background(PlaybackControlArea())
    }
}
