import Foundation
import CryptoKit
import CommonCrypto

public enum CryptoError: Error, LocalizedError {
    case keyDerivationFailed
    case encryptionFailed(String)
    case decryptionFailed(String)
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .keyDerivationFailed:
            return "Failed to derive key from master password."
        case .encryptionFailed:
            return "Encryption failed."
        case .decryptionFailed:
            return "Incorrect Master Password. Please check your password and try again."
        case .invalidData:
            return "The data format is invalid."
        }
    }
}

public struct CryptoEngine {
    
    /// Derives a 256-bit key from a password and salt using PBKDF2 with SHA-256 and 100,000 iterations.
    public static func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        let passwordBytes = Array(password.utf8)
        let saltBytes = Array(salt)
        var derivedKeyBytes = [UInt8](repeating: 0, count: 32) // 256 bits
        
        let result = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password,
            passwordBytes.count,
            saltBytes,
            saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            100_000,
            &derivedKeyBytes,
            derivedKeyBytes.count
        )
        
        guard result == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }
        
        return SymmetricKey(data: Data(derivedKeyBytes))
    }
    
    /// Encrypts raw data using AES-GCM-256 with the provided symmetric key.
    /// Returns the combined format containing the nonce, ciphertext, and tag.
    public static func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed("Unable to create combined sealed box representation.")
            }
            return combined
        } catch {
            throw CryptoError.encryptionFailed(error.localizedDescription)
        }
    }
    
    /// Decrypts a combined AES-GCM-256 package using the provided symmetric key.
    public static func decrypt(combinedData: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            throw CryptoError.decryptionFailed(error.localizedDescription)
        }
    }
    
    /// Generates a new cryptographically secure random 256-bit symmetric key.
    public static func generateSymmetricKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    /// Wraps (encrypts) the Symmetric Master Key using a derived Master Key.
    public static func wrapSMK(smk: SymmetricKey, masterKey: SymmetricKey) throws -> Data {
        let rawSMK = smk.withUnsafeBytes { Data($0) }
        return try encrypt(data: rawSMK, key: masterKey)
    }
    
    /// Unwraps (decrypts) the Symmetric Master Key using a derived Master Key.
    public static func unwrapSMK(wrappedSMK: Data, masterKey: SymmetricKey) throws -> SymmetricKey {
        let rawSMK = try decrypt(combinedData: wrappedSMK, key: masterKey)
        return SymmetricKey(data: rawSMK)
    }
}
