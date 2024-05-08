@testable import Cache
import XCTest

final class StorageTests: XCTestCase {
    private var storage: Storage<String, User>!
    let user = User(firstName: "John", lastName: "Snow")

    override func setUp() {
        super.setUp()

        self.storage = try! Storage<String, User>(
            diskConfig: DiskConfig(name: "Thor"),
            memoryConfig: MemoryConfig(),
            transformer: TransformerFactory.forCodable(ofType: User.self)
        )
    }

    override func tearDown() {
        try? self.storage.removeAll()
        super.tearDown()
    }

    func testSync() throws {
        try self.storage.setObject(self.user, forKey: "user")
        let cachedObject = try storage.object(forKey: "user")

        XCTAssertEqual(cachedObject, self.user)
    }

    func testAsync() {
        let expectation = self.expectation(description: #function)
        self.storage.async.setObject(self.user, forKey: "user", expiry: nil, completion: { _ in })

        self.storage.async.object(forKey: "user", completion: { result in
            switch result {
            case let .success(cachedUser):
                XCTAssertEqual(cachedUser, self.user)
                expectation.fulfill()
            default:
                XCTFail()
            }
        })

        wait(for: [expectation], timeout: 1)
    }

    func testMigration() {
        struct Person1: Codable {
            let fullName: String
        }

        struct Person2: Codable {
            let firstName: String
            let lastName: String
        }

        let person1Storage = self.storage.transformCodable(ofType: Person1.self)
        let person2Storage = self.storage.transformCodable(ofType: Person2.self)

        // Firstly, save object of type Person1
        let person = Person1(fullName: "John Snow")

        try! person1Storage.setObject(person, forKey: "person")
        XCTAssertNil(try? person2Storage.object(forKey: "person"))

        // Later, convert to Person2, do the migration, then overwrite
        let tempPerson = try! person1Storage.object(forKey: "person")
        let parts = tempPerson.fullName.split(separator: " ")
        let migratedPerson = Person2(firstName: String(parts[0]), lastName: String(parts[1]))
        try! person2Storage.setObject(migratedPerson, forKey: "person")

        XCTAssertEqual(
            try! person2Storage.object(forKey: "person").firstName,
            "John"
        )
    }

    func testSameProperties() {
        struct Person: Codable {
            let firstName: String
            let lastName: String
        }

        struct Alien: Codable {
            let firstName: String
            let lastName: String
        }

        let personStorage = self.storage.transformCodable(ofType: Person.self)
        let alienStorage = self.storage.transformCodable(ofType: Alien.self)

        let person = Person(firstName: "John", lastName: "Snow")
        try! personStorage.setObject(person, forKey: "person")

        // As long as it has same properties, it works too
        let cachedObject = try! alienStorage.object(forKey: "person")
        XCTAssertEqual(cachedObject.firstName, "John")
    }

    // MARK: - Storage observers

    func testAddStorageObserver() throws {
        var changes = [StorageChange<String>]()
        var observer: ObserverMock? = ObserverMock()

        self.storage.addStorageObserver(observer!) { _, _, change in
            changes.append(change)
        }

        try self.storage.setObject(self.user, forKey: "user1")
        try self.storage.setObject(self.user, forKey: "user2")
        try self.storage.removeObject(forKey: "user1")
        try self.storage.removeExpiredObjects()
        try self.storage.removeAll()
        observer = nil
        try self.storage.setObject(self.user, forKey: "user1")

        let expectedChanges: [StorageChange<String>] = [
            .add(key: "user1"),
            .add(key: "user2"),
            .remove(key: "user1"),
            .removeExpired,
            .removeAll,
        ]

        XCTAssertEqual(changes, expectedChanges)
    }

    func testRemoveAllStorageObservers() throws {
        var changes1 = [StorageChange<String>]()
        var changes2 = [StorageChange<String>]()

        self.storage.addStorageObserver(self) { _, _, change in
            changes1.append(change)
        }

        self.storage.addStorageObserver(self) { _, _, change in
            changes2.append(change)
        }

        try self.storage.setObject(self.user, forKey: "user1")
        XCTAssertEqual(changes1, [StorageChange.add(key: "user1")])
        XCTAssertEqual(changes2, [StorageChange.add(key: "user1")])

        changes1.removeAll()
        changes2.removeAll()
        self.storage.removeAllStorageObservers()

        try self.storage.setObject(self.user, forKey: "user1")
        XCTAssertTrue(changes1.isEmpty)
        XCTAssertTrue(changes2.isEmpty)
    }

    // MARK: - Key observers

    func testAddObserverForKey() throws {
        var changes = [KeyChange<User>]()
        self.storage.addObserver(self, forKey: "user1") { _, _, change in
            changes.append(change)
        }

        self.storage.addObserver(self, forKey: "user2") { _, _, change in
            changes.append(change)
        }

        try self.storage.setObject(self.user, forKey: "user1")
        XCTAssertEqual(changes, [KeyChange.edit(before: nil, after: self.user)])
    }

    func testKeyObserverWithRemoveExpired() throws {
        var changes = [KeyChange<User>]()
        self.storage.addObserver(self, forKey: "user1") { _, _, change in
            changes.append(change)
        }

        self.storage.addObserver(self, forKey: "user2") { _, _, change in
            changes.append(change)
        }

        try self.storage.setObject(self.user, forKey: "user1", expiry: Expiry.seconds(-1000))
        try self.storage.removeExpiredObjects()

        XCTAssertEqual(changes, [.edit(before: nil, after: self.user), .remove])
    }

    func testKeyObserverWithRemoveAll() throws {
        var changes1 = [KeyChange<User>]()
        var changes2 = [KeyChange<User>]()

        self.storage.addObserver(self, forKey: "user1") { _, _, change in
            changes1.append(change)
        }

        self.storage.addObserver(self, forKey: "user2") { _, _, change in
            changes2.append(change)
        }

        try self.storage.setObject(self.user, forKey: "user1")
        try self.storage.setObject(self.user, forKey: "user2")
        try self.storage.removeAll()

        XCTAssertEqual(changes1, [.edit(before: nil, after: self.user), .remove])
        XCTAssertEqual(changes2, [.edit(before: nil, after: self.user), .remove])
    }

    func testRemoveKeyObserver() throws {
        var changes = [KeyChange<User>]()

        // Test remove
        self.storage.addObserver(self, forKey: "user1") { _, _, change in
            changes.append(change)
        }

        self.storage.removeObserver(forKey: "user1")
        try self.storage.setObject(self.user, forKey: "user1")
        XCTAssertTrue(changes.isEmpty)

        // Test remove by token
        let token = self.storage.addObserver(self, forKey: "user2") { _, _, change in
            changes.append(change)
        }

        token.cancel()
        try self.storage.setObject(self.user, forKey: "user1")
        XCTAssertTrue(changes.isEmpty)
    }

    func testRemoveAllKeyObservers() throws {
        var changes1 = [KeyChange<User>]()
        var changes2 = [KeyChange<User>]()

        self.storage.addObserver(self, forKey: "user1") { _, _, change in
            changes1.append(change)
        }

        self.storage.addObserver(self, forKey: "user2") { _, _, change in
            changes2.append(change)
        }

        try self.storage.setObject(self.user, forKey: "user1")
        try self.storage.setObject(self.user, forKey: "user2")
        XCTAssertEqual(changes1, [KeyChange.edit(before: nil, after: self.user)])
        XCTAssertEqual(changes2, [KeyChange.edit(before: nil, after: self.user)])

        changes1.removeAll()
        changes2.removeAll()
        self.storage.removeAllKeyObservers()

        try self.storage.setObject(self.user, forKey: "user1")
        XCTAssertTrue(changes1.isEmpty)
        XCTAssertTrue(changes2.isEmpty)
    }
}

private class ObserverMock {}
