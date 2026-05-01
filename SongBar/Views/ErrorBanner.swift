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
                action: nil
            )
        case .notRunning:
            bannerRow(
                icon: "exclamationmark.circle",
                message: "Spotify is not open.",
                action: nil
            )
        case .automationDenied:
            bannerRow(
                icon: "lock.shield",
                message: "SongBar does not have permission to control Spotify.",
                action: ("Open Settings", openAutomationSettings)
            )
        case .unknown:
            bannerRow(
                icon: "questionmark.circle",
                message: "Checking Spotify…",
                action: nil
            )
        case .ok, .noActiveTrack:
            EmptyView()
        }
    }

    @ViewBuilder
    private func bannerRow(
        icon: String,
        message: String,
        action: (String, () -> Void)?
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                if let (label, handler) = action {
                    Button(label, action: handler)
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .accessibilityLabel(label)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func openAutomationSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
