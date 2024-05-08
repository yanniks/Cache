@testable import Cache
import XCTest

final class MemoryStorageTests: XCTestCase {
    private let key = "youknownothing"
    private let testObject = User(firstName: "John", lastName: "Snow")
    private var storage: MemoryStorage<String, User>!
    private let config = MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10)

    override func setUp() {
        super.setUp()
        self.storage = MemoryStorage<String, User>(config: self.config)
    }

    override func tearDown() {
        self.storage.removeAll()
        super.tearDown()
    }

    /// Test that it saves an object
    func testSetObject() {
        self.storage.setObject(self.testObject, forKey: self.key)
        let cachedObject = try! self.storage.object(forKey: self.key)
        XCTAssertNotNil(cachedObject)
        XCTAssertEqual(cachedObject.firstName, self.testObject.firstName)
        XCTAssertEqual(cachedObject.lastName, self.testObject.lastName)
    }

    func testCacheEntry() {
        // Returns nil if entry doesn't exist
        var entry = try? self.storage.entry(forKey: self.key)
        XCTAssertNil(entry)

        // Returns entry if object exists
        self.storage.setObject(self.testObject, forKey: self.key)
        entry = try! self.storage.entry(forKey: self.key)

        XCTAssertEqual(entry?.object.firstName, self.testObject.firstName)
        XCTAssertEqual(entry?.object.lastName, self.testObject.lastName)
        XCTAssertEqual(entry?.expiry.date, self.config.expiry.date)
    }

    func testSetObjectWithExpiry() {
        let date = Date().addingTimeInterval(1)
        self.storage.setObject(self.testObject, forKey: self.key, expiry: .seconds(1))
        var entry = try! self.storage.entry(forKey: self.key)
        XCTAssertEqual(entry.expiry.date.timeIntervalSinceReferenceDate,
                       date.timeIntervalSinceReferenceDate,
                       accuracy: 0.1)
        // Timer vs sleep: do not complicate
        sleep(1)
        entry = try! self.storage.entry(forKey: self.key)
        XCTAssertEqual(entry.expiry.date.timeIntervalSinceReferenceDate,
                       date.timeIntervalSinceReferenceDate,
                       accuracy: 0.1)
    }

    /// Test that it removes cached object
    func testRemoveObject() {
        self.storage.setObject(self.testObject, forKey: self.key)
        self.storage.removeObject(forKey: self.key)
        let cachedObject = try? self.storage.object(forKey: self.key)
        XCTAssertNil(cachedObject)
    }

    /// Test that it removes expired object
    func testRemoveObjectIfExpiredWhenExpired() {
        let expiry: Expiry = .date(Date().addingTimeInterval(-10))
        self.storage.setObject(self.testObject, forKey: self.key, expiry: expiry)
        self.storage.removeObjectIfExpired(forKey: self.key)
        let cachedObject = try? self.storage.object(forKey: self.key)

        XCTAssertNil(cachedObject)
    }

    /// Test that it doesn't remove not expired object
    func testRemoveObjectIfExpiredWhenNotExpired() {
        self.storage.setObject(self.testObject, forKey: self.key)
        self.storage.removeObjectIfExpired(forKey: self.key)
        let cachedObject = try! self.storage.object(forKey: self.key)

        XCTAssertNotNil(cachedObject)
    }

    /// Test expired object
    func testExpiredObject() throws {
        self.storage.setObject(self.testObject, forKey: self.key, expiry: .seconds(0.9))
        XCTAssertFalse(try! self.storage.isExpiredObject(forKey: self.key))
        sleep(1)
        XCTAssertTrue(try! self.storage.isExpiredObject(forKey: self.key))
    }

    /// Test that it clears cache directory
    func testRemoveAll() {
        self.storage.setObject(self.testObject, forKey: self.key)
        self.storage.removeAll()
        let cachedObject = try? self.storage.object(forKey: self.key)
        XCTAssertNil(cachedObject)
    }

    /// Test that it removes expired objects
    func testClearExpired() {
        let expiry1: Expiry = .date(Date().addingTimeInterval(-10))
        let expiry2: Expiry = .date(Date().addingTimeInterval(10))
        let key1 = "item1"
        let key2 = "item2"
        self.storage.setObject(self.testObject, forKey: key1, expiry: expiry1)
        self.storage.setObject(self.testObject, forKey: key2, expiry: expiry2)
        self.storage.removeExpiredObjects()
        let object1 = try? self.storage.object(forKey: key1)
        let object2 = try! self.storage.object(forKey: key2)

        XCTAssertNil(object1)
        XCTAssertNotNil(object2)
    }
}
