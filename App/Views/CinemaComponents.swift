import SwiftUI
import LocalLibraryCore

struct CinemaSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
            VStack(spacing: 0) { content }
                .background(AppStyle.panel, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

struct CinemaRow: View {
    let title: String
    let symbol: String
    var subtitle: String? = nil
    var disclosure = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 21, weight: .regular))
                .frame(width: 28).foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 6)
            if disclosure { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
        }.padding(18).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).contentShape(Rectangle())
    }
}

struct CinemaDivider: View {
    var body: some View { Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5).padding(.leading, 60) }
}

struct CinemaButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .semibold))
            .foregroundStyle(prominent ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(prominent ? .white : AppStyle.elevated, in: RoundedRectangle(cornerRadius: 4))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

/// A real local first frame, reused by collection and folder artwork.
struct LibraryArtwork: View {
    let item: VideoItem?
    @ObservedObject var library: LibraryStore
    @ObservedObject var thumbnails: ThumbnailService
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppStyle.elevated
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    Image(systemName: "film.stack").font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.12))
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .accessibilityHidden(true)
        .task(id: (item?.cacheIdentity ?? "empty") + String(thumbnails.epoch)
              + String(item.flatMap { library.source(for: $0) }?.bookmark.hashValue ?? 0)
              + String(item.map { library.isAvailable($0) } ?? false)) {
            guard let item, let source = library.source(for: item) else { image = nil; return }
            image = await thumbnails.image(for: item, source: source, allowDecode: library.isAvailable(item))
        }.onDisappear { image = nil }
    }
}
