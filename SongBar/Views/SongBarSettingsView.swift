import SwiftUI

struct SongBarSettingsView: View {
    let auth: SpotifyAuthViewModel
    @AppStorage("spotify.clientID") private var spotifyClientID = ""

    private var hasClientID: Bool {
        !spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 22) {
                spotifySection
                accessSection
            }
            .padding(24)

            Spacer(minLength: 0)
        }
        .frame(width: 500)
        .frame(minHeight: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("SongBar")
                    .font(.title3.weight(.semibold))
                Text("Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var spotifySection: some View {
        SettingsSection(title: "Spotify", icon: "music.note") {
            SettingsRow(title: "Account") {
                accountStatusLabel
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Client ID")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Spotify Client ID", text: $spotifyClientID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .textContentType(.none)
                    .accessibilityLabel("Spotify Client ID")
            }

            SettingsRow(title: "Redirect URI") {
                Text(SpotifyAuthConfiguration.redirectURI.absoluteString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            connectionMessage

            HStack {
                Link(
                    "Developer Dashboard",
                    destination: URL(string: "https://developer.spotify.com/dashboard")!
                )
                .font(.caption.weight(.medium))

                Spacer()

                if auth.isConnected {
                    Button("Disconnect", role: .destructive) {
                        auth.disconnect()
                    }
                    .disabled(auth.isConnecting)
                } else {
                    Button {
                        Task { await auth.connect(clientID: spotifyClientID) }
                    } label: {
                        connectButtonLabel
                    }
                    .disabled(!hasClientID || auth.isConnecting)
                    .help(hasClientID ? "Connect your Spotify account." : "Enter a Spotify Client ID first.")
                }
            }
        }
    }

    @ViewBuilder
    private var accountStatusLabel: some View {
        if auth.isConnecting {
            Label("Connecting", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        } else if auth.isConnected {
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        } else {
            Label("Not connected", systemImage: "circle.dashed")
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        }
    }

    @ViewBuilder
    private var connectionMessage: some View {
        if let errorMessage = auth.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .labelStyle(.titleAndIcon)
                .fixedSize(horizontal: false, vertical: true)
        } else if let statusMessage = auth.statusMessage {
            Label(statusMessage, systemImage: auth.isConnected ? "checkmark.circle.fill" : "info.circle")
                .font(.caption)
                .foregroundStyle(auth.isConnected ? .green : .secondary)
                .labelStyle(.titleAndIcon)
        }
    }

    @ViewBuilder
    private var connectButtonLabel: some View {
        if auth.isConnecting {
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting")
            }
        } else {
            Label("Connect Spotify", systemImage: "link")
        }
    }

    private var accessSection: some View {
        SettingsSection(title: "Access", icon: "person.crop.circle.badge.checkmark") {
            SettingsRow(title: "Base features") {
                Label("Available", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            }

            SettingsRow(title: "Connected features") {
                Label(
                    auth.isConnected ? "Available for this account" : "Requires Spotify login",
                    systemImage: auth.isConnected ? "checkmark.circle.fill" : "lock.circle"
                )
                    .foregroundStyle(auth.isConnected ? .green : .secondary)
                    .labelStyle(.titleAndIcon)
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 11) {
                content
            }
            .padding(14)
            .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.separator.opacity(0.32), lineWidth: 0.5)
            }
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            trailing
                .font(.subheadline)
        }
    }
}

#Preview {
    SongBarSettingsView(auth: SpotifyAuthViewModel(loadStoredSession: false))
}
