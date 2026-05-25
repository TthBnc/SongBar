import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SpotifyAuthViewModel {
    private(set) var isConnected = false
    private(set) var isConnecting = false
    private(set) var statusMessage: String?
    private(set) var errorMessage: String?

    private let authClient: SpotifyAuthClient
    private let tokenStore: SpotifyTokenStore
    private var session: SpotifyAuthSession?

    init(
        authClient: SpotifyAuthClient = SpotifyAuthClient(),
        tokenStore: SpotifyTokenStore = SpotifyTokenStore(),
        loadStoredSession: Bool = true
    ) {
        self.authClient = authClient
        self.tokenStore = tokenStore

        if loadStoredSession {
            loadStoredSessionFromKeychain()
        }
    }

    func connect(clientID rawClientID: String) async {
        guard !isConnecting else { return }

        let clientID = rawClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            errorMessage = SpotifyAuthError.invalidClientID.localizedDescription
            return
        }

        isConnecting = true
        statusMessage = "Opening Spotify login..."
        errorMessage = nil

        defer {
            isConnecting = false
        }

        let receiver = SpotifyOAuthCallbackReceiver()

        do {
            try await receiver.start()
            defer { receiver.stop() }

            let request = try authClient.makeAuthorizationRequest(clientID: clientID)
            statusMessage = "Waiting for Spotify..."
            let callback = try await receiver.waitForCallback(expectedState: request.state) {
                NSWorkspace.shared.open(request.authorizationURL) ? nil : SpotifyAuthError.browserOpenFailed
            }

            statusMessage = "Finishing connection..."
            let session = try await authClient.exchangeCode(
                callback.code,
                clientID: clientID,
                codeVerifier: request.codeVerifier
            )
            try tokenStore.save(session)

            self.session = session
            isConnected = true
            statusMessage = "Connected"
        } catch {
            receiver.stop()
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func disconnect() {
        do {
            try tokenStore.delete()
            session = nil
            isConnected = false
            statusMessage = "Disconnected"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadStoredSessionFromKeychain() {
        do {
            session = try tokenStore.load()
            isConnected = session != nil
            statusMessage = isConnected ? "Connected" : nil
            errorMessage = nil
        } catch {
            session = nil
            isConnected = false
            errorMessage = error.localizedDescription
        }
    }
}
