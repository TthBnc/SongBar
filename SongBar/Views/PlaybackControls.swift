import SwiftUI

struct PlaybackControls: View {
    let viewModel: NowPlayingViewModel

    private var isPlaying: Bool {
        viewModel.nowPlaying.playbackState == .playing
    }

    private let sideSize: CGFloat = 52
    private let centerSize: CGFloat = 66

    var body: some View {
        HStack(spacing: 20) {
            sideButton(
                systemImage: "backward.fill",
                accessibility: "Previous track"
            ) {
                Task { await viewModel.previous() }
            }

            playPauseButton

            sideButton(
                systemImage: "forward.fill",
                accessibility: "Next track"
            ) {
                Task { await viewModel.next() }
            }
        }
    }

    // MARK: - Center play/pause: solid white prominent

    private var playPauseButton: some View {
        Button {
            Task { await viewModel.playPause() }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.black)
                    .offset(x: isPlaying ? 0 : 1.5)
            }
            .frame(width: centerSize, height: centerSize)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.nowPlaying.controlsEnabled)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }

    // MARK: - Side buttons (prev / next): dark glass circles

    @ViewBuilder
    private func sideButton(
        systemImage: String,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        if #available(macOS 26, *) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: sideSize, height: sideSize)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .buttonStyle(.plain)
            .disabled(!viewModel.nowPlaying.controlsEnabled)
            .accessibilityLabel(accessibility)
        } else {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(PanelMetrics.elevatedSurface)
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: sideSize, height: sideSize)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.nowPlaying.controlsEnabled)
            .accessibilityLabel(accessibility)
        }
    }
}
