import SwiftUI

@main
struct SongBarApp: App {
    @State private var viewModel = NowPlayingViewModel()

    var body: some Scene {
        MenuBarExtra(viewModel.menuBarTitle) {
            NowPlayingPanel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
