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
            // 5 fps frame counter on the view model drives the bar heights.
            // Only ticks while playing — paused/stopped/etc burn zero menu
            // bar updates. TimelineView is intentionally NOT used here.
            EqualizerBars(frame: viewModel.equalizerFrame)
                .frame(width: 12, height: 13)
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

private struct EqualizerBars: View {
    let frame: Int

    private let barCount = 4
    private let barWidth: CGFloat = 2
    private let spacing: CGFloat = 1
    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 12

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(Color.primary)
                    .frame(width: barWidth, height: barHeight(for: i))
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let t = Double(frame) * 0.55
        let phase = Double(index) * 0.95
        let normalized = (sin(t + phase) + 1) * 0.5
        return minHeight + CGFloat(normalized) * (maxHeight - minHeight)
    }
}
