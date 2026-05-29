import XCTest
@testable import Fortress

final class AuditTests: XCTestCase {
    
    func testPasswordStrengthEvaluation() {
        // Test weak password
        let (strength1, score1) = AuditEngine.evaluateStrength("123456")
        XCTAssertEqual(strength1, .weak)
        XCTAssertLessThan(score1, 0.4)
        
        // Test moderate password
        let (strength2, score2) = AuditEngine.evaluateStrength("Password99!")
        XCTAssertEqual(strength2, .moderate)
        
        // Test strong password
        let (strength3, score3) = AuditEngine.evaluateStrength("c0rr3ct-h0rs3-b4tt3ry-st4pl3")
        XCTAssertEqual(strength3, .strong)
        XCTAssertGreaterThanOrEqual(score3, 0.7)
    }
    
    func testPasswordExpirationCheck() {
        // Current date is > 180 days after a past date
        let sixMonthsAgo = Calendar.current.date(byAdding: .day, value: -190, to: Date())
        XCTAssertTrue(AuditEngine.isExpired(lastChanged: sixMonthsAgo))
        
        // Current date is < 180 days after a recent date
        let recentDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        XCTAssertFalse(AuditEngine.isExpired(lastChanged: recentDate))
        
        // Nil means expired (never changed)
        XCTAssertTrue(AuditEngine.isExpired(lastChanged: nil))
    }
}
