import XCTest

extension XCTestCase {
    func given(_: String, closure: () throws -> Void) rethrows {
        try closure()
    }

    func when(_: String, closure: () throws -> Void) rethrows {
        try closure()
    }

    func then(_: String, closure: () throws -> Void) rethrows {
        try closure()
    }
}
