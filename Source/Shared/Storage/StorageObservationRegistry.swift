import Foundation

/// A protocol used for adding and removing storage observations
public protocol StorageObservationRegistry {
    associatedtype S: StorageAware

    /**
     Registers observation closure which will be removed automatically
     when the weakly captured observer has been deallocated.
     - Parameter observer: Any object that helps determine if the observation is still valid
     - Parameter closure: Observation closure
     - Returns: Token used to cancel the observation and remove the observation closure
     */
    @discardableResult
    func addStorageObserver<O: AnyObject>(
        _ observer: O,
        closure: @escaping (O, S, StorageChange<S.Key>) -> Void
    ) -> ObservationToken

    /// Removes all registered key observers
    func removeAllStorageObservers()
}

// MARK: - StorageChange

public enum StorageChange<Key: Hashable>: Equatable {
    case add(key: Key)
    case remove(key: Key)
    case removeAll
    case removeExpired
    case removeInMemory(key: Key)
}

public func == <Key: Hashable>(lhs: StorageChange<Key>, rhs: StorageChange<Key>) -> Bool {
    switch (lhs, rhs) {
    case let (.add(key1), .add(key2)), let (.remove(key1), .remove(key2)), let (.removeInMemory(key1), .removeInMemory(key2)):
        key1 == key2
    case (.removeAll, .removeAll), (.removeExpired, .removeExpired):
        true
    default:
        false
    }
}
