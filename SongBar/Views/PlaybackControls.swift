import SwiftUI

struct PlaybackControls: View {
    let viewModel: NowPlayingViewModel

    private var isPlaying: Bool {
        viewModel.displayPlaybackState == .playing
    }

    private var controlsEnabled: Bool {
        viewModel.nowPlaying.controlsEnabled
    }

    private let sideSize: CGFloat = 52
    private let centerSize: CGFloat = 66

    var body: some View {
        HStack(spacing: 20) {
            sideButton(
                systemImage: "backward.fill",
                accessibility: "Previous track",
                isPending: viewModel.isPreviousPending,
                iconShift: -2
            ) {
                Task { await viewModel.previous() }
            }

            playPauseButton

            sideButton(
                systemImage: "forward.fill",
                accessibility: "Next track",
                isPending: viewModel.isNextPending,
                iconShift: 2
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
                    .shadow(
                        color: .black.opacity(viewModel.isPlayPausePending ? 0.38 : 0.3),
                        radius: viewModel.isPlayPausePending ? 9 : 6,
                        x: 0,
                        y: 2
                    )
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.black)
                    .offset(x: isPlaying ? 0 : 1.5)
                    .scaleEffect(viewModel.isPlayPausePending ? 0.88 : 1)
            }
            .frame(width: centerSize, height: centerSize)
            .scaleEffect(viewModel.isPlayPausePending ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!controlsEnabled)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
        .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isPlaying)
        .animation(.spring(response: 0.18, dampingFraction: 0.75), value: viewModel.isPlayPausePending)
    }

    // MARK: - Side buttons (prev / next): dark glass circles

    @ViewBuilder
    private func sideButton(
        systemImage: String,
        accessibility: String,
        isPending: Bool,
        iconShift: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        if #available(macOS 26, *) {
            Button(action: action) {
                sideIcon(systemImage, isPending: isPending, iconShift: iconShift)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .buttonStyle(.plain)
            .disabled(!controlsEnabled)
            .accessibilityLabel(accessibility)
            .scaleEffect(isPending ? 0.94 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isPending)
        } else {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(PanelMetrics.elevatedSurface.opacity(isPending ? 0.95 : 0.72))
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(isPending ? 0.22 : 0.08), lineWidth: 1)
                        }
                    sideIcon(systemImage, isPending: isPending, iconShift: iconShift)
                }
                .frame(width: sideSize, height: sideSize)
                .scaleEffect(isPending ? 0.94 : 1)
            }
            .buttonStyle(.plain)
            .disabled(!controlsEnabled)
            .accessibilityLabel(accessibility)
            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isPending)
        }
    }

    private func sideIcon(
        _ systemImage: String,
        isPending: Bool,
        iconShift: CGFloat
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: sideSize, height: sideSize)
            .offset(x: isPending ? iconShift : 0)
            .scaleEffect(isPending ? 0.9 : 1)
    }
}
