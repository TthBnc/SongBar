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
    private static let indicatorSize = NSSize(width: 11, height: 12)
    private static let optimisticHoldSeconds: TimeInterval = 2.5
    private static let optimisticPositionTolerance: TimeInterval = 2.0
    private static let optimisticRefreshDelays: [Duration] = [
        .milliseconds(250),
        .milliseconds(500),
        .milliseconds(750),
        .milliseconds(1_000)
    ]

    var isDraggingSeek: Bool { seekDragState != nil }

    var displayPosition: TimeInterval {
        seekDragState ?? optimisticPosition ?? nowPlaying.position
    }

    var displayPlaybackState: PlaybackState {
        optimisticPlaybackState ?? nowPlaying.playbackState
    }

    var isPlayPausePending: Bool {
        inflightCommands.contains(.playPause)
    }

    var isNextPending: Bool {
        inflightCommands.contains(.next)
    }

    var isPreviousPending: Bool {
        inflightCommands.contains(.previous)
    }

    var isSeekPending: Bool {
        inflightCommands.contains(.seek)
    }

    private let client: SpotifyClient
    private let artworkLoader: ArtworkLoader
    private let logger = Logger(subsystem: "dev.tothbnc.SongBar", category: "viewmodel")

    private var pollingTask: Task<Void, Never>?
    private var artworkLoadTask: Task<Void, Never>?
    private var lastArtworkURL: URL?
    private var seekDragState: TimeInterval?
    private var optimisticPlaybackState: PlaybackState?
    private var optimisticPlaybackDeadline: Date?
    private var optimisticPosition: TimeInterval?
    private var optimisticPositionDeadline: Date?
    private var inflightCommands: Set<Command> = []
    private var copyConfirmationResetTask: Task<Void, Never>?
    private var equalizerTask: Task<Void, Never>?
    private var optimisticReconciliationTask: Task<Void, Never>?

    private enum Command: Hashable { case playPause, next, previous, seek }

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
        optimisticReconciliationTask?.cancel()
        optimisticReconciliationTask = nil
    }

    func refresh() async {
        let snapshot = await client.fetchNowPlaying()
        apply(snapshot, reconcileOptimisticState: inflightCommands.isEmpty)
    }

    func playPause() async {
        await runCommand(.playPause, optimisticUpdate: togglePlaybackOptimistically) {
            await self.client.playPause()
        }
    }

    func next() async {
        await runCommand(.next, optimisticUpdate: prepareTrackSkipOptimistically) {
            await self.client.nextTrack()
        }
    }

    func previous() async {
        await runCommand(.previous, optimisticUpdate: prepareTrackSkipOptimistically) {
            await self.client.previousTrack()
        }
    }

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
        await runCommand(.seek, optimisticUpdate: { setOptimisticPosition(target) }) {
            await self.client.seek(to: target)
        }
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

    private func runCommand(
        _ command: Command,
        optimisticUpdate: () -> Void,
        action: @escaping () async -> Void
    ) async {
        guard !inflightCommands.contains(command) else { return }
        inflightCommands.insert(command)
        defer { inflightCommands.remove(command) }
        optimisticUpdate()
        await action()
        let snapshot = await client.fetchNowPlaying()
        apply(snapshot, reconcileOptimisticState: true)
        scheduleOptimisticReconciliation()
    }

    private func apply(_ snapshot: NowPlaying, reconcileOptimisticState: Bool = true) {
        let trackChanged = snapshot.spotifyURI != nowPlaying.spotifyURI
            || snapshot.title != nowPlaying.title

        if reconcileOptimisticState {
            reconcileOptimisticDisplay(with: snapshot, trackChanged: trackChanged)
        }

        let titleChanged = trackChanged
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

    private var hasOptimisticDisplayState: Bool {
        optimisticPlaybackState != nil || optimisticPosition != nil
    }

    private func reconcileOptimisticDisplay(with snapshot: NowPlaying, trackChanged: Bool) {
        if let targetState = optimisticPlaybackState {
            if snapshot.playbackState == targetState || optimisticPlaybackExpired {
                optimisticPlaybackState = nil
                optimisticPlaybackDeadline = nil
            }
        }

        if let targetPosition = optimisticPosition {
            let confirmedPosition = abs(snapshot.position - targetPosition) <= Self.optimisticPositionTolerance
            let confirmedTrackSkip = targetPosition == 0 && trackChanged
            if confirmedPosition || confirmedTrackSkip || optimisticPositionExpired {
                optimisticPosition = nil
                optimisticPositionDeadline = nil
            }
        }
    }

    private var optimisticPlaybackExpired: Bool {
        guard let deadline = optimisticPlaybackDeadline else { return true }
        return Date() >= deadline
    }

    private var optimisticPositionExpired: Bool {
        guard let deadline = optimisticPositionDeadline else { return true }
        return Date() >= deadline
    }

    private func scheduleOptimisticReconciliation() {
        optimisticReconciliationTask?.cancel()
        guard hasOptimisticDisplayState else {
            optimisticReconciliationTask = nil
            return
        }

        optimisticReconciliationTask = Task { @MainActor [weak self] in
            for delay in Self.optimisticRefreshDelays {
                try? await Task.sleep(for: delay)
                guard let self, !Task.isCancelled, self.hasOptimisticDisplayState else { return }
                await self.refresh()
            }
        }
    }

    private func pollInterval() -> Duration {
        switch displayPlaybackState {
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
        switch displayPlaybackState {
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
        switch displayPlaybackState {
        case .playing:
            let frame = equalizerFrame
            menuBarArtwork = thumbnail.withIndicatorOnLeft(indicatorSize: iSize) { origin, sz in
                NSImage.drawEqualizerBars(frame: frame, at: origin, in: sz)
            }
        case .paused:
            menuBarArtwork = thumbnail.withIndicatorOnLeft(indicatorSize: iSize) { origin, sz in
                NSImage.drawPauseGlyph(at: origin, in: sz)
            }
        default:
            menuBarArtwork = thumbnail
        }
    }

    private func togglePlaybackOptimistically() {
        switch displayPlaybackState {
        case .playing:
            optimisticPlaybackState = .paused
        case .paused, .stopped:
            optimisticPlaybackState = .playing
        case .unknown, .unavailable:
            return
        }
        optimisticPlaybackDeadline = Date().addingTimeInterval(Self.optimisticHoldSeconds)
        updateEqualizerAnimation()
    }

    private func prepareTrackSkipOptimistically() {
        setOptimisticPosition(0)
    }

    private func setOptimisticPosition(_ position: TimeInterval) {
        optimisticPosition = position
        optimisticPositionDeadline = Date().addingTimeInterval(Self.optimisticHoldSeconds)
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
