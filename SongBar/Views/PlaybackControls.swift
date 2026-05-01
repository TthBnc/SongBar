import SwiftUI

struct PlaybackControls: View {
    let viewModel: NowPlayingViewModel

    private var isPlaying: Bool {
        viewModel.nowPlaying.playbackState == .playing
    }

    var body: some View {
        HStack(spacing: 24) {
            Button {
                Task { await viewModel.previous() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.nowPlaying.controlsEnabled)
            .accessibilityLabel("Previous track")

            Button {
                Task { await viewModel.playPause() }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.nowPlaying.controlsEnabled)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button {
                Task { await viewModel.next() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.nowPlaying.controlsEnabled)
            .accessibilityLabel("Next track")
        }
    }
}
