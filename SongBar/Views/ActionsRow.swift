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
        shareLabel
            .overlay {
                SharePickerTriggerView(
                    shareURL: shareURL,
                    accessibilityLabel: "Share track"
                )
                .frame(width: PanelMetrics.shareButtonWidth, height: PanelMetrics.actionHeight)
            }
        .accessibilityLabel("Share track")
        .accessibilityHint(shareURL == nil ? "Unavailable for this track" : "")
        .help("Share")
    }
}

private struct SharePickerTriggerView: NSViewRepresentable {
    let shareURL: URL?
    let accessibilityLabel: String

    func makeNSView(context: Context) -> SharePickerTriggerNSView {
        let view = SharePickerTriggerNSView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: SharePickerTriggerNSView, context: Context) {
        nsView.shareURL = shareURL
        nsView.setAccessibilityLabel(accessibilityLabel)
    }
}

private final class SharePickerTriggerNSView: NSView, NSSharingServicePickerDelegate {
    var shareURL: URL? {
        didSet {
            if shareURL == nil {
                closeActivePicker()
            }
            setAccessibilityEnabled(shareURL != nil)
        }
    }

    private var activePicker: NSSharingServicePicker?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        if activePicker != nil {
            closeActivePicker()
            return
        }

        guard let shareURL else { return }
        let picker = NSSharingServicePicker(items: [shareURL as NSURL])
        picker.delegate = self
        activePicker = picker
        picker.show(relativeTo: bounds, of: self, preferredEdge: .minY)
    }

    private func closeActivePicker() {
        if let activePicker {
            activePicker.close()
        }
        activePicker = nil
    }

    func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        didChoose service: NSSharingService?
    ) {
        if sharingServicePicker === activePicker {
            activePicker = nil
        }
    }
}
