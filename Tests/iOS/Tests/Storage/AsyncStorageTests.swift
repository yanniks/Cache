@testable import Cache
import Dispatch
import XCTest

final class AsyncStorageTests: XCTestCase {
    private var storage: AsyncStorage<String, User>!
    let user = User(firstName: "John", lastName: "Snow")

    override func setUp() {
        super.setUp()
        let memory = MemoryStorage<String, User>(config: MemoryConfig())
        let disk = try! DiskStorage<String, User>(config: DiskConfig(name: "Async Disk"), transformer: TransformerFactory.forCodable(ofType: User.self))
        let hybrid = HybridStorage<String, User>(memoryStorage: memory, diskStorage: disk)
        self.storage = AsyncStorage(storage: hybrid, serialQueue: DispatchQueue(label: "Async"))
    }

    override func tearDown() {
        self.storage.removeAll(completion: { _ in })
        super.tearDown()
    }

    func testSetObject() throws {
        let expectation = self.expectation(description: #function)

        self.storage.setObject(self.user, forKey: "user", completion: { _ in })
        self.storage.object(forKey: "user", completion: { result in
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

    func testRemoveAll() {
        let intStorage = self.storage.transform(transformer: TransformerFactory.forCodable(ofType: Int.self))
        let expectation = self.expectation(description: #function)
        given("add a lot of objects") {
            for item in Array(0 ..< 100) {
                intStorage.setObject(item, forKey: "key-\(item)", completion: { _ in })
            }
        }

        when("remove all") {
            intStorage.removeAll(completion: { _ in })
        }

        then("all are removed") {
            intStorage.objectExists(forKey: "key-99", completion: { result in
                switch result {
                case .success:
                    XCTFail()
                default:
                    expectation.fulfill()
                }
            })
        }

        wait(for: [expectation], timeout: 1)
    }
}
