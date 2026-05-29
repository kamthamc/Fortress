import Foundation
import Security
import LocalAuthentication

public enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case authFailed
    case unknown(OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "Item already exists in the Keychain."
        case .itemNotFound:
            return "Item not found in the Keychain."
        case .authFailed:
            return "Keychain authentication failed."
        case .unknown(let status):
            return "Keychain error: \(status)"
        }
    }
}

public struct KeychainHelper {
    public static let shared = KeychainHelper()
    
    private let service = "com.fortress.app.security"
    private let masterKeyAccount = "MasterKey"
    private let masterSaltAccount = "MasterSalt"
    private let biometricKeyAccount = "BiometricMasterKey"
    
    private init() {}
    
    // MARK: - Save / Load / Delete Core Methods
    
    public func save(data: Data, forAccount account: String, requireBiometrics: Bool = false) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        
        // Delete existing item first to overwrite
        SecItemDelete(query as CFDictionary)
        
        query[kSecValueData as String] = data
        
        if requireBiometrics {
            var error: Unmanaged<CFError>?
            // kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly ensures that biometrics must be set
            // and the item is backed by the Secure Enclave and doesn't sync via iCloud Keychain.
            guard let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                .userPresence, // TouchID/FaceID or device passcode fallback
                &error
            ) else {
                throw KeychainError.authFailed
            }
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }
    
    public func load(forAccount account: String, prompt: String? = nil) throws -> Data {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let prompt = prompt {
            query[kSecUseOperationPrompt as String] = prompt
        }
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
        
        guard let data = dataTypeRef as? Data else {
            throw KeychainError.unknown(status)
        }
        
        return data
    }
    
    public func delete(forAccount account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    // MARK: - Specialized Helpers
    
    public func saveSalt(_ salt: Data) throws {
        try save(data: salt, forAccount: masterSaltAccount)
    }
    
    public func loadSalt() throws -> Data {
        return try load(forAccount: masterSaltAccount)
    }
    
    public func saveWrappedSMK(_ wrappedSMK: Data) throws {
        try save(data: wrappedSMK, forAccount: masterKeyAccount)
    }
    
    public func loadWrappedSMK() throws -> Data {
        return try load(forAccount: masterKeyAccount)
    }
    
    /// Checks if FaceID or TouchID can be used on this device.
    public func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Stores the derived Master Key in a biometric-gated Keychain item.
    public func enableBiometricUnlock(masterKey: Data) throws {
        try save(data: masterKey, forAccount: biometricKeyAccount, requireBiometrics: true)
    }
    
    /// Disables biometric unlock by deleting the key.
    public func disableBiometricUnlock() throws {
        try delete(forAccount: biometricKeyAccount)
    }
    
    /// Attempts to retrieve the Master Key using Touch ID / Face ID.
    public func retrieveMasterKeyWithBiometrics() throws -> Data {
        let prompt = "Authenticate with biometrics to unlock Fortress"
        return try load(forAccount: biometricKeyAccount, prompt: prompt)
    }
    
    /// Checks if biometric key exists in keychain.
    public func isBiometricUnlockEnabled() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: biometricKeyAccount,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
            kSecReturnData as String: kCFBooleanFalse!
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }
    
    /// Clear all security keys (e.g. for reset/factory settings)
    public func clearAll() {
        _ = try? delete(forAccount: masterKeyAccount)
        _ = try? delete(forAccount: masterSaltAccount)
        _ = try? delete(forAccount: biometricKeyAccount)
    }
}
