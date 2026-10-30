import SwiftUI
import LocalLibraryCore

private enum LibraryRoute: Hashable {
    case folder(UUID, String)
    case collection(VideoCollection)
}

struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    let player: PlayerController
    @ObservedObject var thumbnails: ThumbnailService
    let volume: SystemVolume
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = LibraryTab.home
    @State private var paths: [LibraryTab: [LibraryRoute]] = [:]
    @State private var query = ""
    @State private var showsSearch = false
    @State private var showsPicker = false
    @State private var showsFolders = false
    @State private var showsPlayback = false
    @State private var reauthorizingID: UUID?
    @FocusState private var searchFocused: Bool

    private var path: Binding<[LibraryRoute]> {
        let tab = selectedTab
        return Binding(get: { paths[tab] ?? [] }, set: { paths[tab] = $0 })
    }

    var body: some View {
        GeometryReader { scene in
            VStack(spacing: 0) {
                NavigationStack(path: path) {
                    Group {
                        switch selectedTab {
                        case .home: home(topInset: scene.safeAreaInsets.top)
                        case .categories: categories
                        case .folders: folders
                        case .settings: SettingsView(thumbnails: thumbnails)
                        }
                    }
                    .navigationDestination(for: LibraryRoute.self) { route in
                        switch route {
                        case .folder(let id, let folderPath):
                            if let source = library.sources.first(where: { $0.id == id }) {
                                FolderBrowser(source: source, path: folderPath, library: library,
                                              thumbnails: thumbnails, select: play, repair: { repair(source) })
                            } else { ContentUnavailableView("目录已移除", systemImage: "folder") }
                        case .collection(let collection): collectionPage(collection)
                        }
                    }
                }
                .id(selectedTab)
                LibraryTabBar(selection: $selectedTab)
            }
            .background(AppStyle.background)
            .tint(.white)
            .sheet(isPresented: $showsPicker) {
                FolderPicker(onSelect: { urls in
                    if let id = reauthorizingID { library.reauthorize(id, with: urls) }
                    else { library.add(urls) }
                }, allowsMultipleSelection: reauthorizingID == nil)
            }
            .sheet(isPresented: $showsFolders) { FolderManager(library: library, player: player, thumbnails: thumbnails) }
            .fullScreenCover(isPresented: $showsPlayback, onDismiss: {
                player.close()
                OrientationPolicy.shared.showLibrary()
            }) {
                PlaybackScreen(library: library, player: player, thumbnails: thumbnails, volume: volume,
                               closePlayback: { showsPlayback = false })
            }
            .alert("提示", isPresented: Binding(get: { library.notice != nil }, set: { if !$0 { library.notice = nil } })) {
                Button("知道了", role: .cancel) { library.notice = nil }
            } message: { Text(library.notice ?? "") }
            .onAppear { OrientationPolicy.shared.showLibrary() }
            .onChange(of: scenePhase) { _, phase in
                player.setAppActive(phase == .active)
                if phase == .active { library.checkAvailability() }
            }
            #if DEBUG
            .onChange(of: library.isLoading, initial: true) { _, loading in
                // Start near the end of the real 3000-item queue without thousands
                // of automation swipes. Release builds never expose this entry.
                if !loading, ProcessInfo.processInfo.arguments.contains("-ui-testing-large-queue-tail"),
                   let item = library.videos.first(where: { $0.relativePath == "第100组/视频028.mp4" }),
                   let source = library.source(for: item) {
                    play(item, items(source))
                }
            }
            #endif
        }
    }

    private func home(topInset: CGFloat) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if showsSearch {
                        VStack(spacing: 16) {
                            HStack {
                                wordmark
                                Spacer()
                                Button("取消") { query = ""; showsSearch = false; searchFocused = false }
                                    .font(.subheadline.weight(.medium)).accessibilityLabel("取消搜索")
                            }.padding(.horizontal, 20)
                            searchField
                        }.padding(.top, topInset + 12).padding(.bottom, 24)
                        let results = library.filtered(query)
                        if results.isEmpty { ContentUnavailableView.search(text: query).padding(.top, 40) }
                        else {
                            sectionHeading(query.isEmpty ? "全部视频" : "搜索结果", count: results.count)
                            VideoGrid(items: results, library: library, thumbnails: thumbnails, select: play)
                                .padding(.horizontal, 20).padding(.top, 18)
                        }
                    } else {
                        if let featured = library.videos.first(where: { library.isAvailable($0) }),
                           let source = library.source(for: featured) {
                            FeaturedVideoCard(item: featured, source: source, thumbnails: thumbnails,
                                              height: heroHeight(in: geometry)) {
                                play(featured, items(source))
                            }.overlay(alignment: .top) {
                                homeNavigation.padding(.top, topInset + 6)
                            }
                        } else {
                            homeNavigation.padding(.top, topInset + 6)
                        }
                        if library.isLoading {
                            ProgressView("正在读取资料库").frame(maxWidth: .infinity).padding(50)
                        } else if library.sources.isEmpty { emptyLibrary }
                        else {
                            VStack(alignment: .leading, spacing: 26) {
                                if library.isScanning {
                                    LibraryReadingProgressView(library: library, compact: true).padding(.horizontal, 20)
                                }
                                if !library.videos.isEmpty { homeLibraryShelf }
                                ForEach(library.sources) { source in sourceSection(source) }
                            }.padding(.top, 8)
                        }
                    }
                }.padding(.bottom, 28)
            }
            .accessibilityIdentifier("home.scroll")
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await library.refreshAndWait(rebuilding: true) }
        }
        // Extend the measured viewport upward, rather than letting its child
        // scroll view grow beyond the measured bottom and underneath the tabs.
        .ignoresSafeArea(.container, edges: .top)
        .background(AppStyle.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func heroHeight(in geometry: GeometryProxy) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return min(max(geometry.size.width * 0.55, 440), geometry.size.height * 0.78)
        }
        return min(max(geometry.size.width * 1.35, 480), geometry.size.height * 0.85)
    }

    private var wordmark: some View {
        Text("VELA").font(.system(size: 25, weight: .black).width(.condensed))
            .tracking(1).foregroundStyle(AppStyle.accent).accessibilityLabel("Vela Player")
    }

    private var homeNavigation: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                wordmark
                Spacer()
                Button { showsSearch = true } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 21, weight: .medium))
                        .frame(width: 40, height: 40)
                }.accessibilityLabel("搜索视频").accessibilityIdentifier("home.search")
                Button { selectedTab = .settings } label: {
                    RoundedRectangle(cornerRadius: 5).fill(AppStyle.accent)
                        .frame(width: 29, height: 29)
                        .overlay { Image(systemName: "person.fill").font(.system(size: 17)).foregroundStyle(.white) }
                        .frame(width: 40, height: 40)
                }.accessibilityLabel("打开设置")
            }
            HStack(spacing: 10) {
                NavigationLink(value: LibraryRoute.collection(.all)) { Text("全部视频") }
                    .accessibilityIdentifier("home.browse.all")
                NavigationLink(value: LibraryRoute.collection(.available)) { Text("可播放") }
                    .accessibilityIdentifier("home.browse.available")
                Menu {
                    ForEach(library.sources) { source in
                        NavigationLink(value: LibraryRoute.folder(source.id, "")) { Text(source.name) }
                            .accessibilityIdentifier("source.\(source.name)")
                    }
                    Button("管理文件夹") { selectedTab = .folders }
                } label: {
                    HStack(spacing: 6) { Text("文件夹"); Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)) }
                }.accessibilityIdentifier("home.sources")
            }
            .font(.system(size: 13, weight: .medium))
            .buttonStyle(HomeFilterStyle())
        }.foregroundStyle(.white).padding(.horizontal, 20).padding(.bottom, 24)
            .background(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.8), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .padding(.top, -90)
            }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索你的片库", text: $query)
                .font(.subheadline).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($searchFocused).accessibilityIdentifier("library.search")
                .task { searchFocused = true }
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .accessibilityLabel("清除搜索")
            }
        }.padding(12).background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 5)).padding(.horizontal, 20)
    }

    private var homeLibraryShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: LibraryRoute.collection(.all)) {
                HStack {
                    Text("你的片库").font(.system(size: 21, weight: .bold)).accessibilityIdentifier("home.library-title")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.foregroundStyle(.white)
            }.buttonStyle(.plain).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 8) {
                    ForEach(Array(library.videos.prefix(12))) { item in
                        if let source = library.source(for: item) {
                            VideoPoster(item: item, source: source, thumbnails: thumbnails,
                                        available: library.isAvailable(item), style: .cover) { play(item, items(source)) }
                                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 180 : 126)
                        }
                    }
                }.padding(.horizontal, 20)
            }
        }
    }

    private var categories: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeading("分类", subtitle: "用你习惯的方式，找到下一部")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                    ForEach([VideoCollection.all, .available, .offline, .largeFiles], id: \.self) { category in
                        categoryTile(category)
                    }
                }.padding(.horizontal, 20)
                if !formats.isEmpty {
                    sectionHeading("按文件格式", count: formats.count)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                        ForEach(formats, id: \.self) { categoryTile(.format($0)) }
                    }.padding(.horizontal, 20)
                }
                Text("分类来自文件信息，目录中的读取顺序保持一致。")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
            }.padding(.vertical, 16)
        }.background(AppStyle.background).toolbar(.hidden, for: .navigationBar)
            .refreshable { await library.refreshAndWait(rebuilding: true) }
    }

    private func categoryTile(_ category: VideoCollection) -> some View {
        let videos = category.items(in: library)
        return NavigationLink(value: LibraryRoute.collection(category)) {
            ZStack(alignment: .bottomLeading) {
                LibraryArtwork(item: videos.first, library: library, thumbnails: thumbnails)
                LinearGradient(colors: [.black.opacity(0.12), .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: category.symbol).font(.system(size: 18))
                        Spacer()
                        Text("\(videos.count)").font(.caption.monospacedDigit())
                    }.foregroundStyle(.white.opacity(0.7))
                    Spacer(minLength: 18)
                    Text(category.title).font(.system(size: 21, weight: .bold)).foregroundStyle(.white)
                    Text(category.subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }.padding(16)
            }.frame(height: 164).clipShape(RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain).accessibilityIdentifier("category.\(category.id)")
    }

    private func collectionPage(_ collection: VideoCollection) -> some View {
        let results = collection.items(in: library)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("\(results.count) 个视频 · \(collection.subtitle)").font(.subheadline).foregroundStyle(.secondary)
                LibraryReadingProgressView(library: library, compact: true)
                if results.isEmpty {
                    ContentUnavailableView("暂无符合条件的视频", systemImage: collection.symbol,
                                           description: Text("添加更多文件夹，或下拉重新读取。"))
                        .accessibilityIdentifier("collection.empty")
                } else { VideoGrid(items: results, library: library, thumbnails: thumbnails, select: play) }
            }.padding(20)
        }.background(AppStyle.background)
            .navigationTitle(collection.title).navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .refreshable { await library.refreshAndWait(rebuilding: true) }
    }

    private var folders: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeading("文件夹", subtitle: "\(library.sources.count) 个连接 · \(library.videos.count) 个视频")
                HStack(spacing: 12) {
                    Button { reauthorizingID = nil; showsPicker = true } label: { Label("添加文件夹", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 12) }
                        .foregroundStyle(.black).background(.white, in: RoundedRectangle(cornerRadius: 4))
                        .accessibilityLabel("添加视频目录").disabled(library.isLoading)
                    Button { showsFolders = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 46, height: 44).background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 7)) }
                        .accessibilityLabel("管理文件夹")
                }.font(.subheadline.weight(.semibold)).buttonStyle(.plain).padding(.horizontal, 20)
                if library.sources.isEmpty { emptyLibrary }
                else {
                    LibraryReadingProgressView(library: library).padding(.horizontal, 20)
                    VStack(spacing: 12) {
                        ForEach(library.sources) { source in
                            NavigationLink(value: LibraryRoute.folder(source.id, "")) {
                                HStack(spacing: 16) {
                                    LibraryArtwork(item: items(source).first, library: library, thumbnails: thumbnails)
                                        .frame(width: 100, height: 80).clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(alignment: .bottomLeading) {
                                            Image(systemName: "folder.fill").font(.system(size: 14)).foregroundStyle(.white)
                                                .padding(6).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 3)).padding(6)
                                        }
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(source.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                                        Text("\(items(source).count) 个视频").font(.caption).foregroundStyle(.secondary)
                                        SourceBadge(status: library.statuses[source.id])
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }.padding(12).background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain).accessibilityIdentifier("source.\(source.name)")
                        }
                    }.padding(.horizontal, 20)
                }
            }.padding(.vertical, 16).padding(.bottom, 24)
        }.background(AppStyle.background).toolbar(.hidden, for: .navigationBar)
            .refreshable { await library.refreshAndWait(rebuilding: true) }
    }

    private func sourceSection(_ source: FolderSource) -> some View {
        let videos = items(source)
        return VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: LibraryRoute.folder(source.id, "")) {
                HStack {
                    Text(source.name).font(.title3.bold()).lineLimit(1)
                    Text("\(videos.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }.foregroundStyle(.white)
            }.padding(.horizontal, 20).buttonStyle(.plain)
            if case .offline = library.statuses[source.id] {
                OfflineFolderBanner(status: library.statuses[source.id], retry: { library.refresh() }, repair: { repair(source) }).padding(.horizontal, 20)
            }
            if videos.isEmpty {
                Text(library.isScanning ? "正在查找本地视频…" : "目录里还没有视频，进入文件夹查看或下拉刷新。")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(Array(videos.prefix(12))) { item in
                            VideoPoster(item: item, source: source, thumbnails: thumbnails, available: library.isAvailable(item), style: .wide) { play(item, videos) }
                                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 236)
                        }
                    }.padding(.horizontal, 20)
                }
            }
        }
    }

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("你的私人影院", systemImage: "play.rectangle.on.rectangle")
        } description: { Text("添加本机或外接存储中的文件夹，打开即播放。") }
          actions: {
            Button("添加视频目录", systemImage: "folder.badge.plus") { reauthorizingID = nil; showsPicker = true }
                .buttonStyle(.borderedProminent).tint(AppStyle.accent).foregroundStyle(.white)
        }.padding(.vertical, 40)
    }

    private var formats: [String] {
        var seen = Set<String>()
        return library.videos.compactMap {
            let value = ($0.fileName as NSString).pathExtension.uppercased()
            return seen.insert(value).inserted ? value : nil
        }
    }
    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }.padding(.horizontal, 20)
    }
    private func sectionHeading(_ title: String, count: Int) -> some View {
        HStack { Text(title).font(.title3.bold()); Text("\(count)").font(.caption).foregroundStyle(.secondary) }.padding(.horizontal, 20)
    }
    private func items(_ source: FolderSource) -> [VideoItem] { library.videos.filter { $0.sourceID == source.id } }
    private func repair(_ source: FolderSource) { reauthorizingID = source.id; showsPicker = true }
    private func play(_ item: VideoItem, _ queue: [VideoItem]) {
        guard library.isAvailable(item) else {
            library.notice = "目录暂时不可读，已保留视频索引。请连接存储设备后刷新，或重新授权该目录。"
            return
        }
        player.select(item, from: queue)
        showsPlayback = true
    }
}

