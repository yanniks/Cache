@testable import Cache
import XCTest

final class DiskStorageTests: XCTestCase {
    private let key = "youknownothing"
    private let testObject = User(firstName: "John", lastName: "Snow")
    private let fileManager = FileManager()
    private var storage: DiskStorage<String, User>!
    private let config = DiskConfig(name: "Floppy")

    override func setUp() {
        super.setUp()
        self.storage = try! DiskStorage<String, User>(config: self.config, transformer: TransformerFactory.forCodable(ofType: User.self))
    }

    override func tearDown() {
        try? self.storage.removeAll()
        super.tearDown()
    }

    func testInit() {
        // Test that it creates cache directory
        let fileExist = self.fileManager.fileExists(atPath: self.storage.path)
        XCTAssertTrue(fileExist)

        // Test that it returns the default maximum size of a cache
        XCTAssertEqual(self.config.maxSize, 0)
    }

    /// Test that it returns the correct path
    func testDefaultPath() {
        let paths = NSSearchPathForDirectoriesInDomains(
            .cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true
        )
        let path = "\(paths.first!)/\(self.config.name.capitalized)"
        XCTAssertEqual(self.storage.path, path)
    }

    /// Test that it returns the correct path
    func testCustomPath() throws {
        let url = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let customConfig = DiskConfig(name: "SSD", directory: url)

        self.storage = try DiskStorage<String, User>(config: customConfig, transformer: TransformerFactory.forCodable(ofType: User.self))

        XCTAssertEqual(
            self.storage.path,
            url.appendingPathComponent("SSD", isDirectory: true).path
        )
    }

    /// Test that it sets attributes
    func testSetDirectoryAttributes() throws {
        try self.storage.setObject(self.testObject, forKey: self.key)
        try self.storage.setDirectoryAttributes([FileAttributeKey.immutable: true])
        let attributes = try fileManager.attributesOfItem(atPath: self.storage.path)

        XCTAssertTrue(attributes[FileAttributeKey.immutable] as? Bool == true)
        try self.storage.setDirectoryAttributes([FileAttributeKey.immutable: false])
    }

    /// Test that it saves an object
    func testsetObject() throws {
        try self.storage.setObject(self.testObject, forKey: self.key)
        let fileExist = self.fileManager.fileExists(atPath: self.storage.makeFilePath(for: self.key))
        XCTAssertTrue(fileExist)
    }

    /// Test that
    func testCacheEntry() throws {
        // Returns nil if entry doesn't exist
        var entry: Entry<User>?
        do {
            entry = try self.storage.entry(forKey: self.key)
        } catch {}
        XCTAssertNil(entry)

        // Returns entry if object exists
        try self.storage.setObject(self.testObject, forKey: self.key)
        entry = try self.storage.entry(forKey: self.key)
        let attributes = try fileManager.attributesOfItem(atPath: self.storage.makeFilePath(for: self.key))
        let expiry = Expiry.date(attributes[FileAttributeKey.modificationDate] as! Date)

        XCTAssertEqual(entry?.object.firstName, self.testObject.firstName)
        XCTAssertEqual(entry?.object.lastName, self.testObject.lastName)
        XCTAssertEqual(entry?.expiry.date, expiry.date)
    }

    func testCacheEntryPath() throws {
        let key = "test.mp4"
        try storage.setObject(self.testObject, forKey: key)
        let entry = try storage.entry(forKey: key)
        let filePath = self.storage.makeFilePath(for: key)

        XCTAssertEqual(entry.filePath, filePath)
    }

    /// Test that it resolves cached object
    func testSetObject() throws {
        try self.storage.setObject(self.testObject, forKey: self.key)
        let cachedObject: User? = try storage.object(forKey: self.key)

        XCTAssertEqual(cachedObject?.firstName, self.testObject.firstName)
        XCTAssertEqual(cachedObject?.lastName, self.testObject.lastName)
    }

