import Foundation
import SwiftUI
import SwiftData
import CryptoKit

@Observable
public final class VaultState {
    public static let shared = VaultState()
    
    public var isSetup: Bool = false
    public var isUnlocked: Bool = false
    public var smk: SymmetricKey? = nil
    public var biometricUnlockAvailable: Bool = false
    public var biometricUnlockEnabled: Bool = false
    public var lastError: String? = nil
    
    // Auto-wipe attempts configuration (0 means disabled)
    public var autoWipeAttemptsLimit: Int {
        get { UserDefaults.standard.integer(forKey: "autoWipeAttemptsLimit") }
        set { UserDefaults.standard.set(newValue, forKey: "autoWipeAttemptsLimit") }
    }
    
    public var failedUnlockAttempts: Int {
        get { UserDefaults.standard.integer(forKey: "failedUnlockAttempts") }
        set { UserDefaults.standard.set(newValue, forKey: "failedUnlockAttempts") }
    }
    
    // In-memory cache of decrypted item payloads to avoid decrypting on every UI layout pass (improves performance significantly!)
    public var decryptedCache: [UUID: VaultItemPayload] = [:]
    
    private init() {
        checkSetupState()
    }
    
    public func checkSetupState() {
        let keychain = KeychainHelper.shared
        do {
            _ = try keychain.loadWrappedSMK()
            _ = try keychain.loadSalt()
            isSetup = true
            biometricUnlockAvailable = keychain.canUseBiometrics()
            biometricUnlockEnabled = keychain.isBiometricUnlockEnabled()
        } catch let error as KeychainError {
            if case .itemNotFound = error {
                isSetup = false
                biometricUnlockEnabled = false
            } else {
                // The item exists but is locked / inaccessible. We are still set up.
                isSetup = true
                biometricUnlockAvailable = keychain.canUseBiometrics()
                biometricUnlockEnabled = keychain.isBiometricUnlockEnabled()
            }
        } catch {
            isSetup = false
            biometricUnlockEnabled = false
        }
    }
    
