import XCTest
@testable import SongBar

final class TimeFormatterTests: XCTestCase {
    func test_placeholder() throws { XCTAssertEqual(TimeFormatter.format(seconds: 0), "0:00") }
}
