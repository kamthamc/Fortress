import XCTest
@testable import Fortress

final class TOTPTests: XCTestCase {
    
    func testBase32Decoding() {
        let base32 = "JBSWY3DPEBLW64TBNQ======"
        let expectedString = "Hello Woral"
        
        let decodedData = TOTPGenerator.decodeBase32(base32)
        XCTAssertNotNil(decodedData)
        
        if let data = decodedData {
            let decodedString = String(data: data, encoding: .utf8)
            XCTAssertEqual(decodedString, expectedString)
        }
    }
    
    func testTOTPGeneration() {
        // Standard TOTP test vector
        let secret = "NY4AIEZ5NX4H4YLD" // Base32 secret
        let testTime = Date(timeIntervalSince1970: 1600000000) // Fixed time step
        
        // Generate TOTP for fixed time
        let code = TOTPGenerator.generateTOTP(secret: secret, time: testTime)
        XCTAssertNotNil(code)
        XCTAssertEqual(code?.count, 6)
        
        // Ensure changing time step updates the code
        let codeFuture = TOTPGenerator.generateTOTP(secret: secret, time: testTime.addingTimeInterval(30))
        XCTAssertNotEqual(code, codeFuture)
    }
}
