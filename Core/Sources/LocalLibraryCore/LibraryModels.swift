import Foundation

public struct FolderSource: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var bookmark: Data
    public var lastKnownPath: String

    public init(id: UUID = UUID(), name: String, bookmark: Data, lastKnownPath: String) {
        self.id = id
        self.name = name
        self.bookmark = bookmark
        self.lastKnownPath = lastKnownPath
    }
}

public struct VideoItem: Codable, Identifiable, Equatable, Sendable {
    public let sourceID: UUID
    public let relativePath: String
    public let byteCount: Int64
    public let modifiedAt: Date

    public var id: String { sourceID.uuidString + "/" + relativePath }
    public var fileName: String { (relativePath as NSString).lastPathComponent }
    public var subdirectory: String {
        let directory = (relativePath as NSString).deletingLastPathComponent
        return directory == "." ? "" : directory
    }
    public var cacheIdentity: String {
        id + "|" + String(byteCount) + "|" + String(modifiedAt.timeIntervalSince1970)
    }

    public init(sourceID: UUID, relativePath: String, byteCount: Int64, modifiedAt: Date) {
        self.sourceID = sourceID
        self.relativePath = relativePath
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
    }

}

public enum LibraryReadOrder {
    /// Keeps each scan's enumeration order and the order in which roots are scanned.
    public static func merging(_ scanned: [VideoItem], sourceID: UUID, into existing: [VideoItem],
                               sourceOrder: [UUID], keepUnseen: Bool) -> [VideoItem] {
        let seen = Set(scanned.map(\.id))
        let preserved = keepUnseen ? existing.filter { $0.sourceID == sourceID && !seen.contains($0.id) } : []
        return sourceOrder.flatMap { id in
            id == sourceID ? scanned + preserved : existing.filter { $0.sourceID == id }
        }
    }
}

public struct PlaybackActivity: Sendable {
    private var lastSeconds: Double?
    private var advancedAt: TimeInterval?
    public init() {}
    public mutating func reset() { lastSeconds = nil; advancedAt = nil }
    @discardableResult public mutating func update(seconds: Double, at time: TimeInterval) -> Bool {
        guard seconds.isFinite, time.isFinite else { return false }
        let advanced = seconds > (lastSeconds ?? 0) + 0.01
        lastSeconds = seconds
        if advanced { advancedAt = time }
        return advanced
    }
    public func hasRecentProgress(at time: TimeInterval, tolerance: TimeInterval = 1) -> Bool {
        guard let advancedAt else { return false }
        return time >= advancedAt && time - advancedAt < tolerance
    }
}

public struct LibrarySnapshot: Codable, Sendable {
    public var schemaVersion: Int
    public var sources: [FolderSource]
    public var videos: [VideoItem]

    public init(sources: [FolderSource] = [], videos: [VideoItem] = []) {
        schemaVersion = 1
        self.sources = sources
        self.videos = videos
    }
}

public enum LibraryFailure: LocalizedError {
    case invalidPath
    case unavailable
    case remoteSource
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .invalidPath: return "文件路径无效，请重新扫描目录。"
        case .unavailable: return "无法访问文件或存储设备。请检查外接设备是否连接，并刷新目录。"
        case .remoteSource: return "仅支持设备本地和外接存储目录，不读取 iCloud 或网络文件。"
        case .permissionDenied: return "目录授权已失效，请重新选择该目录。"
        }
    }
}

public enum LocalMediaPath {
    public static func directoryPath(_ url: URL) -> String {
        var path = url.standardizedFileURL.resolvingSymlinksInPath().path
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }
    public static let videoExtensions: Set<String> = [
        "mp4", "m4v", "mov", "mkv", "avi", "webm", "mpg", "mpeg",
        "ts", "m2ts", "mts", "3gp", "flv", "wmv"
    ]

    public static func resolve(_ relativePath: String, under root: URL) throws -> URL {
        guard root.isFileURL, !relativePath.isEmpty, !relativePath.hasPrefix("/"),
              !relativePath.contains("\0"),
              !relativePath.split(separator: "/", omittingEmptySubsequences: false)
                .contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }) else {
            throw LibraryFailure.invalidPath
        }
        let base = URL(fileURLWithPath: directoryPath(root), isDirectory: true)
        let prefix = directoryPath(base) == "/" ? "/" : directoryPath(base) + "/"
        let file = base.appendingPathComponent(relativePath).standardizedFileURL
        guard file.path.hasPrefix(prefix),
              file.resolvingSymlinksInPath().path == file.path,
              videoExtensions.contains(file.pathExtension.lowercased()) else {
            throw LibraryFailure.invalidPath
        }
        return file
    }

    public static func overlaps(_ lhs: URL, _ rhs: URL) -> Bool {
        let a = directoryPath(lhs)
        let b = directoryPath(rhs)
        return a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/")
    }
}

/// A queue is captured when a row is selected, so typing a search never changes playback mid-session.
public struct PlaybackQueue: Sendable {
    public private(set) var items: [VideoItem] = []
    public private(set) var index: Int?
    public var current: VideoItem? { index.flatMap { items.indices.contains($0) ? items[$0] : nil } }
    public var hasNext: Bool { index.map { $0 + 1 < items.count } ?? false }
    public var hasPrevious: Bool { index.map { $0 > 0 } ?? false }

    public init() {}

    public mutating func select(_ item: VideoItem, from items: [VideoItem]) {
        self.items = items
        index = items.firstIndex(where: { $0.id == item.id })
    }

    @discardableResult public mutating func advance() -> VideoItem? {
        guard let currentIndex = index, hasNext else { return nil }
        index = currentIndex + 1
        return current
    }

    @discardableResult public mutating func previous() -> VideoItem? {
        guard let currentIndex = index, hasPrevious else { return nil }
        index = currentIndex - 1
        return current
    }
}
