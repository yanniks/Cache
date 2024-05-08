@testable import Cache
import XCTest

final class HasherConstantAccrossExecutionsTests: XCTestCase {
    func testHashValueRemainsTheSameAsLastTime() {
        // Warning: this test may start failing after a Swift Update
        let value = "some string with some values"
        var hasher = Hasher.constantAccrossExecutions()
        value.hash(into: &hasher)
        XCTAssertEqual(hasher.finalize(), -4_706_942_985_426_845_298)
    }
}
