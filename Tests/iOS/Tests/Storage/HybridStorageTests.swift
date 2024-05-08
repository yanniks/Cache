@testable import Cache
import XCTest

final class HybridStorageTests: XCTestCase {
    private let cacheName = "WeirdoCache"
    private let key = "alongweirdkey"
    private let testObject = User(firstName: "John", lastName: "Targaryen")
    private var storage: HybridStorage<String, User>!
    private let fileManager = FileManager()

    override func setUp() {
        super.setUp()
        let memory = MemoryStorage<String, User>(config: MemoryConfig())
        let disk = try! DiskStorage<String, User>(config: DiskConfig(name: "HybridDisk"), transformer: TransformerFactory.forCodable(ofType: User.self))

        self.storage = HybridStorage(memoryStorage: memory, diskStorage: disk)
    }

    override func tearDown() {
        try? self.storage.removeAll()
        super.tearDown()
    }

    func testSetObject() throws {
        try when("set to storage") {
            try self.storage.setObject(self.testObject, forKey: self.key)
            let cachedObject = try storage.object(forKey: self.key)
            XCTAssertEqual(cachedObject, self.testObject)
        }

        try then("it is set to memory too") {
            let memoryObject = try storage.memoryStorage.object(forKey: self.key)
            XCTAssertNotNil(memoryObject)
        }

        try then("it is set to disk too") {
            let diskObject = try storage.diskStorage.object(forKey: self.key)
            XCTAssertNotNil(diskObject)
        }
    }

    func testEntry() throws {
        let expiryDate = Date()
        try storage.setObject(self.testObject, forKey: self.key, expiry: .date(expiryDate))
        let entry = try storage.entry(forKey: self.key)

        XCTAssertEqual(entry.object, self.testObject)
        XCTAssertEqual(entry.expiry.date, expiryDate)
    }

    /// Should resolve from disk and set in-memory cache if object not in-memory
    func testObjectCopyToMemory() throws {
        try when("set to disk only") {
            try self.storage.diskStorage.setObject(self.testObject, forKey: self.key)
            let cachedObject: User = try storage.object(forKey: self.key)
            XCTAssertEqual(cachedObject, self.testObject)
        }

        try then("there is no object in memory") {
            let inMemoryCachedObject = try storage.memoryStorage.object(forKey: self.key)
            XCTAssertEqual(inMemoryCachedObject, self.testObject)
        }
    }

    func testEntityExpiryForObjectCopyToMemory() throws {
        let date = Date().addingTimeInterval(3)
        try when("set to disk only") {
            try self.storage.diskStorage.setObject(self.testObject, forKey: self.key, expiry: .seconds(3))
            let entry = try storage.entry(forKey: self.key)
            // accuracy for slow disk processes
            XCTAssertEqual(entry.expiry.date.timeIntervalSinceReferenceDate,
                           date.timeIntervalSinceReferenceDate,
                           accuracy: 1.0)
        }

        try then("there is no object in memory") {
            let entry = try storage.memoryStorage.entry(forKey: self.key)
            // accuracy for slow disk processes
            XCTAssertEqual(entry.expiry.date.timeIntervalSinceReferenceDate,
                           date.timeIntervalSinceReferenceDate,
                           accuracy: 1.0)
        }
    }

    /// Removes cached object from memory and disk
    func testRemoveObject() throws {
        try given("set to storage") {
            try self.storage.setObject(self.testObject, forKey: self.key)
            XCTAssertNotNil(try self.storage.object(forKey: self.key))
        }

        try when("remove object from storage") {
            try self.storage.removeObject(forKey: self.key)
            let cachedObject = try? self.storage.object(forKey: self.key)
            XCTAssertNil(cachedObject)
        }

        then("there is no object in memory") {
            let memoryObject = try? self.storage.memoryStorage.object(forKey: self.key)
            XCTAssertNil(memoryObject)
        }

        then("there is no object on disk") {
            let diskObject = try? self.storage.diskStorage.object(forKey: self.key)
            XCTAssertNil(diskObject)
        }
    }

    /// Clears memory and disk cache
    func testClear() throws {
        try when("set and remove all") {
            try self.storage.setObject(self.testObject, forKey: self.key)
            try self.storage.removeAll()
            XCTAssertNil(try? self.storage.object(forKey: self.key))
        }

        then("there is no object in memory") {
            let memoryObject = try? self.storage.memoryStorage.object(forKey: self.key)
            XCTAssertNil(memoryObject)
        }

        then("there is no object on disk") {
            let diskObject = try? self.storage.diskStorage.object(forKey: self.key)
            XCTAssertNil(diskObject)
        }
    }

