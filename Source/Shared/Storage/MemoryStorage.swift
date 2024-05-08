import Foundation

public class MemoryStorage<Key: Hashable, Value>: StorageAware {
    final class WrappedKey: NSObject {
        let key: Key

        init(_ key: Key) { self.key = key }

        override var hash: Int { self.key.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? WrappedKey else {
                return false
            }

            return value.key == self.key
        }
    }

    fileprivate let cache = NSCache<WrappedKey, MemoryCapsule>()
    // Memory cache keys
    fileprivate var keys = Set<Key>()
    /// Configuration
    fileprivate let config: MemoryConfig

    public init(config: MemoryConfig) {
        self.config = config
        self.cache.countLimit = Int(config.countLimit)
        self.cache.totalCostLimit = Int(config.totalCostLimit)
    }
}

public extension MemoryStorage {
    var allKeys: [Key] {
        Array(self.keys)
    }

    var allObjects: [Value] {
        self.allKeys.compactMap { try? object(forKey: $0) }
    }

    func setObject(_ object: Value, forKey key: Key, expiry: Expiry? = nil) {
        let capsule = MemoryCapsule(value: object, expiry: .date(expiry?.date ?? self.config.expiry.date))
        self.cache.setObject(capsule, forKey: WrappedKey(key))
        self.keys.insert(key)
    }

    func removeAll() {
        self.cache.removeAllObjects()
        self.keys.removeAll()
    }

    func removeExpiredObjects() {
        let allKeys = self.keys
        for key in allKeys {
            self.removeObjectIfExpired(forKey: key)
        }
    }

    func removeObjectIfExpired(forKey key: Key) {
        if let capsule = cache.object(forKey: WrappedKey(key)), capsule.expiry.isExpired {
            self.removeObject(forKey: key)
        }
    }

    func removeObject(forKey key: Key) {
        self.cache.removeObject(forKey: WrappedKey(key))
        self.keys.remove(key)
    }

    func removeInMemoryObject(forKey key: Key) throws {
        self.cache.removeObject(forKey: WrappedKey(key))
        self.keys.remove(key)
    }

    func entry(forKey key: Key) throws -> Entry<Value> {
        guard let capsule = cache.object(forKey: WrappedKey(key)) else {
            throw StorageError.notFound
        }

        guard let object = capsule.object as? Value else {
            throw StorageError.typeNotMatch
        }

        return Entry(object: object, expiry: capsule.expiry)
    }
}

public extension MemoryStorage {
    func transform<U>() -> MemoryStorage<Key, U> {
        let storage = MemoryStorage<Key, U>(config: config)
        return storage
    }
}
