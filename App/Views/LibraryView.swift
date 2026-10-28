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
    @State private var showsPlayback = false

    var body: some View {
        GeometryReader { geometry in
            let items = library.filtered(query)
            let columnWidth = max(1, (geometry.size.width - 60) / 3)
            VStack(spacing: 0) {
                header
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索视频或文件夹", text: $query)
                        .font(.subheadline).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .accessibilityLabel("清除搜索")
                    }
                }
                .padding(12).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 18).padding(.bottom, 20)
                if library.statuses.values.contains(where: { if case .offline = $0 { return true }; return false }) {
                    Button { showsFolders = true } label: {
                        Label("部分目录未连接", systemImage: "externaldrive.badge.exclamationmark")
                            .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18).padding(.bottom, 12)
                    }.foregroundStyle(.orange)
                }
                if items.isEmpty {
                    emptyLibrary
                } else {
                    ScrollView {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(0..<3, id: \.self) { column in
                                LazyVStack(spacing: 20) {
                                    ForEach(stride(from: column, to: items.count, by: 3).map { items[$0] }) { item in
                                        if let source = library.source(for: item) {
                                            VideoPoster(item: item, source: source, thumbnails: thumbnails,
                                                        width: columnWidth, available: library.isAvailable(item)) {
                                                guard library.isAvailable(item) else {
                                                    library.notice = "请连接存储设备并刷新，或在目录管理中重新授权。"
                                                    return
                                                }
                                                player.select(item, from: items)
                                                showsPlayback = true
                                            }
                                        }
                                    }
                                }.frame(width: columnWidth)
                            }
                        }
                        .padding(.horizontal, 18).padding(.bottom, 28)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable { await library.refreshAndWait() }
                }
                if library.isScanning {
                    Text(library.scanDescription).font(.caption2).foregroundStyle(.secondary).padding(.vertical, 6)
                }
            }
            .background(AppStyle.background)
        }
        .sheet(isPresented: $showsPicker) { FolderPicker(onSelect: library.add) }
        .sheet(isPresented: $showsFolders) { FolderManager(library: library, player: player, thumbnails: thumbnails) }
        .fullScreenCover(isPresented: $showsPlayback, onDismiss: player.close) {
            PlaybackScreen(library: library, player: player, thumbnails: thumbnails, volume: volume)
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
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Vela Player").font(.system(size: 28, weight: .bold)).tracking(-0.8)
                Text("视频资料库 · \(library.videos.count)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if library.isScanning { ProgressView().controlSize(.small) }
            Button { showsPicker = true } label: {
                Image(systemName: "folder.badge.plus").font(.system(size: 20)).frame(width: 40, height: 44)
            }.accessibilityLabel("添加视频目录").disabled(library.isLoading)
            Button { showsFolders = true } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 22)).frame(width: 36, height: 44)
            }.accessibilityLabel("目录与设置")
        }
        .foregroundStyle(.white).padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 22)
    }

    @ViewBuilder private var emptyLibrary: some View {
        if library.isLoading {
            ProgressView("正在读取资料库").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if library.sources.isEmpty {
            ContentUnavailableView {
                Label("你的私人影院", systemImage: "play.rectangle.on.rectangle")
            } description: {
                Text("选择本机或外接存储中的视频目录\n封面与视频都留在本地")
            } actions: {
                Button("添加视频目录", systemImage: "folder.badge.plus") { showsPicker = true }
                    .buttonStyle(.borderedProminent).tint(AppStyle.accent).foregroundStyle(.black)
            }
        } else if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ContentUnavailableView(library.isScanning ? "正在查找视频" : "目录里还没有视频", systemImage: "film",
                                   description: Text("在目录设置中刷新或添加其他视频目录。"))
        }
    }
}

