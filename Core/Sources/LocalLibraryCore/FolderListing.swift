import Foundation

public struct LibraryFolder: Identifiable, Equatable, Sendable {
    public let path: String
    public let videoCount: Int
    public var id: String { path }
    public var name: String { (path as NSString).lastPathComponent }
}

/// Derives browseable folders from the saved index, including disconnected roots.
/// Component boundaries prevent `Season 1` from including `Season 10`.
public struct FolderListing: Sendable {
    public let folders: [LibraryFolder]
    public let videos: [VideoItem]
    public let descendants: [VideoItem]

    public init(sourceID: UUID, path: String = "", items: [VideoItem]) {
        let prefix = path.isEmpty ? "" : path + "/"
        let scoped = items.filter { $0.sourceID == sourceID && $0.relativePath.hasPrefix(prefix) }
        descendants = scoped
        videos = scoped.filter { !$0.relativePath.dropFirst(prefix.count).contains("/") }
        var order: [String] = []
        var counts: [String: Int] = [:]
        for item in scoped {
            let components = item.relativePath.dropFirst(prefix.count).split(separator: "/")
            guard components.count > 1, let first = components.first else { continue }
            let child = prefix + first
            if counts[child] == nil { order.append(child) }
            counts[child, default: 0] += 1
        }
        folders = order.map { LibraryFolder(path: $0, videoCount: counts[$0] ?? 0) }
    }
}
