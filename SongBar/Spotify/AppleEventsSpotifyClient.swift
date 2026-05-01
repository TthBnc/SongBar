import Foundation
import AppKit
import os

actor AppleEventsSpotifyClient: SpotifyClient {
    private static let bundleIdentifier = "com.spotify.client"
    private static let logger = Logger(subsystem: "dev.tothbnc.SongBar", category: "spotify")

    private static let fetchSource = """
    tell application "Spotify"
        if not running then return "NOT_RUNNING"
        try
            set st to player state as text
            set pos to player position
            try
                set tn to name of current track
                set tar to artist of current track
                set tal to album of current track
                set tdur to duration of current track
                set turl to spotify url of current track
                set tarturl to artwork url of current track
                return st & "|||" & pos & "|||" & tn & "|||" & tar & "|||" & tal & "|||" & tdur & "|||" & turl & "|||" & tarturl
            on error
                return st & "|||" & pos & "|||NO_TRACK"
            end try
        on error
            return "ERROR"
        end try
    end tell
    """

    private static let playPauseSource = "tell application \"Spotify\" to playpause"
    private static let nextSource = "tell application \"Spotify\" to next track"
    private static let previousSource = "tell application \"Spotify\" to previous track"
    private static let activateSource = "tell application \"Spotify\" to activate"

    private var fetchScript: NSAppleScript?
    private var playPauseScript: NSAppleScript?
    private var nextScript: NSAppleScript?
    private var previousScript: NSAppleScript?
    private var activateScript: NSAppleScript?
    private var compiledScripts = false

    init() {}

    private func ensureCompiled() {
        guard !compiledScripts else { return }
        compiledScripts = true
        fetchScript = compile(Self.fetchSource, label: "fetch")
        playPauseScript = compile(Self.playPauseSource, label: "playPause")
        nextScript = compile(Self.nextSource, label: "next")
        previousScript = compile(Self.previousSource, label: "previous")
        activateScript = compile(Self.activateSource, label: "activate")
    }

    private func compile(_ source: String, label: String) -> NSAppleScript? {
        guard let script = NSAppleScript(source: source) else {
            Self.logger.error("Failed to construct NSAppleScript for \(label, privacy: .public)")
            return nil
        }
        var error: NSDictionary?
        if !script.compileAndReturnError(&error) {
            Self.logger.error("Compile failed for \(label, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
        return script
    }

    private func isInstalled() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier) != nil
    }

    private func isRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).isEmpty
    }

    private enum AppleEventErrorKind {
        case automationDenied
        case notRunning
        case unknown
    }

    private func classify(_ error: NSDictionary?) -> AppleEventErrorKind {
        guard let error else { return .unknown }
        let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
        switch code {
        case -1743, -1744, -10004:
            return .automationDenied
        case -600, -609:
            return .notRunning
        default:
            return .unknown
        }
    }

    func fetchNowPlaying() async -> NowPlaying {
        guard isInstalled() else {
            return NowPlaying(
                title: nil, artist: nil, album: nil,
                playbackState: .unavailable,
                position: 0, duration: 0,
                artworkURL: nil, spotifyURI: nil, shareURL: nil,
                availability: .notInstalled
            )
        }
        guard isRunning() else {
            return NowPlaying(
                title: nil, artist: nil, album: nil,
                playbackState: .unavailable,
                position: 0, duration: 0,
                artworkURL: nil, spotifyURI: nil, shareURL: nil,
                availability: .notRunning
            )
        }

        ensureCompiled()
        guard let script = fetchScript else {
            return NowPlaying(
                title: nil, artist: nil, album: nil,
                playbackState: .unknown,
                position: 0, duration: 0,
                artworkURL: nil, spotifyURI: nil, shareURL: nil,
                availability: .unknown
            )
        }

        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            let kind = classify(error)
            Self.logger.debug("fetchNowPlaying error: \(String(describing: error), privacy: .public)")
            switch kind {
            case .automationDenied:
                return NowPlaying(
                    title: nil, artist: nil, album: nil,
                    playbackState: .unavailable,
                    position: 0, duration: 0,
                    artworkURL: nil, spotifyURI: nil, shareURL: nil,
                    availability: .automationDenied
                )
            case .notRunning:
                return NowPlaying(
                    title: nil, artist: nil, album: nil,
                    playbackState: .unavailable,
                    position: 0, duration: 0,
                    artworkURL: nil, spotifyURI: nil, shareURL: nil,
                    availability: .notRunning
                )
            case .unknown:
                return NowPlaying(
                    title: nil, artist: nil, album: nil,
                    playbackState: .unknown,
                    position: 0, duration: 0,
                    artworkURL: nil, spotifyURI: nil, shareURL: nil,
                    availability: .unknown
                )
            }
        }

        guard let raw = descriptor.stringValue else {
            return NowPlaying(
                title: nil, artist: nil, album: nil,
                playbackState: .unknown,
                position: 0, duration: 0,
                artworkURL: nil, spotifyURI: nil, shareURL: nil,
                availability: .unknown
            )
        }

        return parse(raw)
    }

    private func parse(_ raw: String) -> NowPlaying {
        if raw == "NOT_RUNNING" {
            return NowPlaying(
                title: nil, artist: nil, album: nil,
                playbackState: .unavailable,
                position: 0, duration: 0,
                artworkURL: nil, spotifyURI: nil, shareURL: nil,
                availability: .notRunning
            )
        }
        if raw == "ERROR" {
            return NowPlaying(
                title: nil, artist: nil, album: nil,
                playbackState: .unavailable,
                position: 0, duration: 0,
                artworkURL: nil, spotifyURI: nil, shareURL: nil,
                availability: .automationDenied
            )
        }

        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 2 else {
            return NowPlaying(
                title: nil, artist: nil, album: nil,
                playbackState: .unknown,
                position: 0, duration: 0,
                artworkURL: nil, spotifyURI: nil, shareURL: nil,
                availability: .unknown
            )
        }

        let state = mapState(parts[0])
        let position = TimeInterval(parts[1]) ?? 0

        if parts.count >= 3, parts[2] == "NO_TRACK" {
            return NowPlaying(
                title: nil, artist: nil, album: nil,
                playbackState: state,
                position: position,
                duration: 0,
                artworkURL: nil, spotifyURI: nil, shareURL: nil,
                availability: .noActiveTrack
            )
        }

        guard parts.count >= 8 else {
            return NowPlaying(
                title: nil, artist: nil, album: nil,
                playbackState: state,
                position: position,
                duration: 0,
                artworkURL: nil, spotifyURI: nil, shareURL: nil,
                availability: .noActiveTrack
            )
        }

        let title = nilIfEmpty(parts[2])
        let artist = nilIfEmpty(parts[3])
        let album = nilIfEmpty(parts[4])
        let durationMillis = Double(parts[5]) ?? 0
        let duration = durationMillis / 1000.0
        let uri = nilIfEmpty(parts[6])
        let artworkURL = (parts.count >= 8) ? URL(string: parts[7]) : nil

        let shareURL = SpotifyURL.shareURL(forURI: uri)

        let availability: SpotifyAvailability = (title == nil && artist == nil) ? .noActiveTrack : .ok

        Self.logger.debug("fetched track state=\(String(describing: state), privacy: .public) duration=\(duration) hasURI=\(uri != nil)")

        return NowPlaying(
            title: title,
            artist: artist,
            album: album,
            playbackState: state,
            position: position,
            duration: duration,
            artworkURL: artworkURL,
            spotifyURI: uri,
            shareURL: shareURL,
            availability: availability
        )
    }

    private func nilIfEmpty(_ s: String) -> String? {
        s.isEmpty ? nil : s
    }

    private func mapState(_ s: String) -> PlaybackState {
        switch s.lowercased() {
        case "playing": return .playing
        case "paused": return .paused
        case "stopped": return .stopped
        default: return .unknown
        }
    }

    private func runCommand(_ script: NSAppleScript?, label: String) {
        guard isInstalled(), isRunning() else { return }
        guard let script else { return }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        if let error {
            Self.logger.debug("\(label, privacy: .public) error: \(String(describing: error), privacy: .public)")
        }
    }

    func playPause() async {
        ensureCompiled()
        runCommand(playPauseScript, label: "playPause")
    }

    func nextTrack() async {
        ensureCompiled()
        runCommand(nextScript, label: "next")
    }

    func previousTrack() async {
        ensureCompiled()
        runCommand(previousScript, label: "previous")
    }

    func seek(to seconds: TimeInterval) async {
        guard isInstalled(), isRunning() else { return }
        let safe: TimeInterval
        if seconds.isNaN || seconds.isInfinite || seconds < 0 {
            safe = 0
        } else {
            safe = seconds
        }
        let source = "tell application \"Spotify\" to set player position to \(safe)"
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        if let error {
            Self.logger.debug("seek error: \(String(describing: error), privacy: .public)")
        }
    }

    func openSpotify() async {
        guard isInstalled() else { return }
        if isRunning() {
            ensureCompiled()
            if let script = activateScript {
                var error: NSDictionary?
                _ = script.executeAndReturnError(&error)
                if let error {
                    Self.logger.debug("activate error: \(String(describing: error), privacy: .public)")
                }
                return
            }
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier) else {
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error {
                    Self.logger.debug("openApplication error: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume()
            }
        }
    }

    func openCurrentTrack() async {
        let snapshot = await fetchNowPlaying()
        guard let url = snapshot.shareURL else { return }
        await openTrack(url)
    }

    func openTrack(_ url: URL) async {
        let opened = await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        if !opened {
            Self.logger.debug("openTrack failed for url")
        }
    }
}
