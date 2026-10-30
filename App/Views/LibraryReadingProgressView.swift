import SwiftUI

struct LibraryReadingProgressView: View {
    @ObservedObject var library: LibraryStore
    var compact = false
    @State private var sweeping = false

    private var progress: LibraryReadingProgress { library.readingProgress }
    private var allOffline: Bool {
        !library.isScanning && progress.totalSources > 0 && progress.offlineSources == progress.totalSources
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: library.isScanning ? "folder.badge.gearshape" : (allOffline ? "exclamationmark.circle" : "checkmark.circle"))
                    .foregroundStyle(allOffline ? .orange : AppStyle.accent)
                Text(library.isScanning ? library.scanDescription : (allOffline ? "目录暂不可读" : (progress.rebuilding ? "索引重建完成" : "目录读取完成")))
                    .font(.caption.weight(.medium)).lineLimit(1)
                Spacer(minLength: 4)
                Text("\(progress.completedSources)/\(progress.totalSources) 个目录")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            if library.isScanning {
                // The recursive file total is unknown until traversal ends.
                // Show activity and actual counts instead of an invented percentage.
                GeometryReader { geometry in
                    let width = max(0, geometry.size.width)
                    Capsule().fill(.white.opacity(0.07))
                    Capsule().fill(AppStyle.accent).frame(width: width * 0.3)
                        .offset(x: sweeping ? width * 0.7 : 0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: sweeping)
                        .onAppear { sweeping = true }.onDisappear { sweeping = false }
                }.frame(height: 4).clipped()
            } else if !compact {
                ProgressView(value: Double(progress.completedSources), total: Double(max(1, progress.totalSources)))
                    .tint(AppStyle.accent)
            }
            if !compact || library.isScanning {
                Text("已检查 \(progress.inspectedItems) 个项目 · 发现 \(progress.foundVideos) 个视频")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if library.isScanning && !progress.relativeDirectory.isEmpty {
                Text(progress.relativeDirectory).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            } else if !library.isScanning && progress.offlineSources > 0 {
                Text("\(progress.offlineSources) 个离线目录保留原索引")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }.padding(12).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 5))
            .accessibilityElement(children: .combine).accessibilityIdentifier("library.reading-progress")
    }
}
