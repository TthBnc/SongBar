import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SpotifyAuthViewModel {
    private(set) var isConnected = false
    private(set) var isConnecting = false
    private(set) var isLibraryActionPending = false
    private(set) var isCurrentTrackSaved: Bool?
    private(set) var statusMessage: String?
    private(set) var errorMessage: String?
    private(set) var libraryErrorMessage: String?

    private let authClient: SpotifyAuthClient
    private let libraryClient: SpotifyLibraryClient
    private let tokenStore: SpotifyTokenStore
    private var session: SpotifyAuthSession?
    private var checkedTrackURI: String?
    private var libraryErrorResetTask: Task<Void, Never>?

    init(
        authClient: SpotifyAuthClient = SpotifyAuthClient(),
        libraryClient: SpotifyLibraryClient = SpotifyLibraryClient(),
        tokenStore: SpotifyTokenStore = SpotifyTokenStore(),
        loadStoredSession: Bool = true
    ) {
        self.authClient = authClient
        self.libraryClient = libraryClient
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
            libraryErrorMessage = nil
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
            isCurrentTrackSaved = nil
            checkedTrackURI = nil
            statusMessage = "Disconnected"
            errorMessage = nil
            libraryErrorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func canToggleSavedTrack(for spotifyURI: String?) -> Bool {
        isConnected
            && !isLibraryActionPending
            && SpotifyLibraryItem.trackURI(from: spotifyURI) != nil
    }

    func refreshSavedStatus(for spotifyURI: String?) async {
        guard let trackURI = SpotifyLibraryItem.trackURI(from: spotifyURI), isConnected else {
            checkedTrackURI = nil
            isCurrentTrackSaved = nil
            return
        }

        guard checkedTrackURI != trackURI || isCurrentTrackSaved == nil else { return }
        checkedTrackURI = trackURI
        isCurrentTrackSaved = nil
        libraryErrorMessage = nil

        do {
            let saved = try await withAccessToken { accessToken in
                try await libraryClient.contains(uri: trackURI, accessToken: accessToken)
            }
            guard checkedTrackURI == trackURI else { return }
            isCurrentTrackSaved = saved
        } catch {
            guard checkedTrackURI == trackURI else { return }
            isCurrentTrackSaved = nil
            showLibraryError(error.localizedDescription)
        }
    }

    func toggleSavedTrack(for spotifyURI: String?) async {
        guard let trackURI = SpotifyLibraryItem.trackURI(from: spotifyURI) else {
            showLibraryError(SpotifyLibraryError.unsupportedURI.localizedDescription)
            return
        }
        guard isConnected else {
            showLibraryError("Connect Spotify in Settings to save songs.")
            return
        }
        guard !isLibraryActionPending else { return }

        let previousValue = isCurrentTrackSaved ?? false
        let targetValue = !previousValue
        checkedTrackURI = trackURI
        isCurrentTrackSaved = targetValue
        isLibraryActionPending = true
        libraryErrorMessage = nil

        defer {
            isLibraryActionPending = false
        }

        do {
            try await withAccessToken { accessToken in
                if targetValue {
                    try await libraryClient.save(uri: trackURI, accessToken: accessToken)
                } else {
                    try await libraryClient.remove(uri: trackURI, accessToken: accessToken)
                }
            }
            guard checkedTrackURI == trackURI else { return }
            isCurrentTrackSaved = targetValue
        } catch {
            guard checkedTrackURI == trackURI else { return }
            isCurrentTrackSaved = previousValue
            showLibraryError(error.localizedDescription)
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

    private func withAccessToken<T>(
        _ operation: (String) async throws -> T
    ) async throws -> T {
        let accessToken = try await validAccessToken()

        do {
            return try await operation(accessToken)
        } catch SpotifyLibraryError.unauthorized {
            let refreshed = try await refreshStoredSession()
            return try await operation(refreshed.accessToken)
        }
    }

    private func validAccessToken() async throws -> String {
        if session == nil {
            session = try tokenStore.load()
            isConnected = session != nil
        }

        guard let session else {
            isConnected = false
            throw SpotifyLibraryError.unauthorized
        }

        if session.isExpiredSoon {
            return try await refreshStoredSession().accessToken
        }

        return session.accessToken
    }

    private func refreshStoredSession() async throws -> SpotifyAuthSession {
        guard let session else {
            isConnected = false
            throw SpotifyLibraryError.unauthorized
        }

        let clientID = storedClientID
        guard !clientID.isEmpty else {
            throw SpotifyAuthError.invalidClientID
        }

        let refreshed = try await authClient.refresh(session, clientID: clientID)
        try tokenStore.save(refreshed)
        self.session = refreshed
        isConnected = true
        return refreshed
    }

    private var storedClientID: String {
        UserDefaults.standard.string(forKey: "spotify.clientID")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func showLibraryError(_ message: String) {
        libraryErrorMessage = message
        libraryErrorResetTask?.cancel()
        libraryErrorResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.libraryErrorMessage = nil
        }
    }
}
