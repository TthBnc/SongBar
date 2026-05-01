import SwiftUI

struct ActionsRow: View {
    let viewModel: NowPlayingViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.openSpotify() }
            } label: {
                Label("Open Spotify", systemImage: "arrow.up.forward.app")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Open Spotify")

            Button {
                Task { await viewModel.openCurrentTrack() }
            } label: {
                Label("Open Track", systemImage: "link")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.nowPlaying.hasShareableTrack)
            .accessibilityLabel("Open Track")

            Button {
                viewModel.copyShareURL()
            } label: {
                Label(
                    viewModel.copyConfirmation ? "Copied!" : "Copy Link",
                    systemImage: viewModel.copyConfirmation ? "checkmark" : "doc.on.doc"
                )
                .font(.caption)
                .animation(.default, value: viewModel.copyConfirmation)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.nowPlaying.hasShareableTrack)
            .accessibilityLabel(viewModel.copyConfirmation ? "Copied!" : "Copy Link")
        }
    }
}
