import SwiftUI
import SwiftData

public struct ItemDetailView: View {
    let item: VaultItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var totpCode = ""
    @State private var secondsRemaining = 30.0
    @State private var showShareSheet = false
    @State private var shareExpiryHours = 1
    @State private var shareMaxReads = 1
    @State private var generatedShareURL = ""
    @State private var showCopiedShareBadge = false
    @State private var showHistoryPopover = false
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    public init(item: VaultItem, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    private var isPasswordExpired: Bool {
        if let payload = VaultState.shared.decryptItem(item) {
            return AuditEngine.isExpired(lastChanged: payload.passwordLastChanged)
        }
        return false
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Block: Title, Category, Star Bookmark
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: item.itemType.iconName)
                                .foregroundColor(.accentColor)
                                .font(.system(size: 16, weight: .semibold))
                            Text(item.itemType.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(1.2)
                        }
                        
                        Text(item.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Bookmark Toggle
                        Button {
                            if reduceMotion {
                                item.isBookmarked.toggle()
                            } else {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    item.isBookmarked.toggle()
                                }
                            }
                        } label: {
                            Image(systemName: item.isBookmarked ? "star.fill" : "star")
                                .font(.system(size: 18))
                                .foregroundColor(item.isBookmarked ? .orange : .secondary)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.secondary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .help(item.isBookmarked ? "Remove Bookmark" : "Bookmark Item")
                        
                        // Edit Action
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 18))
                                .foregroundColor(.accentColor)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.secondary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .help("Edit Item")
                        
