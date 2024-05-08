import Foundation

/// Use both memory and disk storage. Try on memory first.
public final class HybridStorage<Key: Hashable, Value> {
    public let memoryStorage: MemoryStorage<Key, Value>
    public let diskStorage: DiskStorage<Key, Value>

    private(set) var storageObservations = [UUID: (HybridStorage, StorageChange<Key>) -> Void]()
    private(set) var keyObservations = [Key: (HybridStorage, KeyChange<Value>) -> Void]()

    public init(memoryStorage: MemoryStorage<Key, Value>, diskStorage: DiskStorage<Key, Value>) {
        self.memoryStorage = memoryStorage
        self.diskStorage = diskStorage

        diskStorage.onRemove = { [weak self] path in
            self?.handleRemovedObject(at: path)
        }
    }

    private func handleRemovedObject(at path: String) {
        notifyObserver(about: .remove) { key in
            let fileName = self.diskStorage.makeFileName(for: key)
            return path.contains(fileName)
        }
    }
}

extension HybridStorage: StorageAware {
    public var allKeys: [Key] {
        self.memoryStorage.allKeys
    }

    public var allObjects: [Value] {
        self.memoryStorage.allObjects
    }

    public func entry(forKey key: Key) throws -> Entry<Value> {
        do {
            return try self.memoryStorage.entry(forKey: key)
        } catch {
            let entry = try diskStorage.entry(forKey: key)
            // set back to memoryStorage
            self.memoryStorage.setObject(entry.object, forKey: key, expiry: entry.expiry)
            return entry
        }
    }

    public func removeObject(forKey key: Key) throws {
        self.memoryStorage.removeObject(forKey: key)
        try self.diskStorage.removeObject(forKey: key)

        notifyStorageObservers(about: .remove(key: key))
    }

    public func removeInMemoryObject(forKey key: Key) throws {
        self.memoryStorage.removeObject(forKey: key)
        notifyStorageObservers(about: .removeInMemory(key: key))
    }

    public func setObject(_ object: Value, forKey key: Key, expiry: Expiry? = nil) throws {
        var keyChange: KeyChange<Value>?

        if self.keyObservations[key] != nil {
            keyChange = .edit(before: try? self.object(forKey: key), after: object)
        }

        self.memoryStorage.setObject(object, forKey: key, expiry: expiry)
        try self.diskStorage.setObject(object, forKey: key, expiry: expiry)

        if let change = keyChange {
            notifyObserver(forKey: key, about: change)
        }

        notifyStorageObservers(about: .add(key: key))
    }

    public func removeAll() throws {
        self.memoryStorage.removeAll()
        try self.diskStorage.removeAll()

        notifyStorageObservers(about: .removeAll)
        notifyKeyObservers(about: .remove)
    }

    public func removeExpiredObjects() throws {
        self.memoryStorage.removeExpiredObjects()
        try self.diskStorage.removeExpiredObjects()

        notifyStorageObservers(about: .removeExpired)
    }
}

public extension HybridStorage {
    func transform<U>(transformer: Transformer<U>) -> HybridStorage<Key, U> {
        let storage = HybridStorage<Key, U>(
            memoryStorage: memoryStorage.transform(),
            diskStorage: self.diskStorage.transform(transformer: transformer)
        )

        return storage
    }
}

extension HybridStorage: StorageObservationRegistry {
    @discardableResult
    public func addStorageObserver<O: AnyObject>(
        _ observer: O,
        closure: @escaping (O, HybridStorage, StorageChange<Key>) -> Void
    ) -> ObservationToken {
        let id = UUID()

        self.storageObservations[id] = { [weak self, weak observer] storage, change in
            guard let observer else {
                self?.storageObservations.removeValue(forKey: id)
                return
            }

            closure(observer, storage, change)
        }

        return ObservationToken { [weak self] in
            self?.storageObservations.removeValue(forKey: id)
        }
    }

    public func removeAllStorageObservers() {
        self.storageObservations.removeAll()
    }

    private func notifyStorageObservers(about change: StorageChange<Key>) {
        for closure in self.storageObservations.values {
            closure(self, change)
        }
    }
}

extension HybridStorage: KeyObservationRegistry {
    @discardableResult
    public func addObserver<O: AnyObject>(
        _ observer: O,
        forKey key: Key,
        closure: @escaping (O, HybridStorage, KeyChange<Value>) -> Void
    ) -> ObservationToken {
        self.keyObservations[key] = { [weak self, weak observer] storage, change in
            guard let observer else {
                self?.removeObserver(forKey: key)
                return
            }

            closure(observer, storage, change)
        }

        return ObservationToken { [weak self] in
            self?.keyObservations.removeValue(forKey: key)
        }
    }

    public func removeObserver(forKey key: Key) {
        self.keyObservations.removeValue(forKey: key)
    }

    public func removeAllKeyObservers() {
        self.keyObservations.removeAll()
    }

    private func notifyObserver(forKey key: Key, about change: KeyChange<Value>) {
        self.keyObservations[key]?(self, change)
    }

    private func notifyObserver(about change: KeyChange<Value>, whereKey closure: (Key) -> Bool) {
        let observation = self.keyObservations.first { key, _ in closure(key) }?.value
        observation?(self, change)
    }

    private func notifyKeyObservers(about change: KeyChange<Value>) {
        for closure in self.keyObservations.values {
            closure(self, change)
        }
    }
}

public extension HybridStorage {
    /// Returns the total size of the underlying DiskStorage in bytes.
    var totalDiskStorageSize: Int? {
        self.diskStorage.totalSize
    }
}
