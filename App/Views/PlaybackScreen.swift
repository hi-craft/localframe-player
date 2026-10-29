import SwiftUI
import LocalLibraryCore

struct PlaybackScreen: View {
    @ObservedObject var library: LibraryStore
    @ObservedObject var player: PlayerController
    @ObservedObject var thumbnails: ThumbnailService
    let volume: SystemVolume
    let closePlayback: () -> Void
    @State private var prefersEmbedded = false
    @State private var showsFolders = false
    @State private var isClosing = false
    @State private var inspectedItem: VideoItem?

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            // On iPhone the system rotation owns the size transition. Changing
            // this before the window rotates briefly embeds a tiny landscape
            // player and starts a second animation over UIKit's rotation.
            let expanded = UIDevice.current.userInterfaceIdiom == .phone
                ? landscape : player.isFullscreen || (landscape && !prefersEmbedded)
            let sideWidth = min(340, max(290, geometry.size.width * 0.31))
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    PlayerPanel(player: player, volume: volume, expanded: expanded,
                        chooseFolder: { showsFolders = true }, manageFolders: { showsFolders = true },
                        close: close, toggleFullscreen: { toggleFullscreen(expanded) })
                        .frame(maxWidth: .infinity)
                        .frame(height: expanded ? nil : min(geometry.size.width * 9 / 16, geometry.size.height * 0.48))
                        .frame(maxHeight: expanded ? .infinity : nil)
                    if !expanded { playlist(compact: false) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if expanded && player.showsPlaylist {
                    playlist(compact: true)
                        .padding(.trailing, geometry.safeAreaInsets.trailing)
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                        .frame(width: sideWidth + geometry.safeAreaInsets.trailing)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .background(.black)
            .ignoresSafeArea(.container, edges: expanded ? .all : [])
            .statusBarHidden(expanded)
            .persistentSystemOverlays(expanded ? .hidden : .automatic)
            .onChange(of: landscape) { _, wide in
                if !wide { player.isFullscreen = false; prefersEmbedded = false }
            }
        }
        .background {
            PlaybackPresentationCoordinator(closeRequested: isClosing, close: closePlayback)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            SystemVolumeView(volume: volume).frame(width: 1, height: 1).opacity(0.01).allowsHitTesting(false)
        }
        .sheet(isPresented: $showsFolders) { FolderManager(library: library, player: player, thumbnails: thumbnails) }
        .sheet(item: $inspectedItem) { item in
            VideoInfoSheet(item: item, source: library.source(for: item),
                           status: library.statuses[item.sourceID]?.description ?? "目录已移除")
        }
        .interactiveDismissDisabled()
        .onAppear { OrientationPolicy.shared.enterPlayer() }
    }

    private func playlist(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("播放列表").font(.system(size: 22, weight: .bold))
                    Spacer()
                    Text("\(player.queue.items.count) 部视频").font(.caption).foregroundStyle(.secondary)
                }
                if let item = player.current {
                    HStack(spacing: 8) {
                        Rectangle().fill(AppStyle.accent).frame(width: 3, height: 12)
                        Text((item.fileName as NSString).deletingPathExtension).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Spacer(minLength: 0)
                        Text("正在播放").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 18)
            Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5).padding(.horizontal, 20)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(player.queue.items) { item in
                                HStack(spacing: 12) {
                                    PlaylistThumbnail(item: item, source: library.source(for: item),
                                        thumbnails: thumbnails, available: library.isAvailable(item),
                                        isCurrent: player.current?.id == item.id, width: compact ? 88 : 120)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text((item.fileName as NSString).deletingPathExtension)
                                            .font(.system(size: 14, weight: player.current?.id == item.id ? .bold : .medium)).lineLimit(2)
                                            .foregroundStyle(.white)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .accessibilityIdentifier("playlist.title.\(item.relativePath)")
                                        Text(item.subdirectory.isEmpty ? (item.fileName as NSString).pathExtension.uppercased() : item.subdirectory)
                                            .font(.caption2).foregroundStyle(.secondary).lineLimit(compact ? 2 : 1)
                                            .accessibilityIdentifier("playlist.subtitle.\(item.relativePath)")
                                    }.frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
                                    if !compact {
                                        Image(systemName: player.current?.id == item.id ? "waveform" : "play.circle")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundStyle(player.current?.id == item.id ? AppStyle.accent : .white.opacity(0.45))
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 12)
                                .background(player.current?.id == item.id ? AppStyle.elevated.opacity(0.7) : .clear,
                                            in: RoundedRectangle(cornerRadius: 4))
                                .contentShape(Rectangle())
                                // A tap recognizer cancels once the finger drags;
                                // a row button can otherwise also activate when
                                // the simultaneous drawer swipe finishes.
                                .onTapGesture { select(item) }
                                .accessibilityElement(children: .contain)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { select(item) }
                                .id(item.id).disabled(!library.isAvailable(item))
                                .accessibilityIdentifier("playlist.\(item.relativePath)")
                                .contextMenu {
                                    Button("视频信息", systemImage: "info.circle") { inspectedItem = item }
                                }
                        }
                    }.padding(.horizontal, 8).padding(.top, 10).padding(.bottom, 20)
                }
                .accessibilityIdentifier("playback.playlist.scroll")
                .allowsHitTesting(!player.controlsLocked)
                .accessibilityHidden(player.controlsLocked)
                .onAppear { if let id = player.current?.id { proxy.scrollTo(id, anchor: .center) } }
            }
        }.background(AppStyle.background)
            .accessibilityElement(children: .contain).accessibilityIdentifier("playback.playlist")
            .contentShape(Rectangle())
            .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { gesture in
                guard compact, !player.controlsLocked,
                      gesture.translation.width > 55,
                      gesture.translation.width > abs(gesture.translation.height) * 1.2 else { return }
                withAnimation(.easeOut(duration: 0.2)) { player.showsPlaylist = false }
            }, including: compact ? .all : .none)
    }

    private func select(_ item: VideoItem) {
        guard library.isAvailable(item) else { return }
        player.select(item, from: player.queue.items)
    }

    private func toggleFullscreen(_ expanded: Bool) {
        guard !isClosing else { return }
        player.isFullscreen = !expanded
        prefersEmbedded = expanded
        OrientationPolicy.shared.fullscreen(!expanded)
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        OrientationPolicy.shared.showLibrary()
    }
}

private struct PlaylistThumbnail: View {
    let item: VideoItem
    let source: FolderSource?
    @ObservedObject var thumbnails: ThumbnailService
    let available: Bool
    let isCurrent: Bool
    let width: CGFloat
    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.055))
            .frame(width: width, height: width * 9 / 16)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: width, height: width * 9 / 16).clipped()
                } else {
                    Image(systemName: "film").font(.title3).foregroundStyle(.white.opacity(0.25))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isCurrent ? .white.opacity(0.3) : .white.opacity(0.06), lineWidth: 1)
            }
            .overlay(alignment: .bottomTrailing) {
                if isCurrent {
                    Image(systemName: "waveform").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white).padding(5).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                }
            }
            .accessibilityHidden(true)
            .task(id: item.cacheIdentity + String(thumbnails.epoch) + String(source?.bookmark.hashValue ?? 0) + String(available)) {
                guard let source else { image = nil; return }
                image = await thumbnails.image(for: item, source: source, allowDecode: available)
            }
            .onDisappear { image = nil }
    }
}
