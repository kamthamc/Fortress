import SwiftUI
import SwiftData

public struct ItemEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let itemToEdit: VaultItem? // Nil means creating new item
    let defaultType: VaultItemType // Type to default to if new
    
    // Core parameters
    @State private var title = ""
    @State private var itemType: VaultItemType = .login
    
    // Form payloads
    @State private var username = ""
    @State private var passwordValue = ""
    @State private var websiteUrl = ""
    @State private var totpSecret = ""
    
    // Bank account fields
    @State private var bankName = ""
    @State private var accountNumber = ""
    @State private var routingOrIFSC = ""
    @State private var bankPinsList: [BankPinEntry] = []
    
    // Card fields
    @State private var cardholderName = ""
    @State private var cardNumber = ""
    @State private var cardExpirationDate = ""
    @State private var cardCvv = ""
    @State private var cardPin = ""
    
    // Identity fields
    @State private var fullName = ""
    @State private var birthDate = ""
    @State private var idNumber = ""
    @State private var passportNumber = ""
    @State private var address = ""
    
    // Secure notes field
    @State private var notesContent = ""
    
    // Membership details
    @State private var organization = ""
    @State private var membershipId = ""
    @State private var membershipExpirationDate = ""
    @State private var policyNumber = ""
    @State private var licenseClass = ""
    
    // Dynamic Custom Fields
    @State private var customFieldsList: [CustomField] = []
    
    // Password Generator parameters
    @State private var showGenerator = false
    @State private var generatorMethod = 2 // Defaults to Apple-Style Strong
    @State private var wordCount = 3
    @State private var complexLength = 16
    @State private var includeUpper = true
    @State private var includeNumbers = true
    @State private var includeSymbols = true
    
    struct BankPinEntry: Identifiable {
        let id = UUID()
        var name: String
        var value: String
    }
    
    public init(itemToEdit: VaultItem? = nil, defaultType: VaultItemType = .login) {
        self.itemToEdit = itemToEdit
        self.defaultType = defaultType
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Section 1: Core details
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: itemType.iconName)
                                .foregroundColor(.accentColor)
                                .font(.system(size: 16, weight: .semibold))
                            Text(itemType.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(1.2)
                        }
                        .padding(.bottom, 2)
                        
                        EditField(label: "Title", placeholder: "Title (e.g. Google, Chase Bank)", text: $title)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
                    )
                    
                    // Section 2: Main details card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details".uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(1.2)
                            .padding(.horizontal, 4)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            switch itemType {
                            case .login:
                                EditField(label: "Username / Email", placeholder: "Username or Email", text: $username)
                                
                                EditField(label: "Password", placeholder: "Password", text: $passwordValue, isSecure: true) {
                                    Button {
                                        showGenerator = true
                                    } label: {
                                        Image(systemName: "wand.and.stars")
                                            .foregroundColor(.accentColor)
                                            .font(.system(size: 14, weight: .medium))
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(Color.accentColor.opacity(0.06)))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Generate Password")
                                }
                                
                                if !passwordValue.isEmpty {
                                    let (strength, score) = AuditEngine.evaluateStrength(passwordValue)
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("STRENGTH: \(strength.description)")
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                                .foregroundColor(strengthColor(strength))
                                            Spacer()
                                            Text("\(Int(score * 100))%")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        GeometryReader { geometry in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color.secondary.opacity(0.12))
                                                    .frame(height: 4)
                                                
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(strengthColor(strength))
                                                    .frame(width: geometry.size.width * CGFloat(score), height: 4)
                                            }
                                        }
                                        .frame(height: 4)
                                    }
                                    .padding(.top, 2)
                                    .padding(.bottom, 6)
                                    .padding(.horizontal, 4)
                                }
                                
                                EditField(label: "Website URL", placeholder: "https://example.com", text: $websiteUrl)
                                EditField(label: "TOTP Secret (Base32)", placeholder: "Enter secret key", text: $totpSecret)
                                    .autocorrectionDisabled()
                                
                            case .bankAccount:
                                EditField(label: "Bank Name", placeholder: "Chase, Wells Fargo", text: $bankName)
                                EditField(label: "Account Number", placeholder: "Account Number", text: $accountNumber)
                                EditField(label: "IFSC / Routing Code", placeholder: "Routing Code", text: $routingOrIFSC)
                                
                            case .creditCard:
                                EditField(label: "Cardholder Name", placeholder: "Full Name on Card", text: $cardholderName)
                                EditField(label: "Card Number", placeholder: "16-digit Card Number", text: $cardNumber)
                                
                                HStack(spacing: 12) {
                                    EditField(label: "Expiry (MM/YY)", placeholder: "MM/YY", text: $cardExpirationDate)
                                    EditField(label: "CVV", placeholder: "CVV", text: $cardCvv)
                                    EditField(label: "Card PIN", placeholder: "Card PIN", text: $cardPin)
                                }
                                
                            case .identity:
                                EditField(label: "Full Name", placeholder: "Full Name", text: $fullName)
                                EditField(label: "Date of Birth", placeholder: "YYYY-MM-DD", text: $birthDate)
                                EditField(label: "ID / SSN Number", placeholder: "ID or SSN", text: $idNumber)
                                EditField(label: "Passport Number", placeholder: "Passport Number", text: $passportNumber)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("ADDRESS")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                    
                                    TextEditor(text: $address)
                                        .font(.system(.body, design: .rounded))
                                        .frame(height: 60)
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(nsColorOrUiColor: .listBackgroundColor).opacity(0.3))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                                                )
                                        )
                                }
                                
                            case .secureNote:
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("NOTES")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                    
                                    TextEditor(text: $notesContent)
                                        .font(.system(.body, design: .rounded))
                                        .frame(minHeight: 180)
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(nsColorOrUiColor: .listBackgroundColor).opacity(0.3))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                                                )
                                        )
                                }
                                
                            case .membership:
                                EditField(label: "Organization / Publisher", placeholder: "Organization Name", text: $organization)
                                EditField(label: "Membership / License ID", placeholder: "ID", text: $membershipId)
                                EditField(label: "Expiration Date", placeholder: "YYYY-MM-DD", text: $membershipExpirationDate)
                                EditField(label: "Policy Number", placeholder: "Policy Number", text: $policyNumber)
                                EditField(label: "License Class", placeholder: "Class (e.g. Class C)", text: $licenseClass)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
                    )
                    
                    // Section 3: Security PINs (For bank accounts only)
                    if itemType == .bankAccount {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Security PINs (UPI, ATM, NetBanking)".uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(1.2)
                                .padding(.horizontal, 4)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach($bankPinsList) { $pin in
                                    HStack(alignment: .bottom, spacing: 10) {
                                        EditField(label: "PIN Name", placeholder: "e.g. UPI PIN", text: $pin.name)
                                        
                                        EditField(label: "Value", placeholder: "PIN Value", text: $pin.value, isSecure: true)
                                        
                                        Button {
                                            if reduceMotion {
                                                bankPinsList.removeAll { $0.id == pin.id }
                                            } else {
                                                withAnimation(.easeOut(duration: 0.2)) {
                                                    bankPinsList.removeAll { $0.id == pin.id }
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.system(size: 18))
                                                .frame(width: 28, height: 28)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.bottom, 6)
                                    }
                                }
                                
                                Button {
                                    if reduceMotion {
                                        bankPinsList.append(BankPinEntry(name: "New PIN", value: ""))
                                    } else {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                            bankPinsList.append(BankPinEntry(name: "New PIN", value: ""))
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Account PIN")
                                    }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                                .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
                        )
                    }
                    
                    // Section 4: Custom Fields Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Custom Fields".uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(1.2)
                            .padding(.horizontal, 4)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach($customFieldsList) { $field in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .bottom, spacing: 12) {
                                        EditField(label: "Field Label", placeholder: "Label", text: $field.label)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("FIELD TYPE")
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .tracking(1.0)
                                            
                                            Picker("", selection: $field.fieldType) {
                                                ForEach(CustomFieldType.allCases, id: \.self) { type in
                                                    Text(type.rawValue).tag(type)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            .frame(height: 38)
                                        }
                                        .frame(width: 110)
                                        
                                        Button {
                                            if reduceMotion {
                                                customFieldsList.removeAll { $0.id == field.id }
                                            } else {
                                                withAnimation(.easeOut(duration: 0.2)) {
                                                    customFieldsList.removeAll { $0.id == field.id }
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.system(size: 18))
                                                .frame(width: 28, height: 28)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.bottom, 6)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        EditField(
                                            label: "Field Value",
                                            placeholder: "Value",
                                            text: $field.value,
                                            isSecure: field.fieldType == .secure || field.fieldType == .password || field.fieldType == .pin
                                        ) {
                                            if field.fieldType == .password {
                                                Button {
                                                    field.value = PasswordGenerator.generateComplexPassword(length: 16)
                                                } label: {
                                                    Image(systemName: "wand.and.stars")
                                                        .foregroundColor(.accentColor)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .frame(width: 28, height: 28)
                                                        .background(Circle().fill(Color.accentColor.opacity(0.06)))
                                                }
                                                .buttonStyle(.plain)
                                                .help("Generate Password")
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                        .opacity(0.6)
                                }
                            }
                            
                            Button {
                                if reduceMotion {
                                    customFieldsList.append(CustomField(label: "New Field", value: "", fieldType: .text))
                                } else {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                        customFieldsList.append(CustomField(label: "New Field", value: "", fieldType: .text))
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Custom Field")
                                }
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
                    )
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColorOrUiColor: .listBackgroundColor).opacity(0.5))
            .navigationTitle(itemToEdit == nil ? "New \(itemType.rawValue)" : "Edit \(title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showGenerator) {
                VStack(spacing: 24) {
                    Text("Password Generator")
                        .font(.system(.headline, design: .rounded))
                    
                    Picker("Method", selection: $generatorMethod) {
                        Text("Apple Strong").tag(2)
                        Text("Memorable").tag(0)
                        Text("Complex").tag(1)
                    }
                    .pickerStyle(.segmented)
                    
                    if generatorMethod == 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Apple-Style Strong Password")
                                .font(.system(size: 13, weight: .bold))
                            Text("Generates 18 random characters split into 3 groups separated by hyphens (e.g. abcd12-efgh34-ijkl56), avoiding ambiguous characters like 1, l, 0, O.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("Example: \(PasswordGenerator.generateAppleStylePassword())")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .padding(.top, 4)
                        }
                    } else if generatorMethod == 0 {
                        VStack(alignment: .leading) {
                            Stepper("Words count: \(wordCount)", value: $wordCount, in: 3...6)
                            Text("Example: \(PasswordGenerator.generatePassphrase(wordCount: wordCount))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Stepper("Length: \(complexLength)", value: $complexLength, in: 8...32)
                            Toggle("Include Uppercase", isOn: $includeUpper)
                            Toggle("Include Numbers", isOn: $includeNumbers)
                            Toggle("Include Symbols", isOn: $includeSymbols)
                        }
                    }
                    
                    Button {
                        if generatorMethod == 0 {
                            passwordValue = PasswordGenerator.generatePassphrase(wordCount: wordCount)
                        } else if generatorMethod == 1 {
                            passwordValue = PasswordGenerator.generateComplexPassword(
                                length: complexLength,
                                includeUppercase: includeUpper,
                                includeLowercase: true,
                                includeDigits: includeNumbers,
                                includeSymbols: includeSymbols
                            )
                        } else {
                            passwordValue = PasswordGenerator.generateAppleStylePassword()
                        }
                        showGenerator = false
                    } label: {
                        Text("Generate & Use")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .frame(width: 340)
                .background(Color(nsColorOrUiColor: .windowBackgroundColor))
            }
            .onAppear {
                loadItemData()
            }
        }
    }
    
    // MARK: - Populate edit data
    
    private func loadItemData() {
        guard let item = itemToEdit else {
            title = ""
            itemType = defaultType
            return
        }
        
        title = item.title
        itemType = item.itemType
        
        if let payload = VaultState.shared.decryptItem(item) {
            // General
            customFieldsList = payload.customFields
            
            // Login
            username = payload.username ?? ""
            passwordValue = payload.passwordValue ?? ""
            websiteUrl = payload.websiteUrl ?? ""
            totpSecret = payload.totpSecret ?? ""
            
            // Bank
            bankName = payload.bankName ?? ""
            accountNumber = payload.accountNumber ?? ""
            routingOrIFSC = payload.routingOrIFSC ?? ""
            bankPinsList = (payload.bankPins ?? [:]).map { BankPinEntry(name: $0.key, value: $0.value) }
            
            // Cards
            cardholderName = payload.cardholderName ?? ""
            cardNumber = payload.cardNumber ?? ""
            cardExpirationDate = payload.cardExpirationDate ?? ""
            cardCvv = payload.cardCvv ?? ""
            cardPin = payload.cardPin ?? ""
            
            // Identity
            fullName = payload.fullName ?? ""
            birthDate = payload.birthDate ?? ""
            idNumber = payload.idNumber ?? ""
            passportNumber = payload.passportNumber ?? ""
            address = payload.address ?? ""
            
            // Note
            notesContent = payload.notesContent ?? ""
            
            // Membership
            organization = payload.organization ?? ""
            membershipId = payload.membershipId ?? ""
            membershipExpirationDate = payload.membershipExpirationDate ?? ""
            policyNumber = payload.policyNumber ?? ""
            licenseClass = payload.licenseClass ?? ""
        }
    }
    
    // MARK: - Save item
    
    private func saveItem() {
        let isCreatingNew = (itemToEdit == nil)
        let vaultState = VaultState.shared
        
        // Assemble pins
        var bankPins = [String: String]()
        for pin in bankPinsList {
            if !pin.name.isEmpty {
                bankPins[pin.name] = pin.value
            }
        }
        
        // Calculate history changes (only if password changed)
        var history = [PasswordHistoryEntry]()
        var lastChangedDate = Date()
        
        if let currentItem = itemToEdit, let currentPayload = vaultState.decryptItem(currentItem) {
            history = currentPayload.passwordHistory
            lastChangedDate = currentPayload.passwordLastChanged ?? Date()
            
            // Check if password changed to insert into history
            if let currentPass = currentPayload.passwordValue, currentPass != passwordValue && !currentPass.isEmpty {
                let entry = PasswordHistoryEntry(passwordValue: currentPass, changedAt: lastChangedDate)
                history.insert(entry, at: 0)
                // Limit history to 5 entries
                if history.count > 5 {
                    history.removeLast()
                }
                lastChangedDate = Date()
            }
        }
        
        let payload = VaultItemPayload(
            customFields: customFieldsList,
            passwordHistory: history,
            username: username,
            passwordValue: passwordValue,
            websiteUrl: websiteUrl,
            totpSecret: totpSecret,
            passwordLastChanged: lastChangedDate,
            bankName: bankName,
            accountNumber: accountNumber,
            routingOrIFSC: routingOrIFSC,
            bankPins: bankPins.isEmpty ? nil : bankPins,
            cardholderName: cardholderName,
            cardNumber: cardNumber,
            cardExpirationDate: cardExpirationDate,
            cardCvv: cardCvv,
            cardPin: cardPin,
            fullName: fullName,
            birthDate: birthDate,
            idNumber: idNumber,
            passportNumber: passportNumber,
            address: address,
            notesContent: notesContent,
            organization: organization,
            membershipId: membershipId,
            membershipExpirationDate: membershipExpirationDate,
            policyNumber: policyNumber,
            licenseClass: licenseClass
        )
        
        do {
            let encrypted = try vaultState.encryptItemPayload(payload)
            
            if isCreatingNew {
                let newItem = VaultItem(
                    title: title,
                    itemTypeString: itemType.rawValue,
                    encryptedData: encrypted
                )
                modelContext.insert(newItem)
            } else if let editing = itemToEdit {
                editing.title = title
                editing.encryptedData = encrypted
                editing.updatedAt = Date()
                vaultState.clearCache(for: editing.id)
            }
            
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save vault item: \(error.localizedDescription)")
        }
    }
    
    private func strengthColor(_ strength: PasswordStrength) -> Color {
        switch strength {
        case .weak: return .red
        case .moderate: return .orange
        case .strong: return .green
        }
    }
}

// MARK: - Modern Edit Field Components

struct EditField<RightContent: View>: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool
    let rightContent: RightContent
    
    init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        @ViewBuilder rightContent: () -> RightContent
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.rightContent = rightContent()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.0)
            
            HStack(spacing: 8) {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                }
                
                rightContent
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColorOrUiColor: .listBackgroundColor).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    )
            )
        }
    }
}

extension EditField where RightContent == EmptyView {
    init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false
    ) {
        self.init(label: label, placeholder: placeholder, text: text, isSecure: isSecure) {
            EmptyView()
        }
    }
}
