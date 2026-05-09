import SwiftUI

@main
struct SongBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI App protocol requires at least one Scene. LSUIElement keeps
        // it from showing. Settings is the lightest valid choice.
        Settings { EmptyView() }
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
