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
        VStack(spacing: 4) {
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
            .disabled(isDisabled)
            .tint(.primary.opacity(0.75))
            .accessibilityLabel("Playback position")

            HStack {
                Text(TimeFormatter.format(seconds: viewModel.displayPosition))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Spacer()
                Text(TimeFormatter.format(seconds: viewModel.nowPlaying.duration))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }
}
