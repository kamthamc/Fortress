import Foundation
import CryptoKit
import SwiftData

public struct VaultBackup: Codable {
    public struct ExportedItem: Codable {
        public var id: UUID
        public var title: String
        public var itemTypeString: String
        public var encryptedData: Data
        public var isBookmarked: Bool
        public var createdAt: Date
        public var updatedAt: Date
        public var isShared: Bool
        public var shareExpiresAt: Date?
        public var maxReads: Int?
        public var currentReads: Int
        
        public init(from item: VaultItem) {
            self.id = item.id
            self.title = item.title
            self.itemTypeString = item.itemTypeString
            self.encryptedData = item.encryptedData
            self.isBookmarked = item.isBookmarked
            self.createdAt = item.createdAt
            self.updatedAt = item.updatedAt
            self.isShared = item.isShared
            self.shareExpiresAt = item.shareExpiresAt
            self.maxReads = item.maxReads
            self.currentReads = item.currentReads
        }
        
        public func toVaultItem() -> VaultItem {
            return VaultItem(
                id: self.id,
                title: self.title,
                itemTypeString: self.itemTypeString,
                encryptedData: self.encryptedData,
                isBookmarked: self.isBookmarked,
                createdAt: self.createdAt,
                updatedAt: self.updatedAt,
                isShared: self.isShared,
                shareExpiresAt: self.shareExpiresAt,
                maxReads: self.maxReads,
                currentReads: self.currentReads
            )
        }
    }
    
    public var version: String
    public var exportedAt: Date
    public var items: [ExportedItem]
}

public struct BackupManager {
    
    /// Exports the provided vault items into a single encrypted binary package.
    /// The package contains a 32-byte salt followed by the AES-GCM encrypted backup payload.
    public static func exportBackup(exportedItems: [VaultBackup.ExportedItem], password: String) throws -> Data {
        // Step 1: Create backup payload structure
        let backup = VaultBackup(version: "1.0", exportedAt: Date(), items: exportedItems)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let serializedJSON = try encoder.encode(backup)
        
        // Step 2: Generate random 32-byte salt for key derivation
        var saltBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        guard status == errSecSuccess else {
            throw CryptoError.encryptionFailed("Unable to generate secure random salt for backup.")
        }
        let salt = Data(saltBytes)
        
        // Step 3: Derive key from password using PBKDF2
        let backupKey = try CryptoEngine.deriveKey(password: password, salt: salt)
        
        // Step 4: Encrypt serialized payload
        let encryptedPayload = try CryptoEngine.encrypt(data: serializedJSON, key: backupKey)
        
        // Step 5: Package format: SALT (32 bytes) + ENCRYPTED PAYLOAD (combined AES-GCM data)
        var package = Data()
        package.append(salt)
        package.append(encryptedPayload)
        
        return package
    }
    
    /// Decrypts a backup package and returns the reconstructed VaultItems.
    public static func importBackup(packageData: Data, password: String) throws -> [VaultBackup.ExportedItem] {
        guard packageData.count > 32 else {
            throw CryptoError.decryptionFailed("Backup file is too small or corrupted.")
        }
        
        // Step 1: Extract salt (first 32 bytes) and ciphertext payload
        let salt = packageData.prefix(32)
        let encryptedPayload = packageData.suffix(from: 32)
        
        // Step 2: Derive decryption key
        let backupKey = try CryptoEngine.deriveKey(password: password, salt: salt)
        
        // Step 3: Decrypt payload
        let decryptedData = try CryptoEngine.decrypt(combinedData: encryptedPayload, key: backupKey)
        
        // Step 4: Deserialize JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(VaultBackup.self, from: decryptedData)
        
        // Step 5: Return exported items
        return backup.items
    }
}
