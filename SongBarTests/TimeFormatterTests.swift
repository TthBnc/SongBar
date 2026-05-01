import XCTest
@testable import SongBar

final class TimeFormatterTests: XCTestCase {

    // MARK: - Examples from PRD §23

    func test_zero_formatsAsZeroZeroZero() {
        XCTAssertEqual(TimeFormatter.format(seconds: 0), "0:00")
    }

    func test_fiveSeconds_formatsAsZeroZeroFive() {
        XCTAssertEqual(TimeFormatter.format(seconds: 5), "0:05")
    }

    func test_oneSixtyOneSeconds_formatsAsTwoFortyOne() {
        XCTAssertEqual(TimeFormatter.format(seconds: 161), "2:41")
    }

    func test_sevenTwentyThreeSeconds_formatsAsTwelveZeroThree() {
        XCTAssertEqual(TimeFormatter.format(seconds: 723), "12:03")
    }

    // MARK: - Edge cases

    func test_negative_clampsToZero() {
        XCTAssertEqual(TimeFormatter.format(seconds: -5), "0:00")
    }

    func test_nan_returnsZero() {
        XCTAssertEqual(TimeFormatter.format(seconds: .nan), "0:00")
    }

    func test_positiveInfinity_returnsZero() {
        XCTAssertEqual(TimeFormatter.format(seconds: .infinity), "0:00")
    }

    func test_negativeInfinity_returnsZero() {
        XCTAssertEqual(TimeFormatter.format(seconds: -.infinity), "0:00")
    }

    func test_fractional_floorsToInteger() {
        XCTAssertEqual(TimeFormatter.format(seconds: 5.7), "0:05")
    }

    func test_exactlySixty_formatsAsOneZeroZero() {
        XCTAssertEqual(TimeFormatter.format(seconds: 60), "1:00")
    }

    func test_largeValue_overSixtyMinutes_formatsCorrectly() {
        XCTAssertEqual(TimeFormatter.format(seconds: 3661), "61:01")
    }
}
