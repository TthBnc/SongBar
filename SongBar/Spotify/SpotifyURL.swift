import Foundation

enum SpotifyURL {
    private static let validKinds: Set<String> = [
        "track", "album", "artist", "playlist", "episode", "show"
    ]

    static func shareURL(forURI uri: String?) -> URL? {
        guard let uri, !uri.isEmpty else { return nil }

        if uri.hasPrefix("https://open.spotify.com/") {
            return URL(string: uri)
        }

        guard uri.hasPrefix("spotify:") else { return nil }

        let parts = uri.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }

        let kind = String(parts[1])
        let id = String(parts[2])

        guard validKinds.contains(kind) else { return nil }
        guard isValidBase62(id) else { return nil }

        return URL(string: "https://open.spotify.com/\(kind)/\(id)")
    }

    static func openURL(forURI uri: String?) -> URL? {
        if let share = shareURL(forURI: uri) {
            return share
        }
        guard let uri, !uri.isEmpty, uri.hasPrefix("spotify:") else { return nil }
        let parts = uri.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let kind = String(parts[1])
        let id = String(parts[2])
        guard validKinds.contains(kind), isValidBase62(id) else { return nil }
        return URL(string: uri)
    }

    private static func isValidBase62(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        for ch in s {
            guard ch.isASCII, ch.isLetter || ch.isNumber else { return false }
        }
        return true
    }
}
