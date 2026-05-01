import SwiftUI

struct NowPlayingPanel: View {
    @Bindable var viewModel: NowPlayingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let availability = viewModel.nowPlaying.availability

            if availability != .ok && availability != .noActiveTrack {
                ErrorBanner(availability: availability)
                    .padding(.bottom, 16)
            }

            HStack {
                Spacer(minLength: 0)
                ArtworkView(image: viewModel.artwork, size: 160)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 22)

            if availability == .ok {
                metadataRow
                    .padding(.bottom, 18)
                ProgressSlider(viewModel: viewModel)
                    .padding(.bottom, 18)
            } else if availability == .noActiveTrack {
                emptyStateView
                    .padding(.bottom, 18)
            }

            HStack {
                Spacer(minLength: 0)
                PlaybackControls(viewModel: viewModel)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 22)

            ActionsRow(viewModel: viewModel)
                .padding(.bottom, 14)

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
        .padding(20)
        .frame(width: 360)
        .onAppear {
            Task { await viewModel.refresh() }
        }
    }

    // MARK: - Title block

    private var metadataRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = viewModel.nowPlaying.title {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if let artist = viewModel.nowPlaying.artist {
                Text(artist)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if let album = viewModel.nowPlaying.album {
                Text(album)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nothing playing")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start a track in Spotify to see it here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
    }
}
