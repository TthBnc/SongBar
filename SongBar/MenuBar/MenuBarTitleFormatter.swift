import Foundation

enum MenuBarTitleFormatter {
    static let defaultMaxLength = 48
    static func format(nowPlaying: NowPlaying, maxLength: Int = defaultMaxLength) -> String {
        "SongBar"
    }
}
