import XCTest
@testable import SongBar

final class SpotifyURLTests: XCTestCase {

    // MARK: - shareURL: nil and empty

    func test_shareURL_nil_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: nil))
    }

    func test_shareURL_emptyString_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: ""))
    }

    // MARK: - shareURL: valid URI conversions for each kind

    func test_shareURL_track_convertsToOpenSpotifyURL() {
        let actual = SpotifyURL.shareURL(forURI: "spotify:track:4uLU6hMCjMI75M1A2tKUQC")
        let expected = URL(string: "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC")
        XCTAssertEqual(actual, expected)
    }

    func test_shareURL_album_convertsToOpenSpotifyURL() {
        let actual = SpotifyURL.shareURL(forURI: "spotify:album:0JGOiO34nwfUdDrD612dOp")
        let expected = URL(string: "https://open.spotify.com/album/0JGOiO34nwfUdDrD612dOp")
        XCTAssertEqual(actual, expected)
    }

    func test_shareURL_artist_convertsToOpenSpotifyURL() {
        let actual = SpotifyURL.shareURL(forURI: "spotify:artist:1dfeR4HaWDbWqFHLkxsg1d")
        let expected = URL(string: "https://open.spotify.com/artist/1dfeR4HaWDbWqFHLkxsg1d")
        XCTAssertEqual(actual, expected)
    }

    func test_shareURL_playlist_convertsToOpenSpotifyURL() {
        let actual = SpotifyURL.shareURL(forURI: "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M")
        let expected = URL(string: "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M")
        XCTAssertEqual(actual, expected)
    }

    func test_shareURL_episode_convertsToOpenSpotifyURL() {
        let actual = SpotifyURL.shareURL(forURI: "spotify:episode:512ojhOuo1ktJprKbVcKyQ")
        let expected = URL(string: "https://open.spotify.com/episode/512ojhOuo1ktJprKbVcKyQ")
        XCTAssertEqual(actual, expected)
    }

    func test_shareURL_show_convertsToOpenSpotifyURL() {
        let actual = SpotifyURL.shareURL(forURI: "spotify:show:5CfCWKI5pZ28U0uOzXkDHe")
        let expected = URL(string: "https://open.spotify.com/show/5CfCWKI5pZ28U0uOzXkDHe")
        XCTAssertEqual(actual, expected)
    }

    // MARK: - shareURL: pass-through for already-public URLs

    func test_shareURL_passesThroughOpenSpotifyHttpsURL() {
        let actual = SpotifyURL.shareURL(forURI: "https://open.spotify.com/track/abcdef")
        let expected = URL(string: "https://open.spotify.com/track/abcdef")
        XCTAssertEqual(actual, expected)
    }

    // MARK: - shareURL: rejection cases

    func test_shareURL_emptyId_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: "spotify:track:"))
    }

    func test_shareURL_idWithSpaces_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: "spotify:track:has spaces"))
    }

    func test_shareURL_idWithSlash_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: "spotify:track:abc/def"))
    }

    func test_shareURL_unknownKind_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: "spotify:bogus:abc"))
    }

    func test_shareURL_extraColons_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: "spotify:track:abc:extra"))
    }

    func test_shareURL_notASpotifyUri_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: "not-a-spotify-uri"))
    }

    func test_shareURL_plainTrackPrefix_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: "track:abc"))
    }

    func test_shareURL_wrongHost_returnsNil() {
        XCTAssertNil(SpotifyURL.shareURL(forURI: "https://example.com/track/abc"))
    }

    // MARK: - openURL

    func test_openURL_validTrackURI_returnsShareURL() {
        let actual = SpotifyURL.openURL(forURI: "spotify:track:4uLU6hMCjMI75M1A2tKUQC")
        let expected = URL(string: "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC")
        XCTAssertEqual(actual, expected)
    }

    func test_openURL_nil_returnsNil() {
        XCTAssertNil(SpotifyURL.openURL(forURI: nil))
    }

    func test_openURL_malformed_returnsNil() {
        XCTAssertNil(SpotifyURL.openURL(forURI: "not-a-spotify-uri"))
    }

    func test_openURL_emptyString_returnsNil() {
        XCTAssertNil(SpotifyURL.openURL(forURI: ""))
    }

    func test_openURL_unknownKind_returnsNil() {
        XCTAssertNil(SpotifyURL.openURL(forURI: "spotify:bogus:abc"))
    }
}
