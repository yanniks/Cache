import Dispatch
import Foundation

/// Manipulate storage in a "all async" manner.
/// The completion closure will be called when operation completes.
public class AsyncStorage<Key: Hashable, Value> {
    public let innerStorage: HybridStorage<Key, Value>
    public let serialQueue: DispatchQueue

    public init(storage: HybridStorage<Key, Value>, serialQueue: DispatchQueue) {
        self.innerStorage = storage
        self.serialQueue = serialQueue
    }
}

public extension AsyncStorage {
    func entry(forKey key: Key, completion: @escaping (Result<Entry<Value>, Error>) -> Void) {
        self.serialQueue.async { [weak self] in
            guard let self else {
                completion(.failure(StorageError.deallocated))
                return
            }

            do {
                let anEntry = try self.innerStorage.entry(forKey: key)
                completion(.success(anEntry))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func removeObject(forKey key: Key, completion: @escaping (Result<Void, Error>) -> Void) {
        self.serialQueue.async { [weak self] in
            guard let self else {
                completion(.failure(StorageError.deallocated))
                return
            }

            do {
                try self.innerStorage.removeObject(forKey: key)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func setObject(
        _ object: Value,
        forKey key: Key,
        expiry: Expiry? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        self.serialQueue.async { [weak self] in
            guard let self else {
                completion(.failure(StorageError.deallocated))
                return
            }

            do {
                try self.innerStorage.setObject(object, forKey: key, expiry: expiry)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func removeAll(completion: @escaping (Result<Void, Error>) -> Void) {
        self.serialQueue.async { [weak self] in
            guard let self else {
                completion(.failure(StorageError.deallocated))
                return
            }

            do {
                try self.innerStorage.removeAll()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func removeExpiredObjects(completion: @escaping (Result<Void, Error>) -> Void) {
        self.serialQueue.async { [weak self] in
            guard let self else {
                completion(.failure(StorageError.deallocated))
                return
            }

            do {
                try self.innerStorage.removeExpiredObjects()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func object(forKey key: Key, completion: @escaping (Result<Value, Error>) -> Void) {
        self.entry(forKey: key, completion: { (result: Result<Entry<Value>, Error>) in
            completion(result.map { entry in
                entry.object
            })
        })
    }

    @available(*, deprecated, renamed: "objectExists(forKey:completion:)")
    func existsObject(
        forKey key: Key,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        self.object(forKey: key, completion: { (result: Result<Value, Error>) in
            completion(result.map { _ in
                true
            })
        })
    }

    func objectExists(
        forKey key: Key,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        self.object(forKey: key, completion: { (result: Result<Value, Error>) in
            completion(result.map { _ in
                true
            })
        })
    }
}

public extension AsyncStorage {
    func transform<U>(transformer: Transformer<U>) -> AsyncStorage<Key, U> {
        let storage = AsyncStorage<Key, U>(
            storage: innerStorage.transform(transformer: transformer),
            serialQueue: self.serialQueue
        )

        return storage
    }
}
