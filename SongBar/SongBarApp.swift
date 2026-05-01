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
            if let thumbnail = viewModel.menuBarArtwork {
                Image(nsImage: thumbnail)
            }
            stateIndicator
            Text(viewModel.menuBarTitle)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch viewModel.nowPlaying.playbackState {
        case .playing:
            // A static "now-playing" glyph. We deliberately avoid TimelineView
            // animations here — they force MenuBarExtra to re-snapshot the
            // entire label at the timeline's tick rate and pegged the CPU
            // on macOS 26.
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .semibold))
        case .paused:
            Image(systemName: "pause.fill")
                .font(.system(size: 10, weight: .semibold))
        default:
            EmptyView()
        }
    }

    private var accessibilityLabel: String {
        switch viewModel.nowPlaying.playbackState {
        case .playing: return "Now playing: \(viewModel.menuBarTitle)"
        case .paused:  return "Paused: \(viewModel.menuBarTitle)"
        default:       return viewModel.menuBarTitle
        }
    }
}