private struct FolderBrowser: View {
    let source: FolderSource
    let path: String
    @ObservedObject var library: LibraryStore
    @ObservedObject var thumbnails: ThumbnailService
    let select: (VideoItem, [VideoItem]) -> Void
    let repair: () -> Void
    @State private var query = ""

    var body: some View {
        let listing = FolderListing(sourceID: source.id, path: path, items: library.videos)
        let searching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let videos = searching ? listing.descendants.filter { $0.relativePath.localizedStandardContains(query) } : listing.videos
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text(path.isEmpty ? "根目录" : source.name + " / " + path)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    Text("\(listing.descendants.count) 个视频").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                if library.isScanning { LibraryReadingProgressView(library: library, compact: true) }
                if case .offline = library.statuses[source.id] {
                    OfflineFolderBanner(status: library.statuses[source.id], retry: { library.refresh() }, repair: repair)
                }
                if !searching && !listing.folders.isEmpty {
                    Text("子文件夹").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                        ForEach(listing.folders) { folder in
                            NavigationLink(value: LibraryRoute.folder(source.id, folder.path)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder").font(.title2).foregroundStyle(.white.opacity(0.7))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(folder.name).font(.subheadline.weight(.medium)).lineLimit(2)
                                        Text("\(folder.videoCount) 个视频").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }.padding(14).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                    .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain).accessibilityIdentifier("folder.\(folder.path)")
                        }
                    }
                }
                if !videos.isEmpty {
                    Text(searching ? "搜索结果 · \(videos.count)" : "本层视频 · \(videos.count)").font(.headline)
                    VideoGrid(items: videos, library: library, thumbnails: thumbnails, select: select)
                } else if searching {
                    ContentUnavailableView.search(text: query)
                } else if listing.folders.isEmpty {
                    ContentUnavailableView("此目录暂无视频", systemImage: "film", description: Text("下拉刷新，或在目录管理中重新授权。"))
                }
            }.padding(20)
        }
        .background(AppStyle.background)
        .navigationTitle(path.isEmpty ? source.name : (path as NSString).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { library.refresh(restart: true, rebuilding: true) } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("刷新目录").disabled(library.isScanning)
            }
        }
        .searchable(text: $query, prompt: "搜索此文件夹及子目录")
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .refreshable { await library.refreshAndWait(rebuilding: true) }
    }
}

