import Foundation
import CryptoKit

public struct TOTPGenerator {
    
    /// Decodes a Base32 string into raw Data.
    public static func decodeBase32(_ base32: String) -> Data? {
        let characterMap = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let cleaned = base32.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")
            .uppercased()
        
        guard !cleaned.isEmpty else { return nil }
        
        var buffer = [UInt8]()
        var bitContainer: UInt32 = 0
        var bitCount = 0
        
        for char in cleaned {
            guard let val = characterMap.firstIndex(of: char) else {
                return nil // Invalid Base32 character
            }
            let index = characterMap.distance(from: characterMap.startIndex, to: val)
            bitContainer = (bitContainer << 5) | UInt32(index)
            bitCount += 5
            
            if bitCount >= 8 {
                bitCount -= 8
                let byte = UInt8((bitContainer >> bitCount) & 0xFF)
                buffer.append(byte)
            }
        }
        return Data(buffer)
    }
    
    /// Generates a standard 6-digit TOTP code for a given Base32 secret, time, and period (default 30s).
    public static func generateTOTP(secret: String, time: Date = Date(), period: Int = 30) -> String? {
        guard let secretData = decodeBase32(secret) else { return nil }
        
        // Step 1: Calculate the time counter step
        let timeInterval = Int64(time.timeIntervalSince1970) / Int64(period)
        var counter = timeInterval.bigEndian
        let counterData = Data(bytes: &counter, count: MemoryLayout.size(ofValue: counter))
        
        // Step 2: Calculate HMAC-SHA1 using CryptoKit
        let key = SymmetricKey(data: secretData)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let macBytes = Array(mac)
        
        // Step 3: Dynamic Truncation
        guard macBytes.count >= 20 else { return nil }
        let offset = Int(macBytes[macBytes.count - 1] & 0x0F)
        let binary = ((Int(macBytes[offset] & 0x7F) << 24) |
                      (Int(macBytes[offset + 1] & 0xFF) << 16) |
                      (Int(macBytes[offset + 2] & 0xFF) << 8) |
                      (Int(macBytes[offset + 3] & 0xFF)))
        
        // Step 4: Format as a 6-digit code
        let otp = binary % 1_000_000
        return String(format: "%06d", otp)
    }
    
    /// Returns the number of seconds remaining in the current TOTP step (0 to 30).
    public static func secondsRemaining(time: Date = Date(), period: Int = 30) -> Double {
        let timeInterval = time.timeIntervalSince1970
        let currentStep = Int64(timeInterval) / Int64(period)
        let nextStepTime = Double((currentStep + 1) * Int64(period))
        return max(0.0, nextStepTime - timeInterval)
    }
    
    /// Returns the progress (0.0 to 1.0) of the current TOTP validity window.
    public static func validityProgress(time: Date = Date(), period: Int = 30) -> Double {
        return secondsRemaining(time: time, period: period) / Double(period)
    }
}
