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
            if let artwork = viewModel.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
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
            EqualizerBars()
                .frame(width: 11, height: 12)
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
    private let barCount = 4
    private let barWidth: CGFloat = 2
    private let spacing: CGFloat = 1
    private let minHeight: CGFloat = 3

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { context in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule()
                        .frame(width: barWidth, height: barHeight(for: i, at: context.date))
                }
            }
        }
    }

    private func barHeight(for index: Int, at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate * 5.5
        let phase = Double(index) * 0.9
        let normalized = (sin(t + phase) + 1) * 0.5
        let maxHeight: CGFloat = 12
        return minHeight + CGFloat(normalized) * (maxHeight - minHeight)
    }
}
