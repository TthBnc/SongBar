import AppKit
import SwiftUI

struct ActionsRow: View {
    let viewModel: NowPlayingViewModel

    private var canOpenSpotify: Bool {
        viewModel.nowPlaying.availability != .notInstalled
    }

    var body: some View {
        HStack(spacing: 8) {
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
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
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
    @State private var anchorView: NSView?
    @State private var activePicker: NSSharingServicePicker?

    private var shareLabel: some View {
        ZStack {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(.primary)
        }
        .frame(width: PanelMetrics.shareButtonWidth, height: PanelMetrics.actionHeight)
        .modifier(ActionCardBackground())
        .opacity(shareURL == nil ? 0.45 : 1)
    }

    var body: some View {
        Button {
            presentSharePicker()
        } label: {
            shareLabel
                .overlay {
                    SharePickerAnchorView(anchorView: $anchorView)
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(.plain)
        .disabled(shareURL == nil)
        .accessibilityLabel("Share track")
        .accessibilityHint(shareURL == nil ? "Unavailable for this track" : "")
        .help("Share")
    }

    private func presentSharePicker() {
        guard let shareURL else { return }
        let picker = NSSharingServicePicker(items: [shareText(for: shareURL)])
        activePicker = picker

        if let anchorView {
            picker.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        } else if let contentView = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        }
    }

    private func shareText(for url: URL) -> String {
        let metadata = [artist, title].compactMap(cleaned).joined(separator: " - ")
        if metadata.isEmpty {
            return url.absoluteString
        }
        return "\(metadata)\n\(url.absoluteString)"
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct SharePickerAnchorView: NSViewRepresentable {
    @Binding var anchorView: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            anchorView = view
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            anchorView = nsView
        }
    }
}
