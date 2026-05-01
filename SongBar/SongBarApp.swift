import SwiftUI

@main
struct SongBarApp: App {
    @State private var viewModel = NowPlayingViewModel()

    var body: some Scene {
        MenuBarExtra(viewModel.menuBarTitle) {
            NowPlayingPanel(viewModel: viewModel)
                .onAppear {
                    viewModel.start()
                    Task { await viewModel.refresh() }
                }
                .onDisappear {
                    viewModel.stop()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
