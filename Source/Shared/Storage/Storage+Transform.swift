#if canImport(UIKit)
    import UIKit
#endif

import Foundation

public extension Storage {
    func transformData() -> Storage<Key, Data> {
        let storage = transform(transformer: TransformerFactory.forData())
        return storage
    }

    #if !os(Linux)
        func transformImage() -> Storage<Key, Image> {
            let storage = transform(transformer: TransformerFactory.forImage())
            return storage
        }
    #endif

    func transformCodable<U: Codable>(ofType: U.Type) -> Storage<Key, U> {
        let storage = transform(transformer: TransformerFactory.forCodable(ofType: U.self))
        return storage
    }
}
