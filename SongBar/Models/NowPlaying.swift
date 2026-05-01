import Foundation

/// Snapshot of the local Spotify desktop app's playback state plus the
/// metadata for the current track. All fields tolerate missing data so
/// the UI can render partial information without crashing.
struct NowPlaying: Equatable, Sendable {
    var title: String?
    var artist: String?
    var album: String?
    var playbackState: PlaybackState
    var position: TimeInterval
    var duration: TimeInterval
    var artworkURL: URL?
    var spotifyURI: String?
    var shareURL: URL?
    var availability: SpotifyAvailability

    static let empty = NowPlaying(
        title: nil,
        artist: nil,
        album: nil,
        playbackState: .unknown,
        position: 0,
        duration: 0,
        artworkURL: nil,
        spotifyURI: nil,
        shareURL: nil,
        availability: .unknown
    )
}

/// Whether SongBar can talk to Spotify, and if so, whether something is
/// actually playing. Drives the panel's banner copy and which controls
/// are enabled.
enum SpotifyAvailability: Equatable, Sendable {
    /// Spotify is running, automation is permitted, and a track is loaded
    /// (playing, paused, or stopped).
    case ok
    /// Spotify is running and reachable but no track is currently loaded.
    case noActiveTrack
    /// Spotify is installed on disk but not currently running.
    case notRunning
    /// Spotify is not installed on this Mac.
    case notInstalled
    /// macOS denied the Automation permission for SongBar → Spotify.
    case automationDenied
    /// Initial state, before any availability check has completed.
    case unknown
}

extension NowPlaying {
    /// True when there is a current track URL we can share or open.
    var hasShareableTrack: Bool {
        shareURL != nil
    }

    /// True when controls should be enabled (Spotify is reachable).
    var controlsEnabled: Bool {
        switch availability {
        case .ok, .noActiveTrack: return true
        case .notRunning, .notInstalled, .automationDenied, .unknown: return false
        }
    }
}
