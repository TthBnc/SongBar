import SwiftUI

struct ProgressSlider: View {
    @Bindable var viewModel: NowPlayingViewModel

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { viewModel.displayPosition },
            set: { viewModel.updateSeekDrag(to: $0) }
        )
    }

    private var isDisabled: Bool {
        viewModel.nowPlaying.duration <= 0 || !viewModel.nowPlaying.controlsEnabled
    }

    var body: some View {
        let displayedPosition = viewModel.displayPosition

        VStack(spacing: 8) {
            Slider(
                value: sliderBinding,
                in: 0...max(viewModel.nowPlaying.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        viewModel.beginSeekDrag(at: viewModel.displayPosition)
                    } else {
                        let target = viewModel.displayPosition
                        Task { await viewModel.endSeekDrag(at: target) }
                    }
                }
            )
            .tint(.white)
            .opacity(viewModel.isSeekPending ? 0.86 : 1)
            .disabled(isDisabled)
            .accessibilityLabel("Playback position")
            .accessibilityValue(TimeFormatter.format(seconds: displayedPosition))
            .animation(
                viewModel.isDraggingSeek ? nil : .spring(response: 0.2, dampingFraction: 0.82),
                value: displayedPosition
            )
            .animation(.easeOut(duration: 0.16), value: viewModel.isSeekPending)

            HStack {
                Text(TimeFormatter.format(seconds: displayedPosition))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: displayedPosition))
                Spacer()
                Text(TimeFormatter.format(seconds: viewModel.nowPlaying.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