private struct VideoPoster: View {
    let item: VideoItem
    let source: FolderSource
    @ObservedObject var thumbnails: ThumbnailService
    let width: CGFloat
    let available: Bool
    let action: () -> Void
    @State private var image: UIImage?

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.065))
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: width, height: width * 1.5).clipped()
                    } else {
                        Image(systemName: "film").font(.system(size: 26, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.22)).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.28)], startPoint: .center, endPoint: .bottom)
                    Text((item.fileName as NSString).pathExtension.uppercased())
                        .font(.system(size: 8, weight: .semibold)).tracking(0.5)
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4)).padding(6)
                }
                .frame(width: width, height: width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if !available {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.caption)
                            .padding(7).background(.black.opacity(0.7), in: Circle()).foregroundStyle(.orange).padding(5)
                    }
                }
                Text((item.fileName as NSString).deletingPathExtension)
                    .font(.system(size: 12, weight: .medium)).lineLimit(2).truncationMode(.middle)
                    .foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(item.fileName)
        .task(id: item.cacheIdentity + String(thumbnails.epoch) + String(source.bookmark.hashValue) + String(available)) {
            image = nil
            image = await thumbnails.image(for: item, source: source)
        }
        .onDisappear { image = nil }
    }
}

private struct PlaybackScreen: View {
    @ObservedObject var library: LibraryStore
    @ObservedObject var player: PlayerController
    @ObservedObject var thumbnails: ThumbnailService
    let volume: SystemVolume
    @Environment(\.dismiss) private var dismiss
    @State private var prefersEmbedded = false
    @State private var showsFolders = false

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let expanded = player.isFullscreen || (landscape && !prefersEmbedded)
            let sideWidth = min(340, max(260, geometry.size.width * 0.31))
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    PlayerPanel(player: player, volume: volume, expanded: expanded,
                        chooseFolder: { showsFolders = true }, manageFolders: { showsFolders = true },
                        close: close, toggleFullscreen: { toggleFullscreen(expanded) })
                        .frame(maxWidth: .infinity)
                        .frame(height: expanded ? nil : min(geometry.size.width * 9 / 16, geometry.size.height * 0.48))
                        .frame(maxHeight: expanded ? .infinity : nil)
                    if !expanded { playlist }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if expanded && player.showsPlaylist { playlist.frame(width: sideWidth) }
            }
            .background(.black)
            .ignoresSafeArea(.container, edges: expanded ? .all : [])
            .statusBarHidden(expanded)
            .persistentSystemOverlays(expanded ? .hidden : .automatic)
            .onChange(of: landscape) { _, wide in
                if !wide { player.isFullscreen = false; prefersEmbedded = false }
            }
        }
        .overlay(alignment: .topLeading) {
            SystemVolumeView(volume: volume).frame(width: 1, height: 1).opacity(0.01).allowsHitTesting(false)
        }
        .sheet(isPresented: $showsFolders) { FolderManager(library: library, player: player, thumbnails: thumbnails) }
        .interactiveDismissDisabled()
    }

    private var playlist: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("播放列表").font(.headline)
                Text("\(player.queue.items.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
            }.padding(.horizontal, 20).padding(.vertical, 18)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(player.queue.items.enumerated()), id: \.element.id) { index, item in
                            Button { player.select(item, from: player.queue.items) } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.055))
                                        if player.current?.id == item.id {
                                            Image(systemName: "waveform").foregroundStyle(AppStyle.accent)
                                        } else {
                                            Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }.frame(width: 42, height: 48)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text((item.fileName as NSString).deletingPathExtension)
                                            .font(.subheadline).lineLimit(2)
                                            .foregroundStyle(player.current?.id == item.id ? AppStyle.accent : .white)
                                        Text(item.subdirectory.isEmpty ? (item.fileName as NSString).pathExtension.uppercased() : item.subdirectory)
                                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(10).background(player.current?.id == item.id ? AppStyle.accent.opacity(0.07) : .clear,
                                                        in: RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain).id(item.id).disabled(!library.isAvailable(item))
                        }
                    }.padding(.horizontal, 10).padding(.bottom, 20)
                }
                .onAppear { if let id = player.current?.id { proxy.scrollTo(id, anchor: .center) } }
            }
        }.background(AppStyle.background)
    }

    private func toggleFullscreen(_ expanded: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            player.isFullscreen = !expanded
            prefersEmbedded = expanded
        }
        requestOrientation(expanded ? .portrait : .landscapeRight)
    }

    private func close() {
        requestOrientation(.portrait)
        dismiss()
    }

    private func requestOrientation(_ orientation: UIInterfaceOrientationMask) {
        guard UIDevice.current.userInterfaceIdiom == .phone,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
        var controller = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        controller?.setNeedsUpdateOfSupportedInterfaceOrientations()
        DispatchQueue.main.async {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { _ in
                // The layout changes immediately even when iOS refuses a rotation request.
            }
        }
    }
}
