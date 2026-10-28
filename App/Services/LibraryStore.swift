import Foundation
import Combine
import LocalLibraryCore

enum SourceStatus: Equatable {
    case checking, ready, offline(String)
    var isAvailable: Bool { if case .ready = self { return true }; return false }
    var description: String {
        switch self {
        case .checking: return "检查中"
        case .ready: return "可用"
        case .offline(let reason): return reason
        }
    }
}

private struct SourceScan: Sendable {
    let scan: DirectoryScan
    let bookmark: Data?
    let path: String
}

@MainActor final class LibraryStore: ObservableObject {
    @Published private(set) var sources: [FolderSource] = []
    @Published private(set) var videos: [VideoItem] = []
    @Published private(set) var statuses: [UUID: SourceStatus] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var isScanning = false
    @Published private(set) var scanDescription = ""
    @Published var notice: String?
    private let disk = LibraryDiskStore()
    private var revision = 0
    private var scanGeneration = UUID()
    private var scanTask: Task<Void, Never>?

    init() { Task { await restore() } }

    private func restore() async {
        do {
            let saved = try await disk.load()
            sources = saved.sources
            videos = VideoItem.sorted(saved.videos)
            for source in sources { statuses[source.id] = .checking }
        } catch {
            notice = "无法读取本地索引：\(error.localizedDescription)。可以重新添加目录。"
        }
        isLoading = false
        refresh()
    }

    func source(for item: VideoItem) -> FolderSource? { sources.first { $0.id == item.sourceID } }
    func isAvailable(_ item: VideoItem) -> Bool { statuses[item.sourceID]?.isAvailable == true }

    func filtered(_ query: String) -> [VideoItem] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return videos }
        return videos.filter { $0.relativePath.localizedStandardContains(term) }
    }

    func add(_ selected: [URL]) { add(selected, replacing: nil) }

    func reauthorize(_ sourceID: UUID, with selected: [URL]) {
        guard let first = selected.first else { return }
        add([first], replacing: sourceID)
    }

    private func add(_ selected: [URL], replacing replacementID: UUID?) {
        guard !isLoading else { return }
        Task {
            for url in selected {
                do {
                    let source = try await Task.detached(priority: .userInitiated) { () -> FolderSource in
                        let started = url.startAccessingSecurityScopedResource()
                        defer { if started { url.stopAccessingSecurityScopedResource() } }
                        guard url.isFileURL else { throw LibraryFailure.remoteSource }
                        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isUbiquitousItemKey, .volumeIsLocalKey])
                        guard values.isUbiquitousItem != true, values.volumeIsLocal != false else {
                            throw LibraryFailure.remoteSource
                        }
                        guard values.isDirectory == true else { throw LibraryFailure.unavailable }
                        let bookmark = try url.bookmarkData(options: [.minimalBookmark],
                                                          includingResourceValuesForKeys: nil, relativeTo: nil)
                        return FolderSource(name: url.lastPathComponent, bookmark: bookmark, lastKnownPath: url.path)
                    }.value
                    if let replacementID {
                        guard let index = sources.firstIndex(where: { $0.id == replacementID }) else { continue }
                        guard !sources.contains(where: {
                            $0.id != replacementID && LocalMediaPath.overlaps(
                                URL(fileURLWithPath: $0.lastKnownPath), URL(fileURLWithPath: source.lastKnownPath))
                        }) else {
                            notice = "该目录与其他已添加目录重叠。"
                            continue
                        }
                        sources[index] = FolderSource(id: replacementID, name: source.name,
                            bookmark: source.bookmark, lastKnownPath: source.lastKnownPath)
                        statuses[replacementID] = .checking
                    // Re-selecting the exact same directory repairs an expired bookmark without losing its ID.
                    } else if let index = sources.firstIndex(where: { $0.lastKnownPath == source.lastKnownPath }) {
                        sources[index].bookmark = source.bookmark
                        statuses[sources[index].id] = .checking
                    } else if sources.contains(where: {
                        LocalMediaPath.overlaps(URL(fileURLWithPath: $0.lastKnownPath),
                                                URL(fileURLWithPath: source.lastKnownPath))
                    }) {
                        notice = "该目录与已添加目录重叠。为避免重复列出视频，请只保留上层或下层目录。"
                    } else {
                        sources.append(source)
                        statuses[source.id] = .checking
                    }
                    persist()
                } catch { notice = error.localizedDescription }
            }
            refresh(restart: true)
        }
    }

    func remove(_ source: FolderSource) {
        sources.removeAll { $0.id == source.id }
        videos.removeAll { $0.sourceID == source.id }
        statuses[source.id] = nil
        persist()
        refresh(restart: true)
    }

    func markUnavailable(_ sourceID: UUID, reason: String) {
        statuses[sourceID] = .offline(reason)
    }

    func refresh(restart: Bool = false) {
        guard !isLoading, !isScanning || restart else { return }
        scanTask?.cancel()
        let generation = UUID()
        scanGeneration = generation
        let selectedSources = sources
        isScanning = !selectedSources.isEmpty
        scanTask = Task {
            for source in selectedSources {
                guard !Task.isCancelled, generation == scanGeneration else { return }
                scanDescription = "正在扫描 \(source.name)"
                let worker = Task.detached(priority: .utility) { () throws -> SourceScan in
                    let lease = try FolderLease(source: source)
                    return try CoordinatedRead.perform(at: lease.url) { directory in
                        let result = try DirectoryScanner.scan(sourceID: source.id, root: directory,
                                                              isCancelled: { Task.isCancelled })
                        return SourceScan(scan: result, bookmark: lease.refreshedBookmark, path: lease.url.path)
                    }
                }
                do {
                    let result = try await withTaskCancellationHandler(operation: {
                        try await worker.value
                    }, onCancel: { worker.cancel() })
                    guard !Task.isCancelled, generation == scanGeneration,
                          let index = sources.firstIndex(where: { $0.id == source.id }) else { return }
                    sources[index].lastKnownPath = result.path
                    if let bookmark = result.bookmark { sources[index].bookmark = bookmark }
                    if result.scan.unreadableCount == 0 {
                        videos.removeAll { $0.sourceID == source.id }
                    } else {
                        // Preserve unverified old entries on partial I/O failure; update every successfully seen file.
                        let seen = Set(result.scan.videos.map(\.id))
                        videos.removeAll { $0.sourceID == source.id && seen.contains($0.id) }
                        notice = "\(source.name)：\(result.scan.unreadableCount) 个位置暂时无法读取，保留未确认的旧索引。"
                    }
                    videos = VideoItem.sorted(videos + result.scan.videos)
                    statuses[source.id] = .ready
                    if result.scan.excludedCloudCount > 0 {
                        notice = "已跳过 \(result.scan.excludedCloudCount) 个云端项目。仅扫描本地视频。"
                    }
                    persist()
                } catch {
                    guard !Task.isCancelled, generation == scanGeneration else { return }
                    statuses[source.id] = .offline("未连接或需要重新授权")
                }
            }
            guard generation == scanGeneration else { return }
            scanDescription = ""
            isScanning = false
        }
    }

    func refreshAndWait() async {
        refresh()
        await scanTask?.value
    }

    private func persist() {
        revision += 1
        let currentRevision = revision
        let snapshot = LibrarySnapshot(sources: sources, videos: videos)
        Task {
            do { try await disk.save(snapshot, revision: currentRevision) }
            catch { notice = "索引保存失败：\(error.localizedDescription)" }
        }
    }
}
