import XCTest
@testable import SongBar

final class MenuBarTitleFormatterTests: XCTestCase {

    // MARK: - Helper

    private func makeNowPlaying(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        playbackState: PlaybackState = .playing,
        availability: SpotifyAvailability = .ok,
        position: TimeInterval = 0,
        duration: TimeInterval = 0
    ) -> NowPlaying {
        NowPlaying(
            title: title,
            artist: artist,
            album: album,
            playbackState: playbackState,
            position: position,
            duration: duration,
            artworkURL: nil,
            spotifyURI: nil,
            shareURL: nil,
            availability: availability
        )
    }

    // MARK: - Availability .ok

    func test_ok_artistAndTitle_formatsAsArtistDashTitle() {
        let np = makeNowPlaying(title: "Motion Sickness", artist: "Phoebe Bridgers")
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "Phoebe Bridgers - Motion Sickness")
    }

    func test_ok_paused_doesNotPrependPrefix() {
        // Playback state is conveyed by the menu bar's icon (pause / wave),
        // so the title text stays clean.
        let np = makeNowPlaying(title: "Foo", artist: "Bar", playbackState: .paused)
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "Bar - Foo")
    }

    func test_ok_titleOnly_returnsTitle() {
        let np = makeNowPlaying(title: "Foo", artist: nil)
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "Foo")
    }

    func test_ok_artistOnly_returnsArtist() {
        let np = makeNowPlaying(title: nil, artist: "Bar")
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "Bar")
    }

    func test_ok_bothNil_returnsFallback() {
        let np = makeNowPlaying(title: nil, artist: nil)
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "SongBar")
    }

    func test_ok_bothEmptyStrings_returnsFallback() {
        let np = makeNowPlaying(title: "", artist: "")
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "SongBar")
    }

    // MARK: - Availability variants → fallback

    func test_notRunning_returnsFallback() {
        let np = makeNowPlaying(title: "Foo", artist: "Bar", availability: .notRunning)
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "SongBar")
    }

    func test_notInstalled_returnsFallback() {
        let np = makeNowPlaying(title: "Foo", artist: "Bar", availability: .notInstalled)
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "SongBar")
    }

    func test_automationDenied_returnsFallback() {
        let np = makeNowPlaying(title: "Foo", artist: "Bar", availability: .automationDenied)
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "SongBar")
    }

    func test_noActiveTrack_returnsFallback() {
        let np = makeNowPlaying(title: "Foo", artist: "Bar", availability: .noActiveTrack)
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: np), "SongBar")
    }

    // MARK: - Truncation

    func test_longBase_truncatesToFortyEightWithEllipsis() {
        let np = makeNowPlaying(
            title: "a really long song name that exceeds 48 characters",
            artist: "Verylongartistname - Verylongtitle"
        )
        let result = MenuBarTitleFormatter.format(nowPlaying: np)
        XCTAssertEqual(result.count, 48)
        XCTAssertEqual(result.last, MenuBarTitleFormatter.ellipsis)
    }

    func test_maxLengthOne_returnsEllipsisOnly() {
        let np = makeNowPlaying(title: "Foo", artist: "Bar")
        let result = MenuBarTitleFormatter.format(nowPlaying: np, maxLength: 1)
        XCTAssertEqual(result, String(MenuBarTitleFormatter.ellipsis))
    }

    func test_maxLengthZero_returnsEllipsisOnly() {
        let np = makeNowPlaying(title: "Foo", artist: "Bar")
        let result = MenuBarTitleFormatter.format(nowPlaying: np, maxLength: 0)
        XCTAssertEqual(result, String(MenuBarTitleFormatter.ellipsis))
    }

    func test_shortStringUnderMaxLength_unchanged() {
        let np = makeNowPlaying(title: "Foo", artist: "Bar")
        let result = MenuBarTitleFormatter.format(nowPlaying: np, maxLength: 48)
        XCTAssertEqual(result, "Bar - Foo")
        XCTAssertNotEqual(result.last, MenuBarTitleFormatter.ellipsis)
    }

    func test_pausedDoesNotAffectTruncation() {
        // base = "Bar - <40-char title>" = 46 chars; under 48, no truncation.
        // The Paused: prefix used to be added here; now it isn't, so the
        // title stays untruncated regardless of playback state.
        let title = String(repeating: "a", count: 40)
        let np = makeNowPlaying(title: title, artist: "Bar", playbackState: .paused)
        let result = MenuBarTitleFormatter.format(nowPlaying: np)
        XCTAssertEqual(result.count, 46)
        XCTAssertNotEqual(result.last, MenuBarTitleFormatter.ellipsis)
    }
}