    func testDiskEmptyAfterClear() throws {
        try self.storage.setObject(self.testObject, forKey: self.key)
        try self.storage.removeAll()

        then("the disk directory is empty") {
            let contents = try? self.fileManager.contentsOfDirectory(atPath: self.storage.diskStorage.path)
            XCTAssertEqual(contents?.count, 0)
        }
    }

    /// Clears expired objects from memory and disk cache
    func testClearExpired() throws {
        let expiry1: Expiry = .date(Date().addingTimeInterval(-10))
        let expiry2: Expiry = .date(Date().addingTimeInterval(10))
        let key1 = "key1"
        let key2 = "key2"

        try when("save 2 objects with different keys and expiry") {
            try self.storage.setObject(self.testObject, forKey: key1, expiry: expiry1)
            try self.storage.setObject(self.testObject, forKey: key2, expiry: expiry2)
        }

        try when("remove expired objects") {
            try self.storage.removeExpiredObjects()
        }

        then("object with key2 survived") {
            XCTAssertNil(try? self.storage.object(forKey: key1))
            XCTAssertNotNil(try? self.storage.object(forKey: key2))
        }
    }

    // MARK: - Storage observers

    func testAddStorageObserver() throws {
        var changes = [StorageChange<String>]()
        self.storage.addStorageObserver(self) { _, _, change in
            changes.append(change)
        }

        try self.storage.setObject(self.testObject, forKey: "user1")
        XCTAssertEqual(changes, [StorageChange.add(key: "user1")])
        XCTAssertEqual(self.storage.storageObservations.count, 1)

        self.storage.addStorageObserver(self) { _, _, _ in }
        XCTAssertEqual(self.storage.storageObservations.count, 2)
    }

    func testRemoveStorageObserver() {
        let token = self.storage.addStorageObserver(self) { _, _, _ in }
        XCTAssertEqual(self.storage.storageObservations.count, 1)

        token.cancel()
        XCTAssertTrue(self.storage.storageObservations.isEmpty)
    }

    func testRemoveAllStorageObservers() {
        self.storage.addStorageObserver(self) { _, _, _ in }
        self.storage.addStorageObserver(self) { _, _, _ in }
        XCTAssertEqual(self.storage.storageObservations.count, 2)

        self.storage.removeAllStorageObservers()
        XCTAssertTrue(self.storage.storageObservations.isEmpty)
    }

    // MARK: - Key observers

    func testAddObserverForKey() throws {
        var changes = [KeyChange<User>]()
        self.storage.addObserver(self, forKey: "user1") { _, _, change in
            changes.append(change)
        }

        XCTAssertEqual(self.storage.keyObservations.count, 1)

        try self.storage.setObject(self.testObject, forKey: "user1")
        XCTAssertEqual(changes, [KeyChange.edit(before: nil, after: self.testObject)])

        self.storage.addObserver(self, forKey: "user1") { _, _, _ in }
        XCTAssertEqual(self.storage.keyObservations.count, 1)

        self.storage.addObserver(self, forKey: "user2") { _, _, _ in }
        XCTAssertEqual(self.storage.keyObservations.count, 2)
    }

    func testRemoveKeyObserver() {
        // Test remove for key
        self.storage.addObserver(self, forKey: "user1") { _, _, _ in }
        XCTAssertEqual(self.storage.keyObservations.count, 1)

        self.storage.removeObserver(forKey: "user1")
        XCTAssertTrue(self.storage.storageObservations.isEmpty)

        // Test remove by token
        let token = self.storage.addObserver(self, forKey: "user2") { _, _, _ in }
        XCTAssertEqual(self.storage.keyObservations.count, 1)

        token.cancel()
        XCTAssertTrue(self.storage.storageObservations.isEmpty)
    }

    func testRemoveAllKeyObservers() {
        self.storage.addObserver(self, forKey: "user1") { _, _, _ in }
        self.storage.addObserver(self, forKey: "user2") { _, _, _ in }
        XCTAssertEqual(self.storage.keyObservations.count, 2)

        self.storage.removeAllKeyObservers()
        XCTAssertTrue(self.storage.keyObservations.isEmpty)
    }
}
