import SwiftUI

struct FolderManager: View {
    @ObservedObject var library: LibraryStore
    @ObservedObject var player: PlayerController
    @ObservedObject var thumbnails: ThumbnailService
    @Environment(\.dismiss) private var dismiss
    @State private var showsPicker = false
    @State private var reauthorizingID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("连接你的收藏").font(.system(size: 25, weight: .bold))
                        Text("本机文件夹与外接存储，分开管理。").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(library.sources) { source in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 14) {
                                Image(systemName: "folder").font(.title2).frame(width: 36)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(source.name).font(.headline)
                                    Text(library.statuses[source.id]?.description ?? "检查中")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            HStack(spacing: 10) {
                                Button("重新授权") { reauthorizingID = source.id; showsPicker = true }.buttonStyle(CinemaButtonStyle())
                                Button {
                                    if player.current?.sourceID == source.id { player.close() }
                                    library.remove(source)
                                } label: { Label("移除", systemImage: "minus.circle").frame(minHeight: 46).padding(.horizontal, 16) }
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.65)).buttonStyle(.plain)
                            }
                        }.padding(18).background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 6))
                    }
                    Button("添加目录", systemImage: "plus") { reauthorizingID = nil; showsPicker = true }
                        .buttonStyle(CinemaButtonStyle(prominent: true)).disabled(library.isLoading)
                    Text("在“文件”中选择“我的 iPhone / iPad”或外接存储目录。移除目录只清除关联和索引，原视频保持原样。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
            }.background(AppStyle.background)
            .navigationTitle("文件夹管理").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $showsPicker) {
                FolderPicker(onSelect: { urls in
                    if let id = reauthorizingID {
                        if player.current?.sourceID == id { player.close() }
                        library.reauthorize(id, with: urls)
                    } else { library.add(urls) }
                }, allowsMultipleSelection: reauthorizingID == nil)
            }
        }.tint(.white).presentationDragIndicator(.visible).presentationCornerRadius(14).preferredColorScheme(.dark)
    }
}
