import XCTest
@testable import SongBar

@MainActor
final class SeekClampingTests: XCTestCase {

    // MARK: - Test double

    final actor RecordingSpotifyClient: SpotifyClient {
        private var nowPlaying: NowPlaying
        private(set) var seeks: [TimeInterval] = []

        init(nowPlaying: NowPlaying) {
            self.nowPlaying = nowPlaying
        }

        func setNowPlaying(_ value: NowPlaying) {
            self.nowPlaying = value
        }

        func fetchNowPlaying() async -> NowPlaying { nowPlaying }
        func playPause() async {}
        func nextTrack() async {}
        func previousTrack() async {}
        func seek(to seconds: TimeInterval) async {
            seeks.append(seconds)
        }
        func openSpotify() async {}
        func openCurrentTrack() async {}
        func openTrack(_ url: URL) async {}
    }

    final actor BlockingSpotifyClient: SpotifyClient {
        private var nowPlaying: NowPlaying
        private(set) var seeks: [TimeInterval] = []

        private var playPauseStarted = false
        private var playPauseStartWaiters: [CheckedContinuation<Void, Never>] = []
        private var playPauseRelease: CheckedContinuation<Void, Never>?

        private var nextStarted = false
        private var nextStartWaiters: [CheckedContinuation<Void, Never>] = []
        private var nextRelease: CheckedContinuation<Void, Never>?

        private var seekStarted = false
        private var seekStartWaiters: [CheckedContinuation<Void, Never>] = []
        private var seekRelease: CheckedContinuation<Void, Never>?

        init(nowPlaying: NowPlaying) {
            self.nowPlaying = nowPlaying
        }

        func fetchNowPlaying() async -> NowPlaying { nowPlaying }

        func playPause() async {
            playPauseStarted = true
            resumePlayPauseStartWaiters()
            await withCheckedContinuation { continuation in
                playPauseRelease = continuation
            }
        }

        func nextTrack() async {
            nextStarted = true
            resumeNextStartWaiters()
            await withCheckedContinuation { continuation in
                nextRelease = continuation
            }
        }

        func previousTrack() async {}

        func seek(to seconds: TimeInterval) async {
            seeks.append(seconds)
            seekStarted = true
            resumeSeekStartWaiters()
            await withCheckedContinuation { continuation in
                seekRelease = continuation
            }
        }

        func openSpotify() async {}
        func openCurrentTrack() async {}
        func openTrack(_ url: URL) async {}

        func waitForPlayPauseStart() async {
            if playPauseStarted { return }
            await withCheckedContinuation { continuation in
                playPauseStartWaiters.append(continuation)
            }
        }

        func waitForNextStart() async {
            if nextStarted { return }
            await withCheckedContinuation { continuation in
                nextStartWaiters.append(continuation)
            }
        }

        func waitForSeekStart() async {
            if seekStarted { return }
            await withCheckedContinuation { continuation in
                seekStartWaiters.append(continuation)
            }
        }

        func completePlayPause(returning value: NowPlaying) {
            nowPlaying = value
            playPauseRelease?.resume()
            playPauseRelease = nil
        }

        func completeNext(returning value: NowPlaying) {
            nowPlaying = value
            nextRelease?.resume()
            nextRelease = nil
        }

        func completeSeek(returning value: NowPlaying) {
            nowPlaying = value
            seekRelease?.resume()
            seekRelease = nil
        }

        private func resumePlayPauseStartWaiters() {
            let waiters = playPauseStartWaiters
            playPauseStartWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }

        private func resumeNextStartWaiters() {
            let waiters = nextStartWaiters
            nextStartWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }

        private func resumeSeekStartWaiters() {
            let waiters = seekStartWaiters
            seekStartWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
    }

    // MARK: - Helpers

    private func makeNowPlaying(
        title: String? = nil,
        position: TimeInterval = 0,
        duration: TimeInterval = 200,
        playbackState: PlaybackState = .playing
    ) -> NowPlaying {
        var np = NowPlaying.empty
        np.title = title
        np.position = position
        np.duration = duration
        np.availability = .ok
        np.playbackState = playbackState
        return np
    }

    private func makeRecording() -> RecordingSpotifyClient {
        RecordingSpotifyClient(nowPlaying: makeNowPlaying())
    }

    private func makeViewModel(client: SpotifyClient) async -> NowPlayingViewModel {
        let vm = NowPlayingViewModel(client: client, artworkLoader: ArtworkLoader(), autoStart: false)
        await vm.refresh()
        return vm
    }

    // MARK: - Cases

    func test_seekWithinRange_recordsExactValue() async {
        let client = makeRecording()
        let vm = await makeViewModel(client: client)

        await vm.endSeekDrag(at: 50)

        let seeks = await client.seeks
        XCTAssertEqual(seeks.count, 1)
        XCTAssertEqual(seeks.first ?? .nan, 50, accuracy: 0.001)
    }

    func test_seekBelowZero_clampsToZero() async {
        let client = makeRecording()
        let vm = await makeViewModel(client: client)

        await vm.endSeekDrag(at: -10)

        let seeks = await client.seeks
        XCTAssertEqual(seeks.count, 1)
        XCTAssertEqual(seeks.first ?? .nan, 0, accuracy: 0.001)
    }

    func test_seekAboveDuration_clampsToDuration() async {
        let client = makeRecording()
        let vm = await makeViewModel(client: client)

        await vm.endSeekDrag(at: 999)

        let seeks = await client.seeks
        XCTAssertEqual(seeks.count, 1)
        XCTAssertEqual(seeks.first ?? .nan, 200, accuracy: 0.001)
    }

    func test_seekNaN_clampsToZero() async {
        let client = makeRecording()
        let vm = await makeViewModel(client: client)

        await vm.endSeekDrag(at: .nan)

        let seeks = await client.seeks
        XCTAssertEqual(seeks.count, 1)
        XCTAssertEqual(seeks.first ?? .nan, 0, accuracy: 0.001)
    }

    func test_seekInfinity_clampsToDuration() async {
        let client = makeRecording()
        let vm = await makeViewModel(client: client)

        await vm.endSeekDrag(at: .infinity)

        let seeks = await client.seeks
        XCTAssertEqual(seeks.count, 1)
        XCTAssertEqual(seeks.first ?? .nan, 200, accuracy: 0.001)
    }

    func test_playPauseOptimisticallyTogglesDisplayStateBeforeRefresh() async {
        let initial = makeNowPlaying(position: 10, playbackState: .playing)
        let confirmed = makeNowPlaying(position: 10, playbackState: .paused)
        let client = BlockingSpotifyClient(nowPlaying: initial)
        let vm = await makeViewModel(client: client)

        let commandTask = Task { await vm.playPause() }
        await client.waitForPlayPauseStart()

        XCTAssertEqual(vm.nowPlaying.playbackState, .playing)
        XCTAssertEqual(vm.displayPlaybackState, .paused)
        XCTAssertTrue(vm.isPlayPausePending)

        await client.completePlayPause(returning: confirmed)
        await commandTask.value

        XCTAssertEqual(vm.nowPlaying.playbackState, .paused)
        XCTAssertEqual(vm.displayPlaybackState, .paused)
        XCTAssertFalse(vm.isPlayPausePending)
    }

    func test_seekCommitKeepsTargetVisibleBeforeRefresh() async {
        let initial = makeNowPlaying(position: 12)
        let confirmed = makeNowPlaying(position: 120)
        let client = BlockingSpotifyClient(nowPlaying: initial)
        let vm = await makeViewModel(client: client)

        vm.beginSeekDrag(at: 80)
        let commandTask = Task { await vm.endSeekDrag(at: 120) }
        await client.waitForSeekStart()

        let seeks = await client.seeks
        XCTAssertFalse(vm.isDraggingSeek)
        XCTAssertEqual(vm.nowPlaying.position, 12, accuracy: 0.001)
        XCTAssertEqual(vm.displayPosition, 120, accuracy: 0.001)
        XCTAssertEqual(seeks.first ?? .nan, 120, accuracy: 0.001)
        XCTAssertTrue(vm.isSeekPending)

        await client.completeSeek(returning: confirmed)
        await commandTask.value

        XCTAssertEqual(vm.displayPosition, 120, accuracy: 0.001)
        XCTAssertFalse(vm.isSeekPending)
    }

    func test_nextOptimisticallyResetsDisplayedPositionBeforeRefresh() async {
        let initial = makeNowPlaying(title: "Current", position: 84)
        let confirmed = makeNowPlaying(title: "Next", position: 2)
        let client = BlockingSpotifyClient(nowPlaying: initial)
        let vm = await makeViewModel(client: client)

        let commandTask = Task { await vm.next() }
        await client.waitForNextStart()

        XCTAssertEqual(vm.nowPlaying.title, "Current")
        XCTAssertEqual(vm.displayPosition, 0, accuracy: 0.001)
        XCTAssertTrue(vm.isNextPending)

        await client.completeNext(returning: confirmed)
        await commandTask.value

        XCTAssertEqual(vm.nowPlaying.title, "Next")
        XCTAssertEqual(vm.displayPosition, 2, accuracy: 0.001)
        XCTAssertFalse(vm.isNextPending)
    }
}
