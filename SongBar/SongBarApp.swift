import SwiftUI

@main
struct SongBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var spotifyAuthViewModel = SpotifyAuthViewModel()

    var body: some Scene {
        Settings {
            SongBarSettingsView(auth: spotifyAuthViewModel)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = NowPlayingViewModel()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(viewModel: viewModel)
    }
}
