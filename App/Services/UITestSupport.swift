#if DEBUG
import Foundation
import LocalLibraryCore

/// Used only by UI automation; never changes a normal launch's library.
enum UITestSupport {
    static func prepareIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing"),
              let clip = Bundle.main.url(forResource: "ui-preview", withExtension: "mp4") else { return }
        do {
            let manager = FileManager.default
            let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let root = documents.appendingPathComponent("UITestLibrary", isDirectory: true)
            // UI automation owns this fixture; discard demo media left by an ordinary launch.
            if manager.fileExists(atPath: root.path) { try manager.removeItem(at: root) }
            try manager.createDirectory(at: root.appendingPathComponent("二级目录/三级目录"), withIntermediateDirectories: true)
            var names = ["开场.mp4", "二级目录/片段二.mp4", "二级目录/三级目录/片段三.mp4"]
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-long-title") {
                names.append("二级目录/风景纪实 第一集 山川与城市的光影旅程.mp4")
            }
            for name in names {
                let file = root.appendingPathComponent(name)
                if !manager.fileExists(atPath: file.path) { try manager.copyItem(at: clip, to: file) }
            }
            let source = FolderSource(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "本机测试", bookmark: try root.bookmarkData(options: [.minimalBookmark]), lastKnownPath: root.path)
            let scan = try DirectoryScanner.scan(sourceID: source.id, root: root)
            let offline = FolderSource(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "离线硬盘", bookmark: Data(), lastKnownPath: documents.appendingPathComponent("DisconnectedDrive").path)
            let saved = VideoItem(sourceID: offline.id, relativePath: "已索引/离线片段.mp4", byteCount: 1, modifiedAt: .distantPast)
            let snapshot = LibrarySnapshot(sources: [source, offline], videos: scan.videos + [saved])
            let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("LocalFrame", isDirectory: true)
            try manager.createDirectory(at: support, withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: support.appendingPathComponent("library-v1.json"), options: .atomic)
        } catch { assertionFailure("UI fixture setup failed: \(error)") }
    }
}
#endif
