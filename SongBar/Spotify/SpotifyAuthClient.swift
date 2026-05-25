import Foundation

struct SpotifyAuthConfiguration {
    static let callbackPort: UInt16 = 17_654
    static let redirectURI = URL(string: "http://127.0.0.1:17654/callback")!
    static let scopes = ["user-library-read", "user-library-modify"]

    fileprivate static let authorizeURL = URL(string: "https://accounts.spotify.com/authorize")!
    fileprivate static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
}

struct SpotifyAuthorizationRequest: Equatable {
    let authorizationURL: URL
    let codeVerifier: String
    let state: String
}

enum SpotifyAuthError: LocalizedError {
    case invalidClientID
    case invalidAuthorizationURL
    case browserOpenFailed
    case missingRefreshToken
    case tokenRequestFailed(statusCode: Int, message: String)
    case invalidTokenResponse
    case keychainFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidClientID:
            return "Enter the Spotify Client ID from your developer dashboard."
        case .invalidAuthorizationURL:
            return "SongBar could not build the Spotify login URL."
        case .browserOpenFailed:
            return "SongBar could not open Spotify login in your browser."
        case .missingRefreshToken:
            return "Spotify did not return a refresh token."
        case .tokenRequestFailed(let statusCode, let message):
            if message.isEmpty {
                return "Spotify rejected the token request with HTTP \(statusCode)."
            }
            return "Spotify rejected the token request with HTTP \(statusCode): \(message)"
        case .invalidTokenResponse:
            return "Spotify returned an unreadable token response."
        case .keychainFailed(let status):
            return "SongBar could not access Keychain. OSStatus \(status)."
        }
    }
}

struct SpotifyAuthClient {
    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func makeAuthorizationRequest(clientID: String) throws -> SpotifyAuthorizationRequest {
        try makeAuthorizationRequest(
            clientID: clientID,
            state: SpotifyPKCE.makeState(),
            codeVerifier: SpotifyPKCE.makeCodeVerifier()
        )
    }

    func makeAuthorizationRequest(
        clientID rawClientID: String,
        state: String,
        codeVerifier: String
    ) throws -> SpotifyAuthorizationRequest {
        let clientID = rawClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else { throw SpotifyAuthError.invalidClientID }

        var components = URLComponents(url: SpotifyAuthConfiguration.authorizeURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: SpotifyAuthConfiguration.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: SpotifyAuthConfiguration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: SpotifyPKCE.codeChallenge(for: codeVerifier))
        ]

        guard let url = components?.url else { throw SpotifyAuthError.invalidAuthorizationURL }
        return SpotifyAuthorizationRequest(authorizationURL: url, codeVerifier: codeVerifier, state: state)
    }

    func exchangeCode(
        _ code: String,
        clientID: String,
        codeVerifier: String
    ) async throws -> SpotifyAuthSession {
        let response = try await performTokenRequest(queryItems: [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: SpotifyAuthConfiguration.redirectURI.absoluteString),
            URLQueryItem(name: "client_id", value: clientID.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ])

        guard response.refreshToken != nil else { throw SpotifyAuthError.missingRefreshToken }
        return response.session(keepingRefreshToken: nil)
    }

    func refresh(_ session: SpotifyAuthSession, clientID: String) async throws -> SpotifyAuthSession {
        guard let refreshToken = session.refreshToken else { throw SpotifyAuthError.missingRefreshToken }
        let response = try await performTokenRequest(queryItems: [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientID.trimmingCharacters(in: .whitespacesAndNewlines))
        ])

        return response.session(keepingRefreshToken: refreshToken)
    }

    private func performTokenRequest(queryItems: [URLQueryItem]) async throws -> SpotifyTokenResponse {
        var request = URLRequest(url: SpotifyAuthConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = queryItems.formURLEncodedBody()

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyAuthError.invalidTokenResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw SpotifyAuthError.tokenRequestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(SpotifyTokenResponse.self, from: data)
        } catch {
            throw SpotifyAuthError.invalidTokenResponse
        }
    }
}

private struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let scope: String?
    let expiresIn: Int
    let refreshToken: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }

    func session(keepingRefreshToken existingRefreshToken: String?) -> SpotifyAuthSession {
        SpotifyAuthSession(
            accessToken: accessToken,
            tokenType: tokenType,
            scope: scope ?? "",
            refreshToken: refreshToken ?? existingRefreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}

private extension Array where Element == URLQueryItem {
    func formURLEncodedBody() -> Data {
        var components = URLComponents()
        components.queryItems = self
        return Data((components.percentEncodedQuery ?? "").utf8)
    }
}
