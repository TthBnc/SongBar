import SwiftUI

struct PlaybackControls: View {
    let viewModel: NowPlayingViewModel

    private var isPlaying: Bool {
        viewModel.nowPlaying.playbackState == .playing
    }

    var body: some View {
        if #available(macOS 26, *) {
            glassControls
        } else {
            fallbackControls
        }
    }

    // MARK: - macOS 26+ Liquid Glass controls

    @available(macOS 26, *)
    private var glassControls: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.previous() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 38, height: 38)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .disabled(!viewModel.nowPlaying.controlsEnabled)
                .accessibilityLabel("Previous track")

                Button {
                    Task { await viewModel.playPause() }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 50, height: 50)
                }
                .glassEffect(.regular.tint(.primary.opacity(0.1)).interactive(), in: .circle)
                .disabled(!viewModel.nowPlaying.controlsEnabled)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button {
                    Task { await viewModel.next() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 38, height: 38)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .disabled(!viewModel.nowPlaying.controlsEnabled)
                .accessibilityLabel("Next track")
            }
        }
    }

    // MARK: - macOS 14/15 fallback controls

    private var fallbackControls: some View {
        HStack(spacing: 16) {
            Button {
                Task { await viewModel.previous() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.nowPlaying.controlsEnabled)
            .accessibilityLabel("Previous track")

            Button {
                Task { await viewModel.playPause() }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 50, height: 50)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.nowPlaying.controlsEnabled)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button {
                Task { await viewModel.next() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.nowPlaying.controlsEnabled)
            .accessibilityLabel("Next track")
        }
    }
}
