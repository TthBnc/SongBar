import XCTest
@testable import SongBar

final class SpotifyURLTests: XCTestCase {
    func test_placeholder() throws { XCTAssertNil(SpotifyURL.shareURL(forURI: nil)) }
}
