import Foundation

/// Save objects to file on disk
public final class DiskStorage<Key: Hashable, Value> {
    enum Error: Swift.Error {
        case fileEnumeratorFailed
    }

    /// File manager to read/write to the disk
    public let fileManager: FileManager
    /// Configuration
    private let config: DiskConfig
    /// The computed path `directory+name`
    public let path: String
    /// The closure to be called when single file has been removed
    var onRemove: ((String) -> Void)?

    private let transformer: Transformer<Value>
    private let hasher = Hasher.constantAccrossExecutions()

    // MARK: - Initialization

    public convenience init(config: DiskConfig, fileManager: FileManager = FileManager.default, transformer: Transformer<Value>) throws {
        let url: URL = if let directory = config.directory {
            directory
        } else {
            try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        // path
        let path = url.appendingPathComponent(config.name, isDirectory: true).path

        self.init(config: config, fileManager: fileManager, path: path, transformer: transformer)

        try createDirectory()

        #if !os(Linux)
            if let protectionType = config.protectionType {
                try setDirectoryAttributes([
                    FileAttributeKey.protectionKey: protectionType
                ])
            }
        #endif
    }

    public required init(config: DiskConfig, fileManager: FileManager = FileManager.default, path: String, transformer: Transformer<Value>) {
        self.config = config
        self.fileManager = fileManager
        self.path = path
        self.transformer = transformer
    }
}

extension DiskStorage: StorageAware {
    public var allKeys: [Key] { [] }

    public var allObjects: [Value] { [] }

    public func entry(forKey key: Key) throws -> Entry<Value> {
        let filePath = makeFilePath(for: key)
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath, isDirectory: false))
        let attributes = try fileManager.attributesOfItem(atPath: filePath)
        let object = try transformer.fromData(data)

        guard let date = attributes[.modificationDate] as? Date else {
            throw StorageError.malformedFileAttributes
        }

        return Entry(
            object: object,
            expiry: Expiry.date(date),
            filePath: filePath
        )
    }

    public func setObject(_ object: Value, forKey key: Key, expiry: Expiry? = nil) throws {
        let expiry = expiry ?? self.config.expiry
        let data = try transformer.toData(object)
        let filePath = makeFilePath(for: key)
        _ = self.fileManager.createFile(atPath: filePath, contents: data, attributes: nil)
        try self.fileManager.setAttributes([.modificationDate: expiry.date], ofItemAtPath: filePath)
    }

    public func removeObject(forKey key: Key) throws {
        let filePath = makeFilePath(for: key)
        try fileManager.removeItem(atPath: filePath)
        self.onRemove?(filePath)
    }

    public func removeAll() throws {
        try self.fileManager.removeItem(atPath: self.path)
        try createDirectory()
    }

    public func removeExpiredObjects() throws {
        let storageURL = URL(fileURLWithPath: path, isDirectory: true)
        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .contentModificationDateKey,
            .totalFileAllocatedSizeKey
        ]
        var resourceObjects = [ResourceObject]()
        var filesToDelete = [URL]()
        var totalSize: UInt = 0
        let fileEnumerator = self.fileManager.enumerator(
            at: storageURL,
            includingPropertiesForKeys: resourceKeys,
            options: .skipsHiddenFiles,
            errorHandler: nil
        )

        guard let urlArray = fileEnumerator?.allObjects as? [URL] else {
            throw Error.fileEnumeratorFailed
        }

        for url in urlArray {
            let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
            guard resourceValues.isDirectory != true else {
                continue
            }

            if let expiryDate = resourceValues.contentModificationDate, expiryDate.inThePast {
                filesToDelete.append(url)
                continue
            }

            if let fileSize = resourceValues.totalFileAllocatedSize {
                totalSize += UInt(fileSize)
                resourceObjects.append((url: url, resourceValues: resourceValues))
            }
        }

        // Remove expired objects
        for url in filesToDelete {
            try self.fileManager.removeItem(at: url)
            self.onRemove?(url.path)
        }

        // Remove objects if storage size exceeds max size
        try removeResourceObjects(resourceObjects, totalSize: totalSize)
    }

    public func removeInMemoryObject(forKey _: Key) throws {}
}

extension DiskStorage {
    /**
     Sets attributes on the disk cache folder.
     - Parameter attributes: Directory attributes
     */
    func setDirectoryAttributes(_ attributes: [FileAttributeKey: Any]) throws {
        try self.fileManager.setAttributes(attributes, ofItemAtPath: self.path)
    }
}

typealias ResourceObject = (url: Foundation.URL, resourceValues: URLResourceValues)

extension DiskStorage {
    /**
     Builds file name from the key.
     - Parameter key: Unique key to identify the object in the cache
     - Returns: A md5 string
     */
    func makeFileName(for key: Key) -> String {
        if let key = key as? String {
            let fileExtension = (key as NSString).pathExtension
            let fileName = MD5(key)

            switch fileExtension.isEmpty {
            case true:
                return fileName
            case false:
                return "\(fileName).\(fileExtension)"
            }
        }

        var hasher = self.hasher
        key.hash(into: &hasher)
        return String(hasher.finalize())
    }

    /**
     Builds file path from the key.
     - Parameter key: Unique key to identify the object in the cache
     - Returns: A string path based on key
     */
    func makeFilePath(for key: Key) -> String {
        "\(self.path)/\(self.makeFileName(for: key))"
    }

    func createDirectory() throws {
        guard !self.fileManager.fileExists(atPath: self.path) else {
            return
        }

        try self.fileManager.createDirectory(atPath: self.path, withIntermediateDirectories: true,
                                             attributes: nil)
    }

    /**
     Removes objects if storage size exceeds max size.
     - Parameter objects: Resource objects to remove
     - Parameter totalSize: Total size
     */
    func removeResourceObjects(_ objects: [ResourceObject], totalSize: UInt) throws {
        guard self.config.maxSize > 0, totalSize > self.config.maxSize else {
            return
        }

        var totalSize = totalSize
        let targetSize = self.config.maxSize / 2

        let sortedFiles = objects.sorted {
            if let time1 = $0.resourceValues.contentModificationDate?.timeIntervalSinceReferenceDate,
               let time2 = $1.resourceValues.contentModificationDate?.timeIntervalSinceReferenceDate {
                time1 > time2
            } else {
                false
            }
        }

        for file in sortedFiles {
            try self.fileManager.removeItem(at: file.url)
            self.onRemove?(file.url.path)

            if let fileSize = file.resourceValues.totalFileAllocatedSize {
                totalSize -= UInt(fileSize)
            }

            if totalSize < targetSize {
                break
            }
        }
    }

    /**
     Removes the object from the cache if it's expired.
     - Parameter key: Unique key to identify the object in the cache
     */
    func removeObjectIfExpired(forKey key: Key) throws {
        let filePath = self.makeFilePath(for: key)
        let attributes = try fileManager.attributesOfItem(atPath: filePath)
        if let expiryDate = attributes[.modificationDate] as? Date, expiryDate.inThePast {
            try self.fileManager.removeItem(atPath: filePath)
            self.onRemove?(filePath)
        }
    }
}

public extension DiskStorage {
    func transform<U>(transformer: Transformer<U>) -> DiskStorage<Key, U> {
        let storage = DiskStorage<Key, U>(
            config: config,
            fileManager: fileManager,
            path: path,
            transformer: transformer
        )

        return storage
    }
}

public extension DiskStorage {
    /// Calculates the total size of the cache directory in bytes.
    var totalSize: Int? {
        if let directory = URL(string: self.path), let size = self.fileManager.sizeOfDirectory(at: directory) {
            return size
        }
        return nil
    }
}
