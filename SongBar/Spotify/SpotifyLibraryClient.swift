import Foundation

enum SpotifyLibraryError: LocalizedError, Equatable {
    case unsupportedURI
    case unauthorized
    case forbidden(String)
    case rateLimited
    case requestFailed(statusCode: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedURI:
            return "This Spotify item cannot be saved from SongBar."
        case .unauthorized:
            return "Spotify needs you to connect again."
        case .forbidden(let message):
            if message.isEmpty {
                return "Spotify blocked this library action. Check that this account is added in Spotify Dashboard user management."
            }
            return message
        case .rateLimited:
            return "Spotify is rate limiting library actions. Try again in a moment."
        case .requestFailed(let statusCode, let message):
            if message.isEmpty {
                return "Spotify library request failed with HTTP \(statusCode)."
            }
            return "Spotify library request failed with HTTP \(statusCode): \(message)"
        case .invalidResponse:
            return "Spotify returned an unreadable library response."
        }
    }
}

enum SpotifyLibraryItem {
    static func trackURI(from spotifyURI: String?) -> String? {
        guard let spotifyURI else { return nil }
        let trimmed = spotifyURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("spotify:track:") else { return nil }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, !parts[2].isEmpty else { return nil }
        return trimmed
    }
}

struct SpotifyLibraryClient {
    private static let libraryURL = URL(string: "https://api.spotify.com/v1/me/library")!
    private static let containsURL = URL(string: "https://api.spotify.com/v1/me/library/contains")!

    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func contains(uri: String, accessToken: String) async throws -> Bool {
        let request = try makeRequest(
            method: "GET",
            endpoint: Self.containsURL,
            uri: uri,
            accessToken: accessToken
        )
        let data = try await perform(request)

        do {
            return try decoder.decode([Bool].self, from: data).first ?? false
        } catch {
            throw SpotifyLibraryError.invalidResponse
        }
    }

    func save(uri: String, accessToken: String) async throws {
        let request = try makeRequest(
            method: "PUT",
            endpoint: Self.libraryURL,
            uri: uri,
            accessToken: accessToken
        )
        _ = try await perform(request)
    }

    func remove(uri: String, accessToken: String) async throws {
        let request = try makeRequest(
            method: "DELETE",
            endpoint: Self.libraryURL,
            uri: uri,
            accessToken: accessToken
        )
        _ = try await perform(request)
    }

    func makeRequest(
        method: String,
        endpoint: URL,
        uri: String,
        accessToken: String
    ) throws -> URLRequest {
        guard let trackURI = SpotifyLibraryItem.trackURI(from: uri) else {
            throw SpotifyLibraryError.unsupportedURI
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "uris", value: trackURI)
        ]

        guard let url = components?.url else {
            throw SpotifyLibraryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyLibraryError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 401:
                throw SpotifyLibraryError.unauthorized
            case 403:
                throw SpotifyLibraryError.forbidden(parseSpotifyErrorMessage(from: data))
            case 429:
                throw SpotifyLibraryError.rateLimited
            default:
                throw SpotifyLibraryError.requestFailed(
                    statusCode: httpResponse.statusCode,
                    message: parseSpotifyErrorMessage(from: data)
                )
            }
        }

        return data
    }

    private func parseSpotifyErrorMessage(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? [String: Any],
            let message = error["message"] as? String
        else {
            return String(data: data, encoding: .utf8) ?? ""
        }

        return message
    }
}

