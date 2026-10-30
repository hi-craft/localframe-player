import SwiftUI

struct SettingsView: View {
    @ObservedObject var thumbnails: ThumbnailService
    @State private var clearing = false
    @State private var cleared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Text("设置").font(.system(size: 32, weight: .bold))
                    Spacer()
                    Text("VELA").font(.system(size: 22, weight: .black).width(.condensed)).tracking(1).foregroundStyle(AppStyle.accent)
                }
                HStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: 6).fill(AppStyle.accent).frame(width: 64, height: 64)
                        .overlay { Image(systemName: "person.fill").font(.system(size: 35)).foregroundStyle(.white) }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("你的私人影院").font(.title3.bold())
                        Text("Vela Player \(version)").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("settings.version")
                    }
                }.padding(.vertical, 10)
                CinemaSection(title: "应用设置") {
                    Button {
                        Task { clearing = true; await thumbnails.clear(); clearing = false; cleared = true }
                    } label: {
                        HStack(spacing: 0) {
                            CinemaRow(title: cleared ? "封面缓存已清除" : "清除封面缓存", symbol: cleared ? "checkmark.circle" : "internaldrive",
                                      subtitle: "最多 64 MB，浏览时按需生成")
                            if clearing { ProgressView().padding(.trailing, 18) }
                        }
                    }.buttonStyle(.plain).disabled(clearing).accessibilityIdentifier("settings.clear-cache")
                    CinemaDivider()
                    NavigationLink { GestureGuideView() } label: {
                        CinemaRow(title: "播放与手势指南", symbol: "hand.tap", subtitle: "快进、锁定、旋转与目录刷新", disclosure: true)
                    }.buttonStyle(.plain).accessibilityIdentifier("settings.guide")
                    CinemaDivider()
                    NavigationLink { OpenSourceView() } label: {
                        CinemaRow(title: "开源组件与许可", symbol: "info.circle", disclosure: true)
                    }.buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 9) {
                    Label("视频留在原处", systemImage: "folder.badge.checkmark").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.8))
                    Text("不复制原视频，不保存播放进度。连接目录后，随时打开你的本地收藏。")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(24).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity).padding(.bottom, 20)
        }.background(AppStyle.background).toolbar(.hidden, for: .navigationBar)
    }
    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "\(version) (\(build))"
    }
}

struct GestureGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("轻触，即刻掌控").font(.system(size: 26, weight: .bold))
                CinemaSection(title: "观看时") {
                    CinemaRow(title: "单击 / 双击", symbol: "hand.tap", subtitle: "单击显隐控制，双击暂停或继续")
                    CinemaDivider()
                    CinemaRow(title: "快进与定位", symbol: "goforward.10", subtitle: "按钮前后跳转 10 秒；轻点进度条跳转，左右滑动画面定位")
                    CinemaDivider()
                    CinemaRow(title: "全屏选集", symbol: "rectangle.stack", subtitle: "从画面右侧向左滑出播放列表，在列表上向右滑收起；锁定后手势停用")
                    CinemaRow(title: "画面预览", symbol: "photo.on.rectangle", subtitle: "按住或拖动进度条预览，松手定位；鼠标或触控板悬停只预览")
                    CinemaDivider()
                    CinemaRow(title: "亮度与音量", symbol: "sun.max", subtitle: "画面左侧上下调亮度，右侧上下调音量")
                    CinemaDivider()
                    CinemaRow(title: "缩放与移动", symbol: "arrow.up.left.and.arrow.down.right", subtitle: "双指捏合放大，最大 4 倍；放大后双指拖动画面")
                    CinemaDivider()
                    CinemaRow(title: "安心观看", symbol: "lock", subtitle: "锁定防止误触；更多选项里可设置定时暂停")
                }
                CinemaSection(title: "管理资料库") {
                    CinemaRow(title: "查看视频信息", symbol: "info.circle", subtitle: "长按视频查看大小、位置和修改时间")
                    CinemaDivider()
                    CinemaRow(title: "下拉刷新", symbol: "arrow.clockwise", subtitle: "清空已连接可读目录的索引并重建，离线记录保留")
                }
                Text("iPhone 退出全屏和返回资料库时恢复竖屏。最后一部播完停止；切到后台或锁屏后暂停，返回后手动继续。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }.background(AppStyle.background).navigationTitle("播放与手势指南").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
    }
}

struct OpenSourceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("MobileVLCKit 3.7.4 / VideoLAN").font(.headline)
                Text("播放器与首帧解码使用 MobileVLCKit / libVLC。相关组件许可请见以下随包提供的上游说明。")
                Text(license).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            }.padding(20)
        }.background(AppStyle.background).navigationTitle("开源许可").toolbar(.visible, for: .navigationBar).navigationBarTitleDisplayMode(.inline)
    }
    private var license: String {
        guard let url = Bundle.main.url(forResource: "MobileVLCKit-COPYING", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "请参阅工程内 THIRD_PARTY_NOTICES.md。" }
        return text
    }
}
