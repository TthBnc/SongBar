import SwiftUI
import AppKit

struct ErrorBanner: View {
    let availability: SpotifyAvailability

    var body: some View {
        switch availability {
        case .notInstalled:
            bannerRow(
                icon: "exclamationmark.triangle",
                message: "Spotify is not installed.",
                action: nil,
                tint: .orange
            )
        case .notRunning:
            bannerRow(
                icon: "exclamationmark.circle",
                message: "Spotify is not open.",
                action: nil,
                tint: .secondary
            )
        case .automationDenied:
            bannerRow(
                icon: "lock.shield",
                message: "SongBar does not have permission to control Spotify.",
                action: ("Open Settings", openAutomationSettings),
                tint: .red
            )
        case .unknown:
            bannerRow(
                icon: "questionmark.circle",
                message: "Checking Spotify\u{2026}",
                action: nil,
                tint: .secondary
            )
        case .ok, .noActiveTrack:
            EmptyView()
        }
    }

    @ViewBuilder
    private func bannerRow(
        icon: String,
        message: String,
        action: (String, () -> Void)?,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 18, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                if let (label, handler) = action {
                    Button(label, action: handler)
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(tint)
                        .accessibilityLabel(label)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func openAutomationSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
