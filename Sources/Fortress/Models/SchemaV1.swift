import Foundation
import SwiftData

public enum VaultSchemaV1: VersionedSchema {
    public static var versionIdentifier = Schema.Version(1, 0, 0)
    
    public static var models: [any PersistentModel.Type] {
        [VaultItem.self]
    }
    
    @Model
    public final class VaultItem {
        @Attribute(.unique) public var id: UUID
        public var title: String
        public var itemTypeString: String
        public var encryptedData: Data
        public var isBookmarked: Bool
        public var createdAt: Date
        public var updatedAt: Date
        
        // Share & Self-Destruct fields
        public var isShared: Bool
        public var shareExpiresAt: Date?
        public var maxReads: Int?
        public var currentReads: Int
        
        // Access pattern tracking
        public var usageCount: Int = 0
        public var lastAccessedAt: Date? = nil
        
        public init(
            id: UUID = UUID(),
            title: String,
            itemTypeString: String,
            encryptedData: Data,
            isBookmarked: Bool = false,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isShared: Bool = false,
            shareExpiresAt: Date? = nil,
            maxReads: Int? = nil,
            currentReads: Int = 0,
            usageCount: Int = 0,
            lastAccessedAt: Date? = nil
        ) {
            self.id = id
            self.title = title
            self.itemTypeString = itemTypeString
            self.encryptedData = encryptedData
            self.isBookmarked = isBookmarked
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isShared = isShared
            self.shareExpiresAt = shareExpiresAt
            self.maxReads = maxReads
            self.currentReads = currentReads
            self.usageCount = usageCount
            self.lastAccessedAt = lastAccessedAt
        }
        
        // Convenience computed property
        public var itemType: VaultItemType {
            get {
                return VaultItemType(rawValue: itemTypeString) ?? .login
            }
            set {
                itemTypeString = newValue.rawValue
            }
        }
    }
}

public typealias VaultItem = VaultSchemaV1.VaultItem
