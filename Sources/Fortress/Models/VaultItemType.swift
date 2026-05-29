import Foundation

public enum VaultItemType: String, Codable, CaseIterable, Identifiable {
    case login = "Login"
    case bankAccount = "Bank Account"
    case creditCard = "Credit Card"
    case identity = "Identity"
    case secureNote = "Secure Note"
    case membership = "Membership / License"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .login: return "key.horizontal.fill"
        case .bankAccount: return "building.columns.fill"
        case .creditCard: return "creditcard.fill"
        case .identity: return "person.crop.rectangle.stack.fill"
        case .secureNote: return "lock.doc.fill"
        case .membership: return "person.text.rectangle.fill"
        }
    }
}

public enum CustomFieldType: String, Codable, CaseIterable {
    case text = "Text"
    case secure = "Secure text"
    case password = "Password"
    case pin = "PIN"
    case date = "Date"
}

public struct CustomField: Codable, Identifiable, Hashable {
    public var id: UUID
    public var label: String
    public var value: String
    public var fieldType: CustomFieldType
    
    public init(id: UUID = UUID(), label: String = "", value: String = "", fieldType: CustomFieldType = .text) {
        self.id = id
        self.label = label
        self.value = value
        self.fieldType = fieldType
    }
}

public struct PasswordHistoryEntry: Codable, Identifiable, Hashable {
    public var id: UUID
    public var passwordValue: String
    public var changedAt: Date
    
    public init(id: UUID = UUID(), passwordValue: String, changedAt: Date = Date()) {
        self.id = id
        self.passwordValue = passwordValue
        self.changedAt = changedAt
    }
}

// MARK: - Decrypted Payload Structure

public struct VaultItemPayload: Codable {
    // Shared Custom fields
    public var customFields: [CustomField]
    public var passwordHistory: [PasswordHistoryEntry]
    
    // Type-specific optional properties
    // 1. Login details
    public var username: String?
    public var passwordValue: String?
    public var websiteUrl: String?
    public var totpSecret: String?
    public var passwordLastChanged: Date?
    
    // 2. Bank details
    public var bankName: String?
    public var accountNumber: String?
    public var routingOrIFSC: String?
    public var bankPins: [String: String]? // Name (e.g. UPI PIN, ATM PIN) -> PIN value
    
    // 3. Card details
    public var cardholderName: String?
    public var cardNumber: String?
    public var cardExpirationDate: String?
    public var cardCvv: String?
    public var cardPin: String?
    
    // 4. Identity details
    public var fullName: String?
    public var birthDate: String?
    public var idNumber: String?
    public var passportNumber: String?
    public var address: String?
    
    // 5. Secure note
    public var notesContent: String?
    
    // 6. Membership / License / Insurance details
    public var organization: String?
    public var membershipId: String?
    public var membershipExpirationDate: String?
    public var policyNumber: String?
    public var licenseClass: String?
    
    public init(
        customFields: [CustomField] = [],
        passwordHistory: [PasswordHistoryEntry] = [],
        username: String? = nil,
        passwordValue: String? = nil,
        websiteUrl: String? = nil,
        totpSecret: String? = nil,
        passwordLastChanged: Date? = nil,
        bankName: String? = nil,
        accountNumber: String? = nil,
        routingOrIFSC: String? = nil,
        bankPins: [String: String]? = nil,
        cardholderName: String? = nil,
        cardNumber: String? = nil,
        cardExpirationDate: String? = nil,
        cardCvv: String? = nil,
        cardPin: String? = nil,
        fullName: String? = nil,
        birthDate: String? = nil,
        idNumber: String? = nil,
        passportNumber: String? = nil,
        address: String? = nil,
        notesContent: String? = nil,
        organization: String? = nil,
        membershipId: String? = nil,
        membershipExpirationDate: String? = nil,
        policyNumber: String? = nil,
        licenseClass: String? = nil
    ) {
        self.customFields = customFields
        self.passwordHistory = passwordHistory
        self.username = username
        self.passwordValue = passwordValue
        self.websiteUrl = websiteUrl
        self.totpSecret = totpSecret
        self.passwordLastChanged = passwordLastChanged
        self.bankName = bankName
        self.accountNumber = accountNumber
        self.routingOrIFSC = routingOrIFSC
        self.bankPins = bankPins
        self.cardholderName = cardholderName
        self.cardNumber = cardNumber
        self.cardExpirationDate = cardExpirationDate
        self.cardCvv = cardCvv
        self.cardPin = cardPin
        self.fullName = fullName
        self.birthDate = birthDate
        self.idNumber = idNumber
        self.passportNumber = passportNumber
        self.address = address
        self.notesContent = notesContent
        self.organization = organization
        self.membershipId = membershipId
        self.membershipExpirationDate = membershipExpirationDate
        self.policyNumber = policyNumber
        self.licenseClass = licenseClass
    }
}
