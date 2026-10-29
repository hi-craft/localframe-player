import SwiftUI

struct PlaybackRateView: View {
    @ObservedObject var player: PlayerController
    @Environment(\.dismiss) private var dismiss
    private let rates: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("按你的节奏观看").font(.system(size: 24, weight: .bold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 10)], spacing: 10) {
                        ForEach(rates, id: \.self) { rate in
                            Button { player.setRate(rate); dismiss() } label: {
                                VStack(spacing: 8) {
                                    Text(String(format: "%g×", rate)).font(.system(size: 21, weight: .bold))
                                    Text(rate == 1 ? "标准" : (rate < 1 ? "慢速" : "快速")).font(.caption).opacity(0.65)
                                }.frame(maxWidth: .infinity).frame(height: 86)
                                    .foregroundStyle(rate == player.rate ? .black : .white)
                                    .background(rate == player.rate ? .white : AppStyle.elevated, in: RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain).accessibilityLabel(String(format: "%g×", rate))
                                .accessibilityAddTraits(rate == player.rate ? .isSelected : [])
                        }
                    }
                }.padding(24).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }.background(AppStyle.background)
                .navigationTitle("播放速度").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.tint(.white).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            .presentationCornerRadius(14).preferredColorScheme(.dark)
    }
}

struct PlaybackOptionsView: View {
    @ObservedObject var player: PlayerController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if let item = player.current {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("正在播放").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text((item.fileName as NSString).deletingPathExtension).font(.system(size: 24, weight: .bold)).lineLimit(2)
                        }
                    }
                    CinemaSection(title: "播放控制") {
                        Button { player.setControlsLocked(true); dismiss() } label: {
                            CinemaRow(title: "锁定播放控制", symbol: "lock", subtitle: "屏蔽画面手势和播放列表，避免误触")
                        }.buttonStyle(.plain).accessibilityLabel("锁定播放控制")
                            .accessibilityIdentifier("playback.options.lock")
                        if let item = player.current {
                            CinemaDivider()
                            NavigationLink {
                                VideoInfoContent(item: item, source: player.currentSource, status: player.currentSourceStatus)
                            } label: { CinemaRow(title: "视频信息", symbol: "info.circle", subtitle: "格式、大小与文件位置", disclosure: true) }
                                .buttonStyle(.plain).accessibilityLabel("视频信息")
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("定时暂停", systemImage: "moon.zzz").font(.system(size: 19, weight: .bold))
                            Spacer()
                            if let deadline = player.sleepDeadline {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(PlaybackTime.string(max(0, deadline.timeIntervalSince(context.date))))
                                        .font(.subheadline.monospacedDigit()).foregroundStyle(.white)
                                        .accessibilityLabel("剩余时间")
                                }
                            } else { Text("未开启").font(.caption).foregroundStyle(.secondary) }
                        }
                        HStack(spacing: 10) {
                            ForEach([15, 30, 60], id: \.self) { minutes in
                                Button { player.setSleepTimer(after: Double(minutes * 60)) } label: {
                                    VStack(spacing: 5) {
                                        Text("\(minutes)").font(.system(size: 24, weight: .semibold))
                                        Text("分钟").font(.caption).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity).frame(height: 80)
                                        .background(AppStyle.elevated, in: RoundedRectangle(cornerRadius: 5))
                                }.buttonStyle(.plain).accessibilityLabel("\(minutes)分钟后暂停")
                            }
                        }
                        if player.sleepDeadline != nil {
                            Button("取消定时暂停") { player.cancelSleepTimer() }.buttonStyle(CinemaButtonStyle())
                        }
                        Text("计时包含暂停和连播时间；关闭播放页后取消。").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(24).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }.background(AppStyle.background)
                .navigationTitle("播放选项").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.tint(.white).presentationDetents([.large]).presentationDragIndicator(.visible)
            .presentationCornerRadius(14).preferredColorScheme(.dark)
    }
}