    /// Initializes the vault with a new Master Password.
    public func setupVault(password: String) async -> Bool {
        let keychain = KeychainHelper.shared
        do {
            // 1. Generate new random salt
            var saltBytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
            let salt = Data(saltBytes)
            
            // 2. Derive Master Key (MK) on background thread
            let masterKey = try await Task.detached(priority: .userInitiated) {
                try CryptoEngine.deriveKey(password: password, salt: salt)
            }.value
            
            // 3. Generate Symmetric Master Key (SMK)
            let newSMK = CryptoEngine.generateSymmetricKey()
            
            // 4. Wrap SMK with Master Key
            let wrappedSMK = try CryptoEngine.wrapSMK(smk: newSMK, masterKey: masterKey)
            
            // 5. Store in Keychain
            try keychain.saveSalt(salt)
            try keychain.saveWrappedSMK(wrappedSMK)
            
            await MainActor.run {
                self.smk = newSMK
                self.isSetup = true
                self.isUnlocked = true
                self.lastError = nil
                self.decryptedCache.removeAll()
            }
            return true
        } catch {
            await MainActor.run {
                self.lastError = "Vault setup failed: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Unlocks the vault using the Master Password.
    public func unlockVault(password: String, enableBiometricsAfterUnlock: Bool = false) async -> Bool {
        let keychain = KeychainHelper.shared
        do {
            // 1. Load salt & wrapped SMK from keychain
            let salt = try keychain.loadSalt()
            let wrappedSMK = try keychain.loadWrappedSMK()
            
            // 2. Derive Master Key on background thread
            let masterKey = try await Task.detached(priority: .userInitiated) {
                try CryptoEngine.deriveKey(password: password, salt: salt)
            }.value
            
            // 3. Unwrap SMK
            let unwrappedSMK = try CryptoEngine.unwrapSMK(wrappedSMK: wrappedSMK, masterKey: masterKey)
            
            // 4. Enable biometrics if requested
            if enableBiometricsAfterUnlock {
                let rawMK = masterKey.withUnsafeBytes { Data($0) }
                try keychain.enableBiometricUnlock(masterKey: rawMK)
            }
            
            await MainActor.run {
                self.smk = unwrappedSMK
                self.isUnlocked = true
                self.lastError = nil
                self.failedUnlockAttempts = 0 // Reset attempts counter on success
                if enableBiometricsAfterUnlock {
                    self.biometricUnlockEnabled = true
                }
            }
            
            return true
        } catch {
            await MainActor.run {
                self.failedUnlockAttempts += 1
                let limit = self.autoWipeAttemptsLimit
                let currentFailed = self.failedUnlockAttempts
                let attemptsLeft = limit > 0 ? (limit - currentFailed) : -1
                
                if limit > 0 && attemptsLeft <= 0 {
                    // Trigger auto wipe
                    resetVault()
                    self.lastError = "Vault has been wiped due to too many failed unlock attempts."
                } else if attemptsLeft > 0 {
                    self.lastError = "Incorrect Master Password. \(attemptsLeft) attempts remaining."
                } else {
                    self.lastError = "Incorrect Master Password. Please try again."
                }
            }
            return false
        }
    }
    
    /// Unlocks the vault using Face ID / Touch ID.
    public func unlockWithBiometrics() -> Bool {
        let keychain = KeychainHelper.shared
        guard keychain.isBiometricUnlockEnabled() else {
            self.lastError = "Biometric unlock not enabled."
            return false
        }
        
        do {
            // Retrieve derived Master Key from biometric-gated Keychain item
            let rawMK = try keychain.retrieveMasterKeyWithBiometrics()
            let masterKey = SymmetricKey(data: rawMK)
            
            // Load wrapped SMK
            let wrappedSMK = try keychain.loadWrappedSMK()
            
            // Unwrap SMK
            let unwrappedSMK = try CryptoEngine.unwrapSMK(wrappedSMK: wrappedSMK, masterKey: masterKey)
            
            self.smk = unwrappedSMK
            self.isUnlocked = true
            self.lastError = nil
            self.failedUnlockAttempts = 0
            return true
        } catch {
            self.lastError = "Biometric authentication failed."
            return false
        }
    }
    
    /// Changes the Master Password. Re-encrypts the SMK wrapper.
    public func changeMasterPassword(oldPassword: String, newPassword: String) async -> Bool {
        let keychain = KeychainHelper.shared
        guard let currentSMK = self.smk else {
            self.lastError = "Vault must be unlocked to change password."
            return false
        }
        
        do {
            let salt = try keychain.loadSalt()
            let wrappedSMK = try keychain.loadWrappedSMK()
            
            // Derive keys and generate signatures on background thread
            let (newSalt, newWrappedSMK, rawNewMK) = try await Task.detached(priority: .userInitiated) {
                let oldMasterKey = try CryptoEngine.deriveKey(password: oldPassword, salt: salt)
                _ = try CryptoEngine.unwrapSMK(wrappedSMK: wrappedSMK, masterKey: oldMasterKey)
                
                var newSaltBytes = [UInt8](repeating: 0, count: 32)
                _ = SecRandomCopyBytes(kSecRandomDefault, newSaltBytes.count, &newSaltBytes)
                let newSalt = Data(newSaltBytes)
                
                let newMasterKey = try CryptoEngine.deriveKey(password: newPassword, salt: newSalt)
                let newWrappedSMK = try CryptoEngine.wrapSMK(smk: currentSMK, masterKey: newMasterKey)
                
                let rawNewMK = newMasterKey.withUnsafeBytes { Data($0) }
                return (newSalt, newWrappedSMK, rawNewMK)
            }.value
            
            // Save to Keychain
            try keychain.saveSalt(newSalt)
            try keychain.saveWrappedSMK(newWrappedSMK)
            
            if keychain.isBiometricUnlockEnabled() {
                try keychain.enableBiometricUnlock(masterKey: rawNewMK)
            }
            
            await MainActor.run {
                self.lastError = nil
            }
            return true
        } catch {
            await MainActor.run {
                self.lastError = "Failed to change master password: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Enables biometric unlock. Requires confirming the current master password.
    public func enableBiometric(password: String) async -> Bool {
        let keychain = KeychainHelper.shared
        do {
            let salt = try keychain.loadSalt()
            
            let rawMK = try await Task.detached(priority: .userInitiated) {
                let masterKey = try CryptoEngine.deriveKey(password: password, salt: salt)
                return masterKey.withUnsafeBytes { Data($0) }
            }.value
            
            try keychain.enableBiometricUnlock(masterKey: rawMK)
            await MainActor.run {
                self.biometricUnlockEnabled = true
            }
            return true
        } catch {
            await MainActor.run {
                self.lastError = "Biometric setup failed."
            }
            return false
        }
    }
    
    /// Disables biometric unlock.
    public func disableBiometric() {
        let keychain = KeychainHelper.shared
        try? keychain.disableBiometricUnlock()
        self.biometricUnlockEnabled = false
    }
    
    /// Locks the vault and erases keys from memory.
    public func lock() {
        self.smk = nil
        self.isUnlocked = false
        self.decryptedCache.removeAll()
    }
    
    /// Factory reset of the application. Erases everything.
    public func resetVault() {
        KeychainHelper.shared.clearAll()
        lock()
        isSetup = false
        checkSetupState()
    }
    
    // MARK: - Decryption & Encryption Helpers for VaultItems
    
    public func decryptItem(_ item: VaultItem) -> VaultItemPayload? {
        // Return cached payload if available
        if let cached = decryptedCache[item.id] {
            return cached
        }
        
        guard let key = smk else { return nil }
        do {
            let decryptedData = try CryptoEngine.decrypt(combinedData: item.encryptedData, key: key)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(VaultItemPayload.self, from: decryptedData)
            decryptedCache[item.id] = payload
            return payload
        } catch {
            return nil
        }
    }
    
    public func encryptItemPayload(_ payload: VaultItemPayload) throws -> Data {
        guard let key = smk else {
            throw CryptoError.encryptionFailed("Vault is locked.")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let serialized = try encoder.encode(payload)
        return try CryptoEngine.encrypt(data: serialized, key: key)
    }
    
    public func clearCache(for itemID: UUID) {
        decryptedCache.removeValue(forKey: itemID)
    }
}
