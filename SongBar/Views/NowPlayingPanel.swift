import SwiftUI

struct NowPlayingPanel: View {
    @Bindable var viewModel: NowPlayingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hard-error banner (notInstalled / notRunning / automationDenied / unknown)
            let availability = viewModel.nowPlaying.availability
            if availability != .ok && availability != .noActiveTrack {
                ErrorBanner(availability: availability)
                    .padding(.bottom, 12)
            }

            // Artwork — centered, with layered shadow treatment
            HStack {
                Spacer()
                ArtworkView(image: viewModel.artwork)
                Spacer()
            }
            .padding(.bottom, 16)

            // Track metadata or soft-state message
            if availability == .ok {
                metadataBlock
                    .padding(.bottom, 12)
            } else if availability == .noActiveTrack {
                emptyStateView
                    .padding(.bottom, 12)
            }

            // Progress slider — only when a track is active
            if availability == .ok {
                ProgressSlider(viewModel: viewModel)
                    .padding(.bottom, 12)
            }

            // Playback controls — centered
            HStack {
                Spacer()
                PlaybackControls(viewModel: viewModel)
                Spacer()
            }
            .padding(.bottom, 16)

            // Open / share actions
            ActionsRow(viewModel: viewModel)
                .padding(.bottom, 12)

            // Footer: quit button
            Divider()
                .padding(.bottom, 8)

            HStack {
                Spacer()
                Button("Quit SongBar") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.tertiary)
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

    // MARK: - Metadata

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let title = viewModel.nowPlaying.title {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
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
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note.list")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nothing playing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Start a track in Spotify to see it here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
}
