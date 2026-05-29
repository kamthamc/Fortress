import XCTest
import CryptoKit
@testable import Fortress

final class CryptoEngineTests: XCTestCase {
    
    func testKeyDerivation() {
        let password = "SuperSecretPassword123!"
        let salt = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])
        
        do {
            let key = try CryptoEngine.deriveKey(password: password, salt: salt)
            // Ensure derived key has a valid length (256-bit key = 32 bytes)
            let keyData = key.withUnsafeBytes { Data($0) }
            XCTAssertEqual(keyData.count, 32)
            
            // Check reproducibility
            let key2 = try CryptoEngine.deriveKey(password: password, salt: salt)
            let key2Data = key2.withUnsafeBytes { Data($0) }
            XCTAssertEqual(keyData, key2Data)
        } catch {
            XCTFail("Key derivation failed: \(error.localizedDescription)")
        }
    }
    
    func testAESGCMEncryptionDecryption() {
        let key = CryptoEngine.generateSymmetricKey()
        let plaintextString = "SecureVaultSecretsText!"
        let plaintextData = Data(plaintextString.utf8)
        
        do {
            let ciphertext = try CryptoEngine.encrypt(data: plaintextData, key: key)
            XCTAssertNotEqual(ciphertext, plaintextData)
            
            let decryptedData = try CryptoEngine.decrypt(combinedData: ciphertext, key: key)
            let decryptedString = String(data: decryptedData, encoding: .utf8)
            XCTAssertEqual(plaintextString, decryptedString)
        } catch {
            XCTFail("Encryption/decryption failed: \(error.localizedDescription)")
        }
    }
    
    func testSMKWrapping() {
        let masterKey = CryptoEngine.generateSymmetricKey()
        let smk = CryptoEngine.generateSymmetricKey()
        
        do {
            let wrappedSMK = try CryptoEngine.wrapSMK(smk: smk, masterKey: masterKey)
            let unwrappedSMK = try CryptoEngine.unwrapSMK(wrappedSMK: wrappedSMK, masterKey: masterKey)
            
            let smkData = smk.withUnsafeBytes { Data($0) }
            let unwrappedSMKData = unwrappedSMK.withUnsafeBytes { Data($0) }
            XCTAssertEqual(smkData, unwrappedSMKData)
        } catch {
            XCTFail("SMK wrapping failed: \(error.localizedDescription)")
        }
    }
}
