import SwiftUI

struct NowPlayingPanel: View {
    @Bindable var viewModel: NowPlayingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hard-error banner (notInstalled / notRunning / automationDenied / unknown)
            let availability = viewModel.nowPlaying.availability
            if availability != .ok && availability != .noActiveTrack {
                ErrorBanner(availability: availability)
            }

            // Artwork — always shown so the panel has consistent height
            HStack {
                Spacer()
                ArtworkView(image: viewModel.artwork)
                Spacer()
            }

            // Track metadata or soft-state messages
            if availability == .ok {
                metadataBlock
            } else if availability == .noActiveTrack {
                Text("Nothing is playing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }

            // Progress slider — only meaningful when there is an active track
            if availability == .ok {
                ProgressSlider(viewModel: viewModel)
            }

            // Playback controls — centered
            HStack {
                Spacer()
                PlaybackControls(viewModel: viewModel)
                Spacer()
            }

            // Open / share actions
            ActionsRow(viewModel: viewModel)

            Divider()

            // Quit button — right-aligned, visually separated from controls
            HStack {
                Spacer()
                Button("Quit SongBar") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Quit SongBar")
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            // Polling runs for the whole app lifetime (started in the
            // view model's init). On panel open, jump-refresh so the
            // popover never shows a stale tick.
            Task { await viewModel.refresh() }
        }
    }

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title = viewModel.nowPlaying.title {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if let artist = viewModel.nowPlaying.artist {
                Text(artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if let album = viewModel.nowPlaying.album {
                Text(album)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
