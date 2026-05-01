import Foundation
import Observation
import AppKit
import os

@MainActor
@Observable
final class NowPlayingViewModel {
    private(set) var nowPlaying: NowPlaying = .empty
    private(set) var artwork: NSImage?
    /// Rounded artwork thumbnail composited with the playback state indicator
    /// (animated equalizer bars while playing, pause glyph while paused).
    /// Kept as a single NSImage so MenuBarLabel can use one Image(nsImage:),
    /// which is all MenuBarExtra's label cell supports reliably.
    private(set) var menuBarArtwork: NSImage?
    private(set) var menuBarTitle: String = "SongBar"
    private(set) var copyConfirmation: Bool = false
    private var equalizerFrame: Int = 0
    private var roundedThumbnail: NSImage?
    private static let indicatorSize = NSSize(width: 9, height: 8)

    var isDraggingSeek: Bool { seekDragState != nil }

    var displayPosition: TimeInterval {
        seekDragState ?? nowPlaying.position
    }

    private let client: SpotifyClient
    private let artworkLoader: ArtworkLoader
    private let logger = Logger(subsystem: "dev.tothbnc.SongBar", category: "viewmodel")

    private var pollingTask: Task<Void, Never>?
    private var artworkLoadTask: Task<Void, Never>?
    private var lastArtworkURL: URL?
    private var seekDragState: TimeInterval?
    private var inflightCommands: Set<Command> = []
    private var copyConfirmationResetTask: Task<Void, Never>?
    private var equalizerTask: Task<Void, Never>?

    private enum Command: Hashable { case playPause, next, previous }

    init(
        client: SpotifyClient = AppleEventsSpotifyClient(),
        artworkLoader: ArtworkLoader = ArtworkLoader(),
        autoStart: Bool = true
    ) {
        self.client = client
        self.artworkLoader = artworkLoader
        if autoStart {
            start()
        }
    }

    func start() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                guard let self, !Task.isCancelled else { return }
                let interval = pollInterval()
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        artworkLoadTask?.cancel()
        artworkLoadTask = nil
        copyConfirmationResetTask?.cancel()
        copyConfirmationResetTask = nil
        equalizerTask?.cancel()
        equalizerTask = nil
    }

    func refresh() async {
        let snapshot = await client.fetchNowPlaying()
        apply(snapshot)
    }

    func playPause() async { await runCommand(.playPause) { await self.client.playPause() } }
    func next() async { await runCommand(.next) { await self.client.nextTrack() } }
    func previous() async { await runCommand(.previous) { await self.client.previousTrack() } }

    func beginSeekDrag(at seconds: TimeInterval) {
        seekDragState = clamp(seconds)
    }

    func updateSeekDrag(to seconds: TimeInterval) {
        guard seekDragState != nil else { return }
        seekDragState = clamp(seconds)
    }

    func endSeekDrag(at seconds: TimeInterval) async {
        let target = clamp(seconds)
        seekDragState = nil
        await client.seek(to: target)
        await refresh()
    }

    func cancelSeekDrag() {
        seekDragState = nil
    }

    func openSpotify() async {
        await client.openSpotify()
    }

    func openCurrentTrack() async {
        if let shareURL = nowPlaying.shareURL {
            await client.openTrack(shareURL)
        } else {
            await client.openSpotify()
        }
    }

    func copyShareURL() {
        guard let url = nowPlaying.shareURL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        showCopyConfirmation()
    }

    private func runCommand(_ command: Command, action: @escaping () async -> Void) async {
        guard !inflightCommands.contains(command) else { return }
        inflightCommands.insert(command)
        defer { inflightCommands.remove(command) }
        await action()
        await refresh()
    }

    private func apply(_ snapshot: NowPlaying) {
        let titleChanged = snapshot.spotifyURI != nowPlaying.spotifyURI
            || snapshot.title != nowPlaying.title
        nowPlaying = snapshot
        menuBarTitle = MenuBarTitleFormatter.format(nowPlaying: snapshot)
        updateEqualizerAnimation()

        let newArtworkURL = snapshot.artworkURL
        if newArtworkURL != lastArtworkURL {
            lastArtworkURL = newArtworkURL
            artwork = nil
            roundedThumbnail = nil
            menuBarArtwork = nil
            artworkLoadTask?.cancel()
            if let url = newArtworkURL {
                artworkLoadTask = Task { @MainActor [weak self, artworkLoader] in
                    let image = await artworkLoader.loadArtwork(from: url)
                    guard let self, !Task.isCancelled, self.lastArtworkURL == url else { return }
                    self.artwork = image
                    self.roundedThumbnail = image?.roundedThumbnail(size: 18, cornerRadius: 4)
                    self.rebuildMenuBarArtwork()
                }
            }
        } else if titleChanged && newArtworkURL == nil {
            artwork = nil
            roundedThumbnail = nil
            menuBarArtwork = nil
        }
    }

    private func pollInterval() -> Duration {
        switch nowPlaying.playbackState {
        case .playing where !isDraggingSeek:
            return .seconds(1)
        default:
            return .seconds(3)
        }
    }

    private func clamp(_ seconds: TimeInterval) -> TimeInterval {
        guard !seconds.isNaN else { return 0 }
        let lower = max(0, seconds)
        guard nowPlaying.duration > 0 else { return lower }
        return min(lower, nowPlaying.duration)
    }

    private func updateEqualizerAnimation() {
        switch nowPlaying.playbackState {
        case .playing:
            rebuildMenuBarArtwork()
            guard equalizerTask == nil else { return }
            equalizerTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(180))
                    guard let self, !Task.isCancelled else { return }
                    self.equalizerFrame &+= 1
                    self.rebuildMenuBarArtwork()
                }
            }
        case .paused:
            equalizerTask?.cancel()
            equalizerTask = nil
            rebuildMenuBarArtwork()
        default:
            equalizerTask?.cancel()
            equalizerTask = nil
            rebuildMenuBarArtwork()
        }
    }

    private func rebuildMenuBarArtwork() {
        guard let thumbnail = roundedThumbnail else {
            menuBarArtwork = nil
            return
        }
        let iSize = Self.indicatorSize
        switch nowPlaying.playbackState {
        case .playing:
            let frame = equalizerFrame
            menuBarArtwork = thumbnail.withStateOverlay(indicatorSize: iSize) { origin, sz in
                NSImage.drawEqualizerBars(frame: frame, at: origin, in: sz)
            }
        case .paused:
            menuBarArtwork = thumbnail.withStateOverlay(indicatorSize: iSize) { origin, sz in
                NSImage.drawPauseGlyph(at: origin, in: sz)
            }
        default:
            menuBarArtwork = thumbnail
        }
    }

    private func showCopyConfirmation() {
        copyConfirmation = true
        copyConfirmationResetTask?.cancel()
        copyConfirmationResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.copyConfirmation = false
        }
    }
}
