import SwiftUI
import LocalLibraryCore

enum LibraryTab: String, CaseIterable, Hashable {
    case home, categories, folders, settings

    var title: String {
        switch self {
        case .home: return "首页"
        case .categories: return "分类"
        case .folders: return "文件夹"
        case .settings: return "设置"
        }
    }
    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .categories: return "square.grid.2x2.fill"
        case .folders: return "folder.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct LibraryTabBar: View {
    @Binding var selection: LibraryTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LibraryTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol).font(.system(size: 20, weight: .semibold))
                        Text(tab.title).font(.system(size: 10, weight: .semibold))
                    }.foregroundStyle(selection == tab ? .white : .white.opacity(0.45))
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(tab.title)
                    .accessibilityIdentifier("tab.\(tab.rawValue)")
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }.frame(maxWidth: 700).frame(maxWidth: .infinity)
            .background(AppStyle.background.opacity(0.98))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5) }
    }
}

enum VideoCollection: Hashable {
    case all, available, offline, largeFiles, format(String)

    var id: String {
        switch self {
        case .all: return "all"
        case .available: return "available"
        case .offline: return "offline"
        case .largeFiles: return "largeFiles"
        case .format(let value): return "format.\(value)"
        }
    }
    var title: String {
        switch self {
        case .all: return "全部视频"
        case .available: return "可播放"
        case .offline: return "离线索引"
        case .largeFiles: return "大文件"
        case .format(let value): return value
        }
    }
    var subtitle: String {
        switch self {
        case .all: return "跨文件夹浏览"
        case .available: return "当前已连接的目录"
        case .offline: return "保留的文件记录"
        case .largeFiles: return "500 MB 及以上"
        case .format: return "按视频文件格式归类"
        }
    }
    var symbol: String {
        switch self {
        case .all: return "film.stack"
        case .available: return "play.rectangle"
        case .offline: return "externaldrive.badge.exclamationmark"
        case .largeFiles: return "internaldrive"
        case .format: return "film"
        }
    }
    @MainActor func items(in library: LibraryStore) -> [VideoItem] {
        switch self {
        case .all: return library.videos
        case .available: return library.videos.filter { library.isAvailable($0) }
        case .offline:
            return library.videos.filter {
                if case .offline = library.statuses[$0.sourceID] { return true }
                return false
            }
        case .largeFiles: return library.videos.filter { $0.byteCount >= 500 * 1024 * 1024 }
        case .format(let value):
            return library.videos.filter { ($0.fileName as NSString).pathExtension.uppercased() == value }
        }
    }
}
