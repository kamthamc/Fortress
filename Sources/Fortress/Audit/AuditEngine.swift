import Foundation
import CryptoKit

public enum PasswordStrength: String, Codable, CaseIterable {
    case weak = "Weak"
    case moderate = "Moderate"
    case strong = "Strong"
    
    public var colorName: String {
        switch self {
        case .weak: return "red"
        case .moderate: return "orange"
        case .strong: return "green"
        }
    }
    
    public var description: String {
        switch self {
        case .weak: return "Weak (Vulnerable to Brute-Force)"
        case .moderate: return "Moderate (Could be Stronger)"
        case .strong: return "Strong & Secure"
        }
    }
    
    public var scoreFraction: Double {
        switch self {
        case .weak: return 0.3
        case .moderate: return 0.6
        case .strong: return 1.0
        }
    }
}

public struct PasswordAuditResult: Identifiable {
    public var id = UUID()
    public var isWeak: Bool
    public var isReused: Bool
    public var isPwned: Bool
    public var isExpired: Bool
    public var strength: PasswordStrength
    public var strengthScore: Double // 0 to 1.0
    public var leakCount: Int
    public var reusedSiblingTitles: [String] = []
    
    public var hasIssues: Bool {
        isWeak || isReused || isPwned || isExpired
    }
}

public struct AuditEngine {
    
    /// Computes the SHA-1 hash of a string in uppercase hex.
    public static func sha1(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02hhX", $0) }.joined()
    }
    
    /// Evaluates password strength and returns a score (0.0 to 1.0) and category.
    public static func evaluateStrength(_ password: String) -> (strength: PasswordStrength, score: Double) {
        guard !password.isEmpty else { return (.weak, 0.0) }
        
        var points = 0.0
        
        // 1. Length checks
        let length = password.count
        if length >= 16 {
            points += 0.4
        } else if length >= 12 {
            points += 0.3
        } else if length >= 8 {
            points += 0.15
        } else {
            points += 0.05
        }
        
        // 2. Character diversity
        let hasLower = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil
        
        var diversityCount = 0
        if hasLower { diversityCount += 1 }
        if hasUpper { diversityCount += 1 }
        if hasDigit { diversityCount += 1 }
        if hasSpecial { diversityCount += 1 }
        
        points += (Double(diversityCount) / 4.0) * 0.4
        
        // 3. Sequential and common checks (penalty)
        let commonPasswords = ["123456", "12345678", "password", "qwerty", "admin", "12345"]
        if commonPasswords.contains(password.lowercased()) {
            points -= 0.5
        }
        
        // Clamp score between 0.0 and 1.0
        let score = max(0.0, min(1.0, points))
        
        let strength: PasswordStrength
        if score >= 0.7 {
            strength = .strong
        } else if score >= 0.4 {
            strength = .moderate
        } else {
            strength = .weak
        }
        
        return (strength, score)
    }
    
    /// Scans a list of items to identify reused passwords.
    /// Returns a set of item IDs that have reused passwords.
    public static func findReusedPasswordIDs(items: [VaultItem], decryptedPayloads: [UUID: VaultItemPayload]) -> Set<UUID> {
        var passwordToItemIDs = [String: Set<UUID>]()
        
        for item in items {
            guard let payload = decryptedPayloads[item.id] else { continue }
            
            // Collect any passwords or PINs
            var passwordsToAud = [String]()
            if let pass = payload.passwordValue, !pass.isEmpty {
                passwordsToAud.append(pass)
            }
            if let pins = payload.bankPins {
                passwordsToAud.append(contentsOf: pins.values.filter { !$0.isEmpty })
            }
            if let pin = payload.cardPin, !pin.isEmpty {
                passwordsToAud.append(pin)
            }
            
            for pass in passwordsToAud {
                passwordToItemIDs[pass, default: Set<UUID>()].insert(item.id)
            }
        }
        
        var reusedIDs = Set<UUID>()
        for (_, ids) in passwordToItemIDs {
            if ids.count > 1 {
                reusedIDs.formUnion(ids)
            }
        }
        
        return reusedIDs
    }
    
    /// Checks if a password has been leaked using HIBP k-Anonymity API (safe, zero-knowledge).
    public static func checkPwned(password: String) async throws -> Int {
        guard !password.isEmpty else { return 0 }
        
        let fullHash = sha1(password)
        let prefix = String(fullHash.prefix(5))
        let suffix = String(fullHash.suffix(from: fullHash.index(fullHash.startIndex, offsetBy: 5)))
        
        guard let url = URL(string: "https://api.pwnedpasswords.com/range/\(prefix)") else {
            return 0
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Fortress-Password-Manager", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return 0
        }
        
        guard let text = String(data: data, encoding: .utf8) else {
            return 0
        }
        
        // Scan returned suffixes
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ":")
            if parts.count == 2 {
                let returnedSuffix = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                if returnedSuffix == suffix {
                    if let count = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                        return count
                    }
                }
            }
        }
        
        return 0
    }
    
    /// Evaluates if a password or security item is expired / needs rotation (e.g. older than 6 months).
    public static func isExpired(lastChanged: Date?, maxAgeDays: Int = 180) -> Bool {
        guard let lastChanged = lastChanged else {
            return true // Never changed means it is expired/needs verification
        }
        if let expirationDate = Calendar.current.date(byAdding: .day, value: maxAgeDays, to: lastChanged) {
            return Date() > expirationDate
        }
        return false
    }
    
    /// Scans the vault items to map which sibling items share identical passwords.
    /// Returns a map of item ID -> list of sibling item titles that have the same password.
    public static func getReusedPasswordMap(items: [VaultItem], decryptedPayloads: [UUID: VaultItemPayload]) -> [UUID: [String]] {
        var passwordToItems = [String: [VaultItem]]()
        
        for item in items {
            guard let payload = decryptedPayloads[item.id] else { continue }
            
            var passwordsToAud = [String]()
            if let pass = payload.passwordValue, !pass.isEmpty {
                passwordsToAud.append(pass)
            }
            if let pins = payload.bankPins {
                passwordsToAud.append(contentsOf: pins.values.filter { !$0.isEmpty })
            }
            if let pin = payload.cardPin, !pin.isEmpty {
                passwordsToAud.append(pin)
            }
            
            for pass in passwordsToAud {
                passwordToItems[pass, default: []].append(item)
            }
        }
        
        var reusedMap = [UUID: [String]]()
        for (_, matchedItems) in passwordToItems {
            if matchedItems.count > 1 {
                for item in matchedItems {
                    let siblingTitles = matchedItems.filter { $0.id != item.id }.map { $0.title }
                    reusedMap[item.id, default: []].append(contentsOf: siblingTitles)
                }
            }
        }
        
        return reusedMap
    }
}
