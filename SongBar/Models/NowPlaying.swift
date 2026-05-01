import Foundation

struct NowPlaying: Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var playbackState: PlaybackState
    var position: TimeInterval
    var duration: TimeInterval
    var artworkURL: URL?
    var spotifyURI: String?
    var shareURL: URL?

    static let empty = NowPlaying(
        title: nil,
        artist: nil,
        album: nil,
        playbackState: .unavailable,
        position: 0,
        duration: 0,
        artworkURL: nil,
        spotifyURI: nil,
        shareURL: nil
    )
}