                        // Share Action
                        Button {
                            setupShare()
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundColor(.accentColor)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.secondary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .help("Share Item")
                        
                        // Delete Action
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(.red)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.red.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .help("Delete Item")
                    }
                }
                .padding(.bottom, 8)
                
                // Expiry Rotation Warning Badge
                if isPasswordExpired {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Security Alert: It is recommended to update passwords and bank PINs every 3 to 6 months. This item hasn't been updated recently.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
                }
                
                // Content Renderer based on Type
                if let payload = VaultState.shared.decryptItem(item) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // 1. CREDIT CARD RENDERING (Render Card first)
                        if item.itemType == .creditCard {
                            CardView(
                                cardholderName: payload.cardholderName ?? "",
                                cardNumber: payload.cardNumber ?? "",
                                expirationDate: payload.cardExpirationDate ?? "",
                                cvv: payload.cardCvv ?? "",
                                cardPin: payload.cardPin ?? ""
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 8)
                        }
                        
                        // 2. LOGIN TEMPLATE
                        if item.itemType == .login {
                            if let username = payload.username, !username.isEmpty {
                                renderDetailRow(label: "Username", value: username)
                            }
                            if let password = payload.passwordValue, !password.isEmpty {
                                SecureTextField(label: "Password", value: password)
                                
                                // Visual representation of password strength
                                let (strength, score) = AuditEngine.evaluateStrength(password)
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
                                
                                // Password history summary if available
                                if !payload.passwordHistory.isEmpty {
                                    Button {
                                        showHistoryPopover.toggle()
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock.arrow.2.circlepath")
                                            Text("Password History (\(payload.passwordHistory.count) saved)")
                                            Spacer()
                                        }
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, -8)
                                    .popover(isPresented: $showHistoryPopover) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Password History")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                            
                                            ScrollView {
                                                VStack(alignment: .leading, spacing: 10) {
                                                    ForEach(payload.passwordHistory) { entry in
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            HStack {
                                                                Text(entry.passwordValue)
                                                                    .font(.system(.body, design: .monospaced))
                                                                Spacer()
                                                                Button {
                                                                    ClipboardUtility.copy(entry.passwordValue)
                                                                } label: {
                                                                    Image(systemName: "doc.on.doc")
                                                                        .font(.system(size: 11))
                                                                        .foregroundColor(.accentColor)
                                                                }
                                                                .buttonStyle(.plain)
                                                            }
                                                            Text("Saved on \(entry.changedAt, formatter: dateFormatter)")
                                                                .font(.system(size: 10))
                                                                .foregroundColor(.secondary)
                                                            Divider()
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(maxHeight: 200)
                                        }
                                        .padding(16)
                                        .frame(width: 280)
                                    }
                                }
                            }
                            if let url = payload.websiteUrl, !url.isEmpty {
                                renderDetailRow(label: "Website URL", value: url, isLink: true)
                            }
                            
                            // Interactive TOTP Counter
                            if let totpSecret = payload.totpSecret, !totpSecret.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("ONE-TIME PASSWORD (2FA)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                    
                                    HStack(spacing: 16) {
                                        Text(totpCode.isEmpty ? "••••••" : totpCode)
                                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                                            .foregroundColor(.accentColor)
                                        
                                        Spacer()
                                        
                                        // Circular Progress Ring
                                        ZStack {
                                            Circle()
                                                .stroke(Color.secondary.opacity(0.15), lineWidth: 3.5)
                                                .frame(width: 32, height: 32)
                                            
                                            Circle()
                                                .trim(from: 0.0, to: CGFloat(secondsRemaining / 30.0))
                                                .stroke(secondsRemaining > 5 ? Color.accentColor : Color.red, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                                .frame(width: 32, height: 32)
                                                .rotationEffect(.degrees(-90))
                                            
                                            Text("\(Int(ceil(secondsRemaining)))")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }
                                        .onReceive(timer) { _ in
                                            updateTOTP(secret: totpSecret)
                                        }
                                        .onAppear {
                                            updateTOTP(secret: totpSecret)
                                        }
                                        
                                        Button {
                                            ClipboardUtility.copy(totpCode)
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 14))
                                                .foregroundColor(.accentColor)
                                                .frame(width: 28, height: 28)
                                                .background(Circle().fill(Color.accentColor.opacity(0.06)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                                            )
                                    )
                                }
                            }
                        }
                        
                        // 3. BANK ACCOUNT TEMPLATE (With Multiple PIN support)
                        if item.itemType == .bankAccount {
                            if let bankName = payload.bankName, !bankName.isEmpty {
                                renderDetailRow(label: "Bank Name", value: bankName)
                            }
                            if let account = payload.accountNumber, !account.isEmpty {
                                renderDetailRow(label: "Account Number", value: account)
                            }
                            if let routing = payload.routingOrIFSC, !routing.isEmpty {
                                renderDetailRow(label: "IFSC / Routing Code", value: routing)
                            }
                            
                            // Multiple PINs (e.g. Netbanking, UPI, ATM PIN)
                            if let pins = payload.bankPins, !pins.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("BANK ACCOUNT SECURITY PINS")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                    
                                    ForEach(pins.sorted(by: { $0.key < $1.key }), id: \.key) { key, val in
                                        SecureTextField(label: key, value: val)
                                    }
                                }
                            }
                        }
                        
                        // 4. IDENTITY DETAILS TEMPLATE
                        if item.itemType == .identity {
                            if let name = payload.fullName, !name.isEmpty {
                                renderDetailRow(label: "Full Name", value: name)
                            }
                            if let dob = payload.birthDate, !dob.isEmpty {
                                renderDetailRow(label: "Date of Birth", value: dob)
                            }
                            if let idNum = payload.idNumber, !idNum.isEmpty {
                                renderDetailRow(label: "ID/SSN Number", value: idNum)
                            }
                            if let passport = payload.passportNumber, !passport.isEmpty {
                                renderDetailRow(label: "Passport Number", value: passport)
                            }
                            if let address = payload.address, !address.isEmpty {
                                renderDetailRow(label: "Address", value: address)
                            }
                        }
                        
                        // 5. SECURE NOTES TEMPLATE
                        if item.itemType == .secureNote {
                            if let notes = payload.notesContent, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("NOTES")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                    
                                    Text(notes)
                                        .font(.body)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                                                )
                                        )
                                }
                            }
                        }
                        
                        // 6. MEMBERSHIPS / LICENSES / INSURANCE
                        if item.itemType == .membership {
                            if let org = payload.organization, !org.isEmpty {
                                renderDetailRow(label: "Organization / Publisher", value: org)
                            }
                            if let memId = payload.membershipId, !memId.isEmpty {
                                renderDetailRow(label: "Membership / License ID", value: memId)
                            }
                            if let exp = payload.membershipExpirationDate, !exp.isEmpty {
                                renderDetailRow(label: "Expiration Date", value: exp)
                            }
                            if let policy = payload.policyNumber, !policy.isEmpty {
                                renderDetailRow(label: "Policy Number", value: policy)
                            }
                            if let licClass = payload.licenseClass, !licClass.isEmpty {
                                renderDetailRow(label: "License Class", value: licClass)
                            }
                        }
                        
                        // 7. CUSTOM FIELDS RENDERING
                        if !payload.customFields.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("CUSTOM FIELDS")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                ForEach(payload.customFields) { field in
                                    switch field.fieldType {
                                    case .text:
                                        renderDetailRow(label: field.label, value: field.value)
                                    case .secure, .password, .pin:
                                        SecureTextField(label: field.label, value: field.value)
                                    case .date:
                                        renderDetailRow(label: field.label, value: field.value)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("Could not decrypt item. Check your master key.")
                        .foregroundColor(.red)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColorOrUiColor: .listBackgroundColor).opacity(0.5))
        .sheet(isPresented: $showShareSheet) {
            ShareSetupSheet(
                item: item,
                expiryHours: $shareExpiryHours,
                maxReads: $shareMaxReads,
                generatedURL: $generatedShareURL,
                onGenerate: generateShareToken,
                onCopy: copyShareURL,
                showCopied: $showCopiedShareBadge
            )
        }
        .onAppear {
            item.usageCount += 1
            item.lastAccessedAt = Date()
            try? modelContext.save()
        }
    }
    
    private func strengthColor(_ strength: PasswordStrength) -> Color {
        switch strength {
        case .weak: return .red
        case .moderate: return .orange
        case .strong: return .green
        }
    }
    
    private func renderDetailRow(label: String, value: String, isLink: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.0)
            
            HStack {
                if isLink {
                    Link(value, destination: URL(string: value.starts(with: "http") ? value : "https://\(value)") ?? URL(string: "https://google.com")!)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.accentColor)
                } else {
                    Text(value)
                        .font(.body)
                        .textSelection(.enabled)
                }
                
                Spacer()
                
                Button {
                    ClipboardUtility.copy(value)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
    }
    
    private func updateTOTP(secret: String) {
        if let code = TOTPGenerator.generateTOTP(secret: secret) {
            totpCode = code
        }
        secondsRemaining = TOTPGenerator.secondsRemaining()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    // MARK: - Sharing Logic
    
    private func setupShare() {
        if item.isShared {
            // Already sharing, compile current share URL
            let token = item.id.uuidString
            generatedShareURL = "fortress://share?id=\(token)"
        } else {
            generatedShareURL = ""
        }
    }
    
    private func generateShareToken() {
        // Flag item as shared in database with constraints
        item.isShared = true
        item.currentReads = 0
        item.maxReads = shareMaxReads
        item.shareExpiresAt = Calendar.current.date(byAdding: .hour, value: shareExpiryHours, to: Date())
        
        // Save database context
        try? modelContext.save()
        
        // Generate secure link. In a real app, this might contain a base64 encrypted payload or sync via iCloud.
        // For local self-destruct, it triggers the matching record ID on the shared iCloud DB.
        generatedShareURL = "fortress://share?id=\(item.id.uuidString)"
    }
    
    private func copyShareURL() {
        ClipboardUtility.copy(generatedShareURL)
        if reduceMotion {
            showCopiedShareBadge = true
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showCopiedShareBadge = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if reduceMotion {
                showCopiedShareBadge = false
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    showCopiedShareBadge = false
                }
            }
        }
    }
}