    /// Test that it removes cached object
    func testRemoveObject() throws {
        try self.storage.setObject(self.testObject, forKey: self.key)
        try self.storage.removeObject(forKey: self.key)
        let fileExist = self.fileManager.fileExists(atPath: self.storage.makeFilePath(for: self.key))
        XCTAssertFalse(fileExist)
    }

    /// Test that it removes expired object
    func testRemoveObjectIfExpiredWhenExpired() throws {
        let expiry: Expiry = .date(Date().addingTimeInterval(-100_000))
        try self.storage.setObject(self.testObject, forKey: self.key, expiry: expiry)
        try self.storage.removeObjectIfExpired(forKey: self.key)
        var cachedObject: User?
        do {
            cachedObject = try self.storage.object(forKey: self.key)
        } catch {}

        XCTAssertNil(cachedObject)
    }

    /// Test that it doesn't remove not expired object
    func testRemoveObjectIfExpiredWhenNotExpired() throws {
        try self.storage.setObject(self.testObject, forKey: self.key)
        try self.storage.removeObjectIfExpired(forKey: self.key)
        let cachedObject: User? = try storage.object(forKey: self.key)
        XCTAssertNotNil(cachedObject)
    }

    /// Test expired object
    func testExpiredObject() throws {
        try self.storage.setObject(self.testObject, forKey: self.key, expiry: .seconds(0.9))
        XCTAssertFalse(try! self.storage.isExpiredObject(forKey: self.key))
        sleep(1)
        XCTAssertTrue(try! self.storage.isExpiredObject(forKey: self.key))
    }

    /// Test that it clears cache directory
    func testClear() throws {
        try given("create some files inside folder so that it is not empty") {
            try self.storage.setObject(self.testObject, forKey: self.key)
        }

        when("call removeAll to remove the whole the folder") {
            do {
                try self.storage.removeAll()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        then("the folder should exist") {
            let fileExist = self.fileManager.fileExists(atPath: self.storage.path)
            XCTAssertTrue(fileExist)
        }

        then("the folder should be empty") {
            let contents = try? self.fileManager.contentsOfDirectory(atPath: self.storage.path)
            XCTAssertEqual(contents?.count, 0)
        }
    }

    /// Test that it clears cache files, but keeps root directory
    func testCreateDirectory() {
        do {
            try self.storage.removeAll()
            XCTAssertTrue(self.fileManager.fileExists(atPath: self.storage.path))
            let contents = try? self.fileManager.contentsOfDirectory(atPath: self.storage.path)
            XCTAssertEqual(contents?.count, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    /// Test that it removes expired objects
    func testClearExpired() throws {
        let expiry1: Expiry = .date(Date().addingTimeInterval(-100_000))
        let expiry2: Expiry = .date(Date().addingTimeInterval(100_000))
        let key1 = "item1"
        let key2 = "item2"
        try storage.setObject(self.testObject, forKey: key1, expiry: expiry1)
        try self.storage.setObject(self.testObject, forKey: key2, expiry: expiry2)
        try self.storage.removeExpiredObjects()
        var object1: User?
        let object2 = try storage.object(forKey: key2)

        do {
            object1 = try self.storage.object(forKey: key1)
        } catch {}

        XCTAssertNil(object1)
        XCTAssertNotNil(object2)
    }

    /// Test that it returns a correct file name
    func testMakeFileName() {
        XCTAssertEqual(self.storage.makeFileName(for: self.key), MD5(self.key))
        XCTAssertEqual(self.storage.makeFileName(for: "test.mp4"), "\(MD5("test.mp4")).mp4")
    }

    /// Test that it returns a correct file path
    func testMakeFilePath() {
        let filePath = "\(storage.path)/\(self.storage.makeFileName(for: self.key))"
        XCTAssertEqual(self.storage.makeFilePath(for: self.key), filePath)
    }
}
