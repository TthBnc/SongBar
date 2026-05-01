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

    // MARK: - Helpers

    private func makeRecording() -> RecordingSpotifyClient {
        var np = NowPlaying.empty
        np.duration = 200
        np.availability = .ok
        np.playbackState = .playing
        return RecordingSpotifyClient(nowPlaying: np)
    }

    private func makeViewModel(client: RecordingSpotifyClient) async -> NowPlayingViewModel {
        let vm = NowPlayingViewModel(client: client, artworkLoader: ArtworkLoader())
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
}
