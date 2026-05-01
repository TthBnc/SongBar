import SwiftUI

struct ActionsRow: View {
    let viewModel: NowPlayingViewModel

    var body: some View {
        HStack(spacing: 8) {
            ActionCard(
                icon: "link",
                title: "Track",
                subtitle: "Open in Spotify",
                enabled: viewModel.nowPlaying.hasShareableTrack
            ) {
                Task { await viewModel.openCurrentTrack() }
            }

            ActionCard(
                icon: viewModel.copyConfirmation ? "checkmark" : "doc.on.doc",
                title: viewModel.copyConfirmation ? "Copied" : "Copy Link",
                subtitle: "Share Song",
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
    }

    private var cardContent: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .modifier(ActionCardBackground())
        .opacity(enabled ? 1 : 0.45)
    }
}

private struct ActionCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        } else {
            content
                .background(
                    Color.white.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        }
    }
}

private struct ShareCard: View {
    let shareURL: URL?
    let title: String?
    let artist: String?

    private var shareLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Share")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text("Options")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
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
            .accessibilityLabel("Share, options")
        } else {
            shareLabel
                .accessibilityLabel("Share, options")
        }
    }
}
