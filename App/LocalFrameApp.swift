import SwiftUI

@main struct LocalFrameApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var library: LibraryStore
    @StateObject private var player: PlayerController
    @StateObject private var thumbnails = ThumbnailService()
    @StateObject private var volume = SystemVolume()

    init() {
        #if DEBUG
        UITestSupport.prepareIfRequested()
        #endif
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
    static let accent = Color(red: 229 / 255, green: 9 / 255, blue: 20 / 255)
    static let background = Color(red: 0.031, green: 0.031, blue: 0.031)
    static let panel = Color(red: 0.075, green: 0.075, blue: 0.075)
    static let elevated = Color(red: 0.13, green: 0.13, blue: 0.13)
}
