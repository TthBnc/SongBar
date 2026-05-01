import SwiftUI

@main
struct SongBarApp: App {
    @State private var viewModel = NowPlayingViewModel()

    var body: some Scene {
        MenuBarExtra {
            NowPlayingPanel(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let viewModel: NowPlayingViewModel

    var body: some View {
        HStack(spacing: 5) {
            if let composite = viewModel.menuBarArtwork {
                Image(nsImage: composite)
            }
            Text(viewModel.menuBarTitle)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch viewModel.nowPlaying.playbackState {
        case .playing: return "Now playing: \(viewModel.menuBarTitle)"
        case .paused:  return "Paused: \(viewModel.menuBarTitle)"
        default:       return viewModel.menuBarTitle
        }
    }
}

