import SwiftUI

struct ActionsRow: View {
    let viewModel: NowPlayingViewModel

    private var canOpenSpotify: Bool {
        viewModel.nowPlaying.availability != .notInstalled
    }

    var body: some View {
        HStack(spacing: 12) {
            ActionCard(
                icon: "macwindow",
                title: "Open",
                subtitle: "Spotify",
                enabled: canOpenSpotify
            ) {
                Task { await viewModel.openSpotify() }
            }

            ActionCard(
                icon: viewModel.copyConfirmation ? "checkmark" : "link",
                title: viewModel.copyConfirmation ? "Copied" : "Copy",
                subtitle: "Link",
                enabled: viewModel.nowPlaying.hasShareableTrack
            ) {
                viewModel.copyShareURL()
            }

            ShareCard(
                shareURL: viewModel.nowPlaying.shareURL,
                title: viewModel.nowPlaying.title,
                artist: viewModel.nowPlaying.artist
            )
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.copyConfirmation)
    }
}

private struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint(enabled ? "" : "Unavailable right now")
    }

    private var cardContent: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.bold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: PanelMetrics.actionHeight)
        .frame(maxWidth: .infinity, minHeight: PanelMetrics.actionHeight)
        .modifier(ActionCardBackground())
        .opacity(enabled ? 1 : 0.45)
    }
}

private struct ActionCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: PanelMetrics.controlRadius))
        } else {
            content
                .background(
                    PanelMetrics.elevatedSurface,
                    in: RoundedRectangle(cornerRadius: PanelMetrics.controlRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PanelMetrics.controlRadius, style: .continuous)
                        .stroke(PanelMetrics.elevatedStroke, lineWidth: 0.5)
                )
        }
    }
}

private struct ShareCard: View {
    let shareURL: URL?
    let title: String?
    let artist: String?

    private var shareLabel: some View {
        ZStack {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.primary)
        }
        .frame(width: PanelMetrics.shareButtonWidth, height: PanelMetrics.actionHeight)
        .modifier(ActionCardBackground())
        .opacity(shareURL == nil ? 0.45 : 1)
    }

    var body: some View {
        if let url = shareURL {
            ShareLink(
                item: url,
                subject: Text(title ?? "Song"),
                message: Text([artist, title].compactMap { $0 }.joined(separator: " — "))
            ) {
                shareLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share track")
            .help("Share")
        } else {
            Button {} label: {
                shareLabel
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Share track")
            .accessibilityHint("Unavailable for this track")
            .help("Share")
        }
    }
}
