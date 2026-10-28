import SwiftUI

struct FolderManager: View {
    @ObservedObject var library: LibraryStore
    @ObservedObject var player: PlayerController
    @ObservedObject var thumbnails: ThumbnailService
    @Environment(\.dismiss) private var dismiss
    @State private var showsPicker = false
    @State private var clearing = false
    @State private var reauthorizingID: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(library.sources) { source in
                        VStack(alignment: .leading, spacing: 7) {
                            Label(source.name, systemImage: "folder").font(.headline)
                            Text(library.statuses[source.id]?.description ?? "检查中")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Button("重新授权") { reauthorizingID = source.id; showsPicker = true }.buttonStyle(.borderless)
                                Spacer()
                                Button("移除", role: .destructive) {
                                    if player.current?.sourceID == source.id { player.close() }
                                    library.remove(source)
                                }.buttonStyle(.borderless)
                            }.font(.subheadline)
                        }.padding(.vertical, 5)
                    }
                    Button("添加目录", systemImage: "folder.badge.plus") { reauthorizingID = nil; showsPicker = true }
                        .disabled(library.isLoading)
                } header: { Text("视频目录") } footer: {
                    Text("在“文件”中选择“我的 iPhone / iPad”或外接存储目录。移除目录只清除关联和索引，原视频保持原样。")
                }
                Section {
                    Button {
                        Task { clearing = true; await thumbnails.clear(); clearing = false }
                    } label: {
                        HStack { Text("清除封面缓存"); Spacer(); if clearing { ProgressView() } }
                    }.disabled(clearing)
                } header: { Text("轻量缓存") } footer: {
                    Text("封面缓存上限 64 MB，优先保留最近使用的封面。不会复制视频或保存播放进度。")
                }
                Section("操作提示") {
                    Label("单击显隐控制，双击暂停或继续", systemImage: "hand.tap")
                    Label("左右滑动定位，左侧上下调亮度", systemImage: "sun.max")
                    Label("右侧上下调音量，双指捏合缩放", systemImage: "speaker.wave.2")
                    Label("放大后双指拖动画面，最大 4 倍", systemImage: "arrow.up.left.and.arrow.down.right")
                    Label("最后一集播完停止；切后台或锁屏暂停", systemImage: "pause.circle")
                }.font(.footnote)
                Section {
                    NavigationLink("开源组件与许可") { OpenSourceView() }
                    LabeledContent("版本", value: "Vela Player 0.2.0")
                }
            }
            .navigationTitle("目录与设置").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $showsPicker) {
                FolderPicker(onSelect: { urls in
                    if let id = reauthorizingID {
                        if player.current?.sourceID == id { player.close() }
                        library.reauthorize(id, with: urls)
                    } else { library.add(urls) }
                }, allowsMultipleSelection: reauthorizingID == nil)
            }
        }
    }
}

private struct OpenSourceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("MobileVLCKit 3.7.4 / VideoLAN").font(.headline)
                Text("播放器与首帧解码使用 MobileVLCKit / libVLC。相关组件许可请见以下随包提供的上游说明。")
                Text(license).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            }.padding(20)
        }.navigationTitle("开源许可").navigationBarTitleDisplayMode(.inline)
    }
    private var license: String {
        guard let url = Bundle.main.url(forResource: "MobileVLCKit-COPYING", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "请参阅工程内 THIRD_PARTY_NOTICES.md。" }
        return text
    }
}
