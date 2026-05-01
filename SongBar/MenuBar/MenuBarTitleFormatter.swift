import Foundation

enum MenuBarTitleFormatter {
    static let defaultMaxLength = 48
    static let fallback = "SongBar"
    static let ellipsis: Character = "\u{2026}"

    static func format(nowPlaying: NowPlaying, maxLength: Int = defaultMaxLength) -> String {
        guard nowPlaying.availability == .ok else { return fallback }

        let title = nonEmpty(nowPlaying.title)
        let artist = nonEmpty(nowPlaying.artist)

        let base: String
        switch (artist, title) {
        case let (artist?, title?):
            base = "\(artist) - \(title)"
        case (nil, let title?):
            base = title
        case (let artist?, nil):
            base = artist
        default:
            return fallback
        }

        let prefixed = nowPlaying.playbackState == .paused ? "Paused: \(base)" : base

        return truncate(prefixed, to: maxLength)
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }

    private static func truncate(_ s: String, to maxLength: Int) -> String {
        if maxLength <= 1 { return String(ellipsis) }
        if s.count <= maxLength { return s }
        let head = s.prefix(maxLength - 1)
        return String(head) + String(ellipsis)
    }
}