private struct SourceBadge: View {
    let status: SourceStatus?
    var body: some View {
        Group {
            switch status {
            case .ready: Label("本地", systemImage: "checkmark.circle.fill").foregroundStyle(.white.opacity(0.8))
            case .partial: Label("部分可读", systemImage: "exclamationmark.circle").foregroundStyle(.orange)
            case .offline: Label("离线", systemImage: "externaldrive.badge.exclamationmark").foregroundStyle(.orange)
            default: Label("检查中", systemImage: "ellipsis.circle").foregroundStyle(.secondary)
            }
        }.font(.system(size: 10, weight: .medium)).labelStyle(.titleAndIcon)
    }
}

private struct OfflineFolderBanner: View {
    let status: SourceStatus?
    let retry: () -> Void
    let repair: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("目录暂不可读 · 索引已保留", systemImage: "externaldrive.badge.exclamationmark")
                .font(.subheadline.weight(.medium)).foregroundStyle(.orange)
            Text(status?.description ?? "请重新连接存储设备或授权此目录。")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 20) {
                Button("重新连接后刷新", action: retry)
                Button("重新授权", action: repair).accessibilityIdentifier("source.reauthorize")
            }.font(.caption.weight(.semibold)).buttonStyle(.borderless)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct VideoGrid: View {
    let items: [VideoItem]
    @ObservedObject var library: LibraryStore
    @ObservedObject var thumbnails: ThumbnailService
    let select: (VideoItem, [VideoItem]) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105, maximum: 210), spacing: 12)], alignment: .leading, spacing: 22) {
            ForEach(items) { item in
                if let source = library.source(for: item) {
                    VideoPoster(item: item, source: source, thumbnails: thumbnails,
                                available: library.isAvailable(item), style: .cover) { select(item, items) }
                }
            }
        }
    }
}

