@testable import Cache
import XCTest

final class DateCacheTests: XCTestCase {
    func testInThePast() {
        var date = Date(timeInterval: 100_000, since: Date())
        XCTAssertFalse(date.inThePast)

        date = Date(timeInterval: -100_000, since: Date())
        XCTAssertTrue(date.inThePast)
    }
}
