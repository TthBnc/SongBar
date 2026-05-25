import SwiftUI

enum PanelMetrics {
    static let width: CGFloat = 310
    static let padding: CGFloat = 20
    static let artworkSize: CGFloat = 230
    static let artworkRadius: CGFloat = 14
    static let controlRadius: CGFloat = 14
    static let actionHeight: CGFloat = 48
    static let shareButtonWidth: CGFloat = 46
    static let metadataIconWidth: CGFloat = 17
    static let dividerColor = Color.white.opacity(0.08)
    static let elevatedSurface = Color.white.opacity(0.08)
    static let elevatedStroke = Color.white.opacity(0.07)
}

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
                ArtworkView(image: viewModel.artwork, size: PanelMetrics.artworkSize)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 18)

            if availability == .ok {
                metadataRow
                    .padding(.bottom, 16)
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
            .padding(.bottom, 24)

            Divider()
                .overlay(PanelMetrics.dividerColor)
                .padding(.bottom, 14)

            ActionsRow(viewModel: viewModel)
                .padding(.bottom, 14)

            Divider()
                .overlay(PanelMetrics.dividerColor)
                .padding(.bottom, 10)

            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Quit SongBar")
            }
        }
        .padding(PanelMetrics.padding)
        .frame(width: PanelMetrics.width)
        .onAppear {
            Task { await viewModel.refresh() }
        }
    }

    // MARK: - Title block

    private var metadataRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let title = viewModel.nowPlaying.title {
                MetadataLine(
                    icon: "music.note",
                    text: title,
                    font: .title2.weight(.bold),
                    textStyle: .primary,
                    lineLimit: 2,
                    accessibilityLabel: "Song title, \(title)"
                )
            }
            if let artist = viewModel.nowPlaying.artist {
                MetadataLine(
                    icon: "person.fill",
                    text: artist,
                    font: .body,
                    textStyle: .primary.opacity(0.85),
                    lineLimit: 1,
                    accessibilityLabel: "Artist, \(artist)"
                )
            }
            if let album = viewModel.nowPlaying.album {
                MetadataLine(
                    icon: "opticaldisc",
                    text: album,
                    font: .subheadline,
                    textStyle: .secondary,
                    lineLimit: 1,
                    accessibilityLabel: "Album, \(album)"
                )
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

private struct MetadataLine: View {
    let icon: String
    let text: String
    let font: Font
    let textStyle: AnyShapeStyle
    let lineLimit: Int
    let accessibilityLabel: String

    init<S: ShapeStyle>(
        icon: String,
        text: String,
        font: Font,
        textStyle: S,
        lineLimit: Int,
        accessibilityLabel: String
    ) {
        self.icon = icon
        self.text = text
        self.font = font
        self.textStyle = AnyShapeStyle(textStyle)
        self.lineLimit = lineLimit
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: PanelMetrics.metadataIconWidth, alignment: .center)
                .accessibilityHidden(true)

            Text(text)
                .font(font)
                .foregroundStyle(textStyle)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