private struct HomeFilterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 14).frame(height: 33)
            .background(.black.opacity(configuration.isPressed ? 0.5 : 0.18), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.65), lineWidth: 0.7))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private enum VideoPosterStyle { case grid, cover, wide }

private struct VideoPoster: View {
    let item: VideoItem
    let source: FolderSource
    @ObservedObject var thumbnails: ThumbnailService
    let available: Bool
    var style = VideoPosterStyle.grid
    let action: () -> Void
    @State private var image: UIImage?
    @State private var showsInfo = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.06))
                    .aspectRatio(style == .wide ? 16.0 / 9 : 2.0 / 3, contentMode: .fit)
                    .overlay {
                        GeometryReader { geometry in
                            if let image {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            } else {
                                Image(systemName: "film").font(.system(size: 30, weight: .ultraLight))
                                    .foregroundStyle(.white.opacity(0.18)).frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if style == .grid {
                            Text((item.fileName as NSString).pathExtension.uppercased())
                                .font(.system(size: 9, weight: .semibold)).tracking(0.4)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 5)).padding(8)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if style != .grid {
                            ZStack(alignment: .bottomLeading) {
                                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                                Text((item.fileName as NSString).deletingPathExtension.replacingOccurrences(of: "_", with: " "))
                                    .font(.system(size: style == .cover ? 14 : 13, weight: .heavy))
                                    .lineLimit(2).multilineTextAlignment(.leading).foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1).padding(10)
                            }
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if !available {
                            Image(systemName: "externaldrive.badge.exclamationmark").font(.caption)
                                .padding(7).background(.black.opacity(0.7), in: Circle()).foregroundStyle(.orange).padding(6)
                        } else if style != .grid {
                            Text("V").font(.system(size: 18, weight: .black).width(.condensed))
                                .foregroundStyle(AppStyle.accent).shadow(color: .black.opacity(0.6), radius: 2).padding(8)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                if style == .grid {
                    Text((item.fileName as NSString).deletingPathExtension)
                    .font(.system(size: 12, weight: .medium)).lineLimit(2).truncationMode(.middle)
                    .foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(item.fileName)
        .accessibilityIdentifier("video.\(item.relativePath)")
        .contextMenu { Button("视频信息", systemImage: "info.circle") { showsInfo = true } }
        .sheet(isPresented: $showsInfo) {
            VideoInfoSheet(item: item, source: source, status: available ? "可用" : "暂不可读，已保留索引")
        }
        .task(id: item.cacheIdentity + String(thumbnails.epoch) + String(source.bookmark.hashValue) + String(available)) {
            image = await thumbnails.image(for: item, source: source, allowDecode: available)
        }
        .onDisappear { image = nil }
    }
}
