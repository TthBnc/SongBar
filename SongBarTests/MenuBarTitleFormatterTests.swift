import XCTest
@testable import SongBar

final class MenuBarTitleFormatterTests: XCTestCase {
    func test_placeholder() throws {
        XCTAssertEqual(MenuBarTitleFormatter.format(nowPlaying: .empty), "SongBar")
    }
}
