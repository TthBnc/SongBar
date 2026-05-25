import SwiftUI

@main
struct SongBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SongBarSettingsView(auth: appDelegate.spotifyAuthViewModel)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let spotifyAuthViewModel = SpotifyAuthViewModel()
    let viewModel = NowPlayingViewModel()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(viewModel: viewModel, auth: spotifyAuthViewModel)
    }
}
