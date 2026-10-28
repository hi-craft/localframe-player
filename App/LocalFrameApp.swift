import SwiftUI

@main struct LocalFrameApp: App {
    @StateObject private var library: LibraryStore
    @StateObject private var player: PlayerController
    @StateObject private var thumbnails = ThumbnailService()
    @StateObject private var volume = SystemVolume()

    init() {
        let store = LibraryStore()
        _library = StateObject(wrappedValue: store)
        _player = StateObject(wrappedValue: PlayerController(library: store))
    }

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library, player: player, thumbnails: thumbnails, volume: volume)
                .preferredColorScheme(.dark)
                .tint(AppStyle.accent)
        }
    }
}

enum AppStyle {
    static let accent = Color(red: 0.48, green: 0.89, blue: 0.73)
    static let background = Color(red: 0.055, green: 0.065, blue: 0.075)
    static let panel = Color(red: 0.09, green: 0.105, blue: 0.12)
}
