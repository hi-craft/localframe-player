import SwiftUI
import LocalLibraryCore

struct VideoInfoSheet: View {
    let item: VideoItem
    let source: FolderSource?
    let status: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VideoInfoContent(item: item, source: source, status: status)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.tint(.white).presentationDragIndicator(.visible).presentationCornerRadius(14).preferredColorScheme(.dark)
    }
}

struct VideoInfoContent: View {
    let item: VideoItem
    let source: FolderSource?
    let status: String
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text("V").font(.system(size: 24, weight: .black).width(.condensed)).foregroundStyle(AppStyle.accent)
                        Text("本地视频").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                    }
                    Text(item.fileName).font(.system(size: 26, weight: .bold)).textSelection(.enabled)
                    Text((item.fileName as NSString).pathExtension.uppercased())
                        .font(.system(size: 11, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(Rectangle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                }
                CinemaSection(title: "文件详情") {
                    detail("文件大小", value: ByteCountFormatter.string(fromByteCount: item.byteCount, countStyle: .file))
                    CinemaDivider()
                    detail("修改时间", value: item.modifiedAt == .distantPast ? "未知" : item.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                }
                CinemaSection(title: "文件位置") {
                    detail("根文件夹", value: source?.name ?? "目录已移除")
                        .accessibilityElement(children: .combine).accessibilityIdentifier("video.info.source")
                    CinemaDivider()
                    detail("目录状态", value: status)
                    CinemaDivider()
                    VStack(alignment: .leading, spacing: 9) {
                        Text("相对路径").font(.caption).foregroundStyle(.secondary)
                        Text(item.relativePath).font(.subheadline).textSelection(.enabled).accessibilityIdentifier("video.info.path")
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    UIPasteboard.general.string = item.relativePath
                    copied = true
                } label: { Label(copied ? "已复制相对路径" : "复制相对路径", systemImage: copied ? "checkmark" : "doc.on.doc") }
                    .buttonStyle(CinemaButtonStyle())
            }.padding(24).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
        }.background(AppStyle.background).navigationTitle("视频信息").navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 20) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value).multilineTextAlignment(.trailing)
        }.font(.subheadline).padding(18)
    }
}
