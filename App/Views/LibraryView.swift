import SwiftUI
import LocalLibraryCore

struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    @ObservedObject var player: PlayerController
    @ObservedObject var thumbnails: ThumbnailService
    let volume: SystemVolume
    @Environment(\.scenePhase) private var scenePhase
    @State private var query = ""
    @State private var showsPicker = false
    @State private var showsFolders = false
    @State private var embeddedOverride = false

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let expanded = player.current != nil && (player.isFullscreen || (landscape && !embeddedOverride))
            let sideWidth = min(360, max(280, geometry.size.width * 0.33))
            let playerWidth = geometry.size.width - (expanded && player.showsPlaylist ? sideWidth : 0)
            VStack(spacing: 0) {
                if !expanded { header }
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        PlayerPanel(player: player, volume: volume, expanded: expanded,
                                    chooseFolder: { showsPicker = true }, manageFolders: { showsFolders = true },
                                    toggleFullscreen: { toggleFullscreen(expanded: expanded) })
                            .frame(height: expanded ? nil : min(playerWidth * 9 / 16, geometry.size.height * 0.44))
                        if !expanded { playlist }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if expanded && player.showsPlaylist {
                        Divider()
                        playlist.frame(width: sideWidth)
                    }
                }
            }
            .background(AppStyle.background)
            .statusBarHidden(expanded)
            .persistentSystemOverlays(expanded ? .hidden : .automatic)
            .onChange(of: landscape) { _, wide in
                embeddedOverride = false
                if !wide { player.isFullscreen = false }
            }
        }
        .overlay(alignment: .topLeading) {
            SystemVolumeView(volume: volume).frame(width: 1, height: 1).opacity(0.01).allowsHitTesting(false)
        }
        .sheet(isPresented: $showsPicker) { FolderPicker(onSelect: library.add) }
        .sheet(isPresented: $showsFolders) {
            FolderManager(library: library, player: player, thumbnails: thumbnails)
        }
        .alert("提示", isPresented: Binding(get: { library.notice != nil }, set: { if !$0 { library.notice = nil } })) {
            Button("知道了", role: .cancel) { library.notice = nil }
        } message: { Text(library.notice ?? "") }
        .onChange(of: scenePhase) { _, phase in
            player.setAppActive(phase == .active)
            if phase == .active { library.refresh() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Vela Player").font(.title2.bold())
                Text("OFFLINE CINEMA").font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(2.5).foregroundStyle(AppStyle.accent)
            }
            Spacer()
            if library.isScanning { ProgressView().controlSize(.small).accessibilityLabel(library.scanDescription) }
            Button { showsPicker = true } label: { Image(systemName: "folder.badge.plus").frame(width: 40, height: 40) }
                .accessibilityLabel("添加目录").disabled(library.isLoading)
            Button { showsFolders = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 40, height: 40) }
                .accessibilityLabel("目录与缓存设置")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private var playlist: some View {
        let items = library.filtered(query)
        return VStack(spacing: 0) {
            HStack {
                Text("播放列表").font(.headline)
                Text("\(items.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Button { library.refresh() } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 40, height: 36)
                }.disabled(library.isScanning).accessibilityLabel("刷新目录")
            }
            .padding(.horizontal, 18).padding(.top, 8)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索文件名或目录", text: $query)
                    .font(.subheadline).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .accessibilityLabel("清除搜索")
                }
            }
            .padding(11).background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 18).padding(.bottom, 10)
            if library.statuses.values.contains(where: { if case .offline = $0 { return true }; return false }) {
                Button { showsFolders = true } label: {
                    Label("部分目录未连接，点击检查", systemImage: "externaldrive.badge.exclamationmark")
                        .font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.foregroundStyle(.orange).background(.orange.opacity(0.08))
            }
            if items.isEmpty {
                if library.isLoading {
                    ProgressView("正在读取索引").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if library.sources.isEmpty {
                    ContentUnavailableView {
                        Label("选择一个视频目录", systemImage: "folder")
                    } description: {
                        Text("自动查找所有子目录中的视频\n支持本机与外接存储")
                    } actions: {
                        Button("添加目录") { showsPicker = true }.buttonStyle(.bordered)
                    }
                } else if !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ContentUnavailableView(library.isScanning ? "正在扫描视频" : "没有找到视频",
                                           systemImage: "film", description: Text("检查目录内容，或下拉刷新列表。"))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { item in
                            if let source = library.source(for: item) {
                                VideoRow(item: item, source: source, thumbnails: thumbnails,
                                         selected: player.current?.id == item.id,
                                         available: library.isAvailable(item)) {
                                    if library.isAvailable(item) { player.select(item, from: items) }
                                    else {
                                        library.notice = "该目录暂不可用。请连接存储设备并刷新，或在目录管理中重新授权。"
                                    }
                                }
                            }
                        }
                    }.padding(.horizontal, 10).padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await library.refreshAndWait() }
            }
            if library.isScanning {
                Text(library.scanDescription).font(.caption2).foregroundStyle(.secondary).padding(.vertical, 5)
            }
        }
        .background(AppStyle.background)
    }

    private func toggleFullscreen(expanded: Bool) {
        embeddedOverride = expanded
        player.isFullscreen = !expanded
        guard UIDevice.current.userInterfaceIdiom == .phone,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: expanded ? .portrait : .landscapeRight)) { _ in
            // If rotation is unavailable, the same button still expands within the current orientation.
        }
    }
}

private struct VideoRow: View {
    let item: VideoItem
    let source: FolderSource
    @ObservedObject var thumbnails: ThumbnailService
    let selected: Bool
    let available: Bool
    let action: () -> Void
    @State private var image: UIImage?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.05))
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 100, height: 60).clipped()
                    } else {
                        Image(systemName: "film").foregroundStyle(.white.opacity(0.2)).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    Text((item.fileName as NSString).pathExtension.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 3)).padding(4)
                }
                .frame(width: 100, height: 60).clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.fileName).font(.subheadline.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? AppStyle.accent : .white).lineLimit(2)
                    Text(([source.name, item.subdirectory].filter { !$0.isEmpty }).joined(separator: " / "))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Text(available ? ByteCountFormatter.string(fromByteCount: item.byteCount, countStyle: .file) : "目录未连接")
                        .font(.caption2.monospacedDigit()).foregroundStyle(available ? Color.secondary : .orange)
                }
                Spacer(minLength: 0)
                if selected { Image(systemName: "play.fill").font(.caption).foregroundStyle(AppStyle.accent) }
            }
            .padding(9).background(selected ? AppStyle.accent.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.fileName + (selected ? "，当前视频" : ""))
        .task(id: item.cacheIdentity + String(thumbnails.epoch) + String(source.bookmark.hashValue) + String(available)) {
            image = nil
            image = await thumbnails.image(for: item, source: source)
        }
        .onDisappear { image = nil }
    }
}
