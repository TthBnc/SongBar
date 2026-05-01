import SwiftUI

struct ActionsRow: View {
    let viewModel: NowPlayingViewModel

    var body: some View {
        if #available(macOS 26, *) {
            glassActionsRow
        } else {
            fallbackActionsRow
        }
    }

    // MARK: - macOS 26+ Liquid Glass action row

    @available(macOS 26, *)
    private var glassActionsRow: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                // Open Spotify — de-emphasized, icon-only with tooltip
                Button {
                    Task { await viewModel.openSpotify() }
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .help("Open Spotify")
                .accessibilityLabel("Open Spotify")

                Spacer()

                // Open Track — icon + short label
                Button {
                    Task { await viewModel.openCurrentTrack() }
                } label: {
                    Label("Track", systemImage: "link")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                .disabled(!viewModel.nowPlaying.hasShareableTrack)
                .accessibilityLabel("Open Track in Spotify")

                // Copy Link — icon + short label, tinted when copied
                Button {
                    viewModel.copyShareURL()
                } label: {
                    Label(
                        viewModel.copyConfirmation ? "Copied" : "Copy",
                        systemImage: viewModel.copyConfirmation ? "checkmark" : "doc.on.doc"
                    )
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.copyConfirmation)
                }
                .glassEffect(
                    viewModel.copyConfirmation
                        ? Glass.regular.tint(.green).interactive()
                        : Glass.regular.interactive(),
                    in: .capsule
                )
                .disabled(!viewModel.nowPlaying.hasShareableTrack)
                .accessibilityLabel(viewModel.copyConfirmation ? "Copied!" : "Copy Link")
            }
        }
    }

    // MARK: - macOS 14/15 fallback action row

    private var fallbackActionsRow: some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.openSpotify() }
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("Open Spotify")
            .accessibilityLabel("Open Spotify")

            Spacer()

            Button {
                Task { await viewModel.openCurrentTrack() }
            } label: {
                Label("Track", systemImage: "link")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.nowPlaying.hasShareableTrack)
            .accessibilityLabel("Open Track in Spotify")

            Button {
                viewModel.copyShareURL()
            } label: {
                Label(
                    viewModel.copyConfirmation ? "Copied" : "Copy",
                    systemImage: viewModel.copyConfirmation ? "checkmark" : "doc.on.doc"
                )
                .font(.caption.weight(.medium))
                .animation(.easeInOut(duration: 0.2), value: viewModel.copyConfirmation)
            }
            .buttonStyle(.bordered)
            .tint(viewModel.copyConfirmation ? .green : .accentColor)
            .disabled(!viewModel.nowPlaying.hasShareableTrack)
            .accessibilityLabel(viewModel.copyConfirmation ? "Copied!" : "Copy Link")
        }
    }
}
