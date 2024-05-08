@testable import Cache
import XCTest

final class JSONDecoderExtensionsTests: XCTestCase {
    private var storage: HybridStorage<String, User>!

    override func setUp() {
        super.setUp()
        let memory = MemoryStorage<String, User>(config: MemoryConfig())
        let disk = try! DiskStorage<String, User>(
            config: DiskConfig(name: "HybridDisk"),
            transformer: TransformerFactory.forCodable(ofType: User.self)
        )

        self.storage = HybridStorage(memoryStorage: memory, diskStorage: disk)
    }

    override func tearDown() {
        try? self.storage.removeAll()
        super.tearDown()
    }

    func testJsonDictionary() throws {
        let json: [String: Any] = [
            "first_name": "John",
            "last_name": "Snow",
        ]

        let user = try JSONDecoder.decode(json, to: User.self)
        try self.storage.setObject(user, forKey: "user")

        let cachedObject = try storage.object(forKey: "user")
        XCTAssertEqual(user, cachedObject)
    }

    func testJsonString() throws {
        let string = "{\"first_name\": \"John\", \"last_name\": \"Snow\"}"

        let user = try JSONDecoder.decode(string, to: User.self)
        try self.storage.setObject(user, forKey: "user")

        let cachedObject = try storage.object(forKey: "user")
        XCTAssertEqual(cachedObject.firstName, "John")
    }
}
