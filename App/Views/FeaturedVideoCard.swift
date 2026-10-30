import SwiftUI
import LocalLibraryCore

struct FeaturedVideoCard: View {
    let item: VideoItem
    let source: FolderSource
    @ObservedObject var thumbnails: ThumbnailService
    let height: CGFloat
    let play: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var image: UIImage?
    @State private var showsInfo = false

    var body: some View {
        ZStack(alignment: sizeClass == .regular ? .bottomLeading : .bottom) {
            GeometryReader { geometry in
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    LinearGradient(colors: [AppStyle.elevated, AppStyle.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }.accessibilityHidden(true)
            LinearGradient(stops: [.init(color: .black.opacity(0.1), location: 0),
                                   .init(color: .clear, location: 0.35),
                                   .init(color: .black.opacity(0.45), location: 0.62),
                                   .init(color: AppStyle.background.opacity(0.95), location: 0.93),
                                   .init(color: AppStyle.background, location: 1)], startPoint: .top, endPoint: .bottom)
            if sizeClass == .regular {
                LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
            }
            VStack(alignment: sizeClass == .regular ? .leading : .center, spacing: 14) {
                HStack(spacing: 6) {
                    Text("V").font(.system(size: 20, weight: .black).width(.condensed)).foregroundStyle(AppStyle.accent)
                    Text("本 地 精 选").font(.system(size: 10, weight: .semibold)).tracking(2)
                }.foregroundStyle(.white.opacity(0.85))
                Text((item.fileName as NSString).deletingPathExtension.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: sizeClass == .regular ? 46 : 35, weight: .black).width(.condensed))
                    .lineLimit(2).minimumScaleFactor(0.75)
                    .multilineTextAlignment(sizeClass == .regular ? .leading : .center)
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.5), radius: 8, y: 3)
                HStack(spacing: 8) {
                    Text(source.name).lineLimit(1)
                    Circle().fill(AppStyle.accent).frame(width: 3, height: 3)
                    Text((item.fileName as NSString).pathExtension.uppercased())
                }.font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 10) {
                    Button(action: play) { Label("播放", systemImage: "play.fill").frame(maxWidth: .infinity).frame(height: 42) }
                        .foregroundStyle(.black).background(.white, in: RoundedRectangle(cornerRadius: 4))
                        .accessibilityIdentifier("home.featured.play")
                    Button { showsInfo = true } label: { Label("详细信息", systemImage: "info.circle").frame(maxWidth: .infinity).frame(height: 42) }
                        .foregroundStyle(.white).background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                        .accessibilityIdentifier("home.featured.info")
                }.font(.system(size: 15, weight: .bold)).buttonStyle(.plain).padding(.top, 4)
            }
            .frame(maxWidth: sizeClass == .regular ? 440 : 370)
            .padding(.horizontal, sizeClass == .regular ? 40 : 28).padding(.bottom, 32)
        }.frame(height: height).clipped()
            .accessibilityElement(children: .contain).accessibilityIdentifier("home.featured")
            .task(id: item.cacheIdentity + String(thumbnails.epoch) + String(source.bookmark.hashValue)) {
                image = await thumbnails.image(for: item, source: source, featured: true)
            }
            .onDisappear { image = nil }
            .sheet(isPresented: $showsInfo) { VideoInfoSheet(item: item, source: source, status: "可用") }
    }
}
