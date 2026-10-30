#if DEBUG
import Foundation
import LocalLibraryCore

/// Used only by UI automation; never changes a normal launch's library.
enum UITestSupport {
    static func prepareIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing"),
              !ProcessInfo.processInfo.arguments.contains("-ui-testing-reuse-library"),
              let clip = Bundle.main.url(forResource: "ui-preview", withExtension: "mp4") else { return }
        do {
            let manager = FileManager.default
            let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let root = documents.appendingPathComponent("UITestLibrary", isDirectory: true)
            // UI automation owns this fixture; discard demo media left by an ordinary launch.
            if manager.fileExists(atPath: root.path) { try manager.removeItem(at: root) }
            let large = ProcessInfo.processInfo.arguments.contains("-ui-testing-large-library")
            try manager.createDirectory(at: large ? root : root.appendingPathComponent("二级目录/三级目录"), withIntermediateDirectories: true)
            var names = ["开场.mp4", "二级目录/片段二.mp4", "二级目录/三级目录/片段三.mp4"]
            if large {
                names = (1...100).flatMap { group in
                    (1...30).map { String(format: "第%03d组/视频%03d.mp4", group, $0) }
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-long-title") {
                names.append("二级目录/风景纪实 第一集 山川与城市的光影旅程.mp4")
            }
            let sharedClip = root.appendingPathComponent(".fixture.mp4")
            if large { try manager.copyItem(at: clip, to: sharedClip) }
            for name in names {
                let file = root.appendingPathComponent(name)
                if !manager.fileExists(atPath: file.path) {
                    try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if large { try manager.linkItem(at: sharedClip, to: file) }
                    else { try manager.copyItem(at: clip, to: file) }
                }
            }
            let source = FolderSource(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "本机测试", bookmark: try root.bookmarkData(options: [.minimalBookmark]), lastKnownPath: root.path)
            let scan = try DirectoryScanner.scan(sourceID: source.id, root: root)
            let offline = FolderSource(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "离线硬盘", bookmark: Data(), lastKnownPath: documents.appendingPathComponent("DisconnectedDrive").path)
            let saved = VideoItem(sourceID: offline.id, relativePath: "已索引/离线片段.mp4", byteCount: 1, modifiedAt: .distantPast)
            // Keep the stress fixture deterministic without changing real directory read order.
            let indexed = large ? scan.videos.sorted { $0.relativePath < $1.relativePath } : scan.videos
            let snapshot = LibrarySnapshot(sources: [source, offline], videos: indexed + [saved])
            let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("LocalFrame", isDirectory: true)
            try manager.createDirectory(at: support, withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: support.appendingPathComponent("library-v1.json"), options: .atomic)
        } catch { assertionFailure("UI fixture setup failed: \(error)") }
    }
}
#endif