// MARK: - Share Setup Sheet View

struct ShareSetupSheet: View {
    let item: VaultItem
    @Binding var expiryHours: Int
    @Binding var maxReads: Int
    @Binding var generatedURL: String
    let onGenerate: () -> Void
    let onCopy: () -> Void
    @Binding var showCopied: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Share Destructible Item")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
            
            Text("Sharing generates a secure iCloud/Local token. Once opened by the recipient, the item will automatically delete from your vault and theirs after the chosen thresholds.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if generatedURL.isEmpty {
                VStack(spacing: 16) {
                    // Expiry timer selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DESTRUCT AFTER DURATION")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Picker("Duration", selection: $expiryHours) {
                            Text("1 Hour").tag(1)
                            Text("4 Hours").tag(4)
                            Text("1 Day").tag(24)
                            Text("7 Days").tag(168)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Max reads selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MAX VIEWS")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Picker("Views", selection: $maxReads) {
                            Text("View Once").tag(1)
                            Text("5 Views").tag(5)
                            Text("10 Views").tag(10)
                            Text("Unlimited").tag(9999)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Button(action: onGenerate) {
                        Text("Create Destructible Share Link")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
            } else {
                VStack(spacing: 16) {
                    Text("Secure Share Link Generated:")
                        .font(.system(size: 14, weight: .semibold))
                    
                    HStack {
                        Text(generatedURL)
                            .font(.system(size: 13, design: .monospaced))
                            .lineLimit(1)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: onCopy) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .foregroundColor(showCopied ? .green : .accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                    
                    Text("This link contains the secure reference and is now active. It will auto-destruct when criteria are met.")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(nsColorOrUiColor: .windowBackgroundColor))
    }
}
