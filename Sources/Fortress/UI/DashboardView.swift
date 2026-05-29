import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \VaultItem.title) private var allItems: [VaultItem]
    
    @State private var selectedCategory: SidebarCategory = .all
    @State private var selectedItem: VaultItem? = nil
    @State private var searchQuery = ""
    @State private var showEditSheet = false
    @State private var showCreateTypePicker = false
    @State private var createDefaultType: VaultItemType = .login
    
    // Settings parameters
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var showChangePasswordSheet = false
    @State private var backupPassword = ""
    @State private var showBackupSheet = false
    @State private var showRestoreSheet = false
    @State private var showEnableBiometricsSheet = false
    @State private var biometricsPassword = ""
    @State private var restoreDataString = ""
    @State private var showResetConfirm = false
    @State private var settingsSuccessMsg = ""
    @State private var settingsErrorMsg = ""
    @State private var showImportPicker = false
    @State private var isProcessingSettings = false
    
    // Sheet local error messages (displayed inside the modal sheets)
    @State private var changePasswordError = ""
    @State private var backupError = ""
    @State private var restoreError = ""
    @State private var biometricsError = ""
    
    // Audit results
    @State private var auditPwnedItems: [UUID: Int] = [:] // item ID -> leak count
    @State private var auditProgress = 0.0
    @State private var isAuditing = false
    @State private var selectedWatchtowerSection: WatchtowerSection? = nil
    
    @Bindable private var vaultState = VaultState.shared
    
    public init() {}
    
    // Calculates sidebar badges counts
    private var itemCounts: [SidebarCategory: Int] {
        var counts = [SidebarCategory: Int]()
        counts[.all] = allItems.count
        counts[.bookmarks] = allItems.filter { $0.isBookmarked }.count
        counts[.frequentlyUsed] = allItems.filter { $0.usageCount > 0 }.count
        counts[.leastUsed] = allItems.count
        counts[.login] = allItems.filter { $0.itemType == .login }.count
        counts[.bankAccount] = allItems.filter { $0.itemType == .bankAccount }.count
        counts[.creditCard] = allItems.filter { $0.itemType == .creditCard }.count
        counts[.identity] = allItems.filter { $0.itemType == .identity }.count
        counts[.secureNote] = allItems.filter { $0.itemType == .secureNote }.count
        counts[.membership] = allItems.filter { $0.itemType == .membership }.count
        return counts
    }
    
    // Items filtered by category selection (excluding bookmarks which are handled separately)
    private var categoryFilteredItems: [VaultItem] {
        switch selectedCategory {
        case .all:
            return allItems
        case .bookmarks:
            return allItems.filter { $0.isBookmarked }
        case .frequentlyUsed:
            return allItems.filter { $0.usageCount > 0 }
        case .leastUsed:
            return allItems
        case .login:
            return allItems.filter { $0.itemType == .login }
        case .bankAccount:
            return allItems.filter { $0.itemType == .bankAccount }
        case .creditCard:
            return allItems.filter { $0.itemType == .creditCard }
        case .identity:
            return allItems.filter { $0.itemType == .identity }
        case .secureNote:
            return allItems.filter { $0.itemType == .secureNote }
        case .membership:
            return allItems.filter { $0.itemType == .membership }
        case .audit, .settings:
            return []
        }
    }
    
    private var defaultBackupURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if paths.isEmpty {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FortressBackup.db")
        }
        return paths[0].appendingPathComponent("FortressBackup.db")
    }
    
    public var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory, itemCounts: itemCounts)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } content: {
            switch selectedCategory {
            case .audit:
                renderAuditView()
            case .settings:
                renderSettingsView()
            default:
                ItemListView(
                    items: categoryFilteredItems,
                    selectedItem: $selectedItem,
                    searchQuery: $searchQuery,
                    category: selectedCategory
                )
                .navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 350)
                .overlay(
                    // Magic Button styled dynamically in the bottom corner of list
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            MagicButton(isMenuPresented: $showCreateTypePicker)
                                .padding(16)
                        }
                    }
                )
            }
        } detail: {
            if selectedCategory == .settings || selectedCategory == .audit {
                // Settings & Audit have their detail/primary layouts inline
                VStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor.opacity(0.3))
                    Text("Select an operation from the sidebar")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColorOrUiColor: .listBackgroundColor).opacity(0.3))
            } else if let item = selectedItem {
                ItemDetailView(item: item) {
                    showEditSheet = true
                } onDelete: {
                    deleteItem(item)
                }
                .id(item.id) // Force refresh detail view on item selection
            } else {
                VStack {
                    Image(systemName: "lock.rectangle.stack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Select an item to view details")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColorOrUiColor: .listBackgroundColor).opacity(0.3))
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ItemEditView(itemToEdit: selectedItem, defaultType: selectedItem == nil ? createDefaultType : (selectedItem?.itemType ?? .login))
        }
        .sheet(isPresented: $showCreateTypePicker) {
            // Dropdown style sheet to select new item type (Things card style)
            VStack(spacing: 20) {
                HStack {
                    Text("Create New Item")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Button {
                        showCreateTypePicker = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(VaultItemType.allCases) { type in
                        Button {
                            createDefaultType = type
                            showCreateTypePicker = false
                            // Add minor delay to let previous sheet dismiss cleanly
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                selectedItem = nil // Unselect so edit sheet creates a new item
                                showEditSheet = true
                            }
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: type.iconName)
                                    .font(.system(size: 22))
                                    .foregroundColor(.accentColor)
                                Text(type.rawValue)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .frame(width: 320)
            .background(Color(nsColorOrUiColor: .windowBackgroundColor))
        }
        .onChange(of: selectedCategory) { oldValue, newValue in
            settingsSuccessMsg = ""
            settingsErrorMsg = ""
            biometricsPassword = ""
            oldPassword = ""
            newPassword = ""
            backupPassword = ""
            selectedWatchtowerSection = nil
        }
    }
    
    private func deleteItem(_ item: VaultItem) {
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
            selectedItem = nil
        }
    }
    
    // MARK: - Audit View Dashboard
    
    @ViewBuilder
    private func renderAuditView() -> some View {
        let (reusedItems, weakItems, expiredItems, reusedMap) = performLocalAudits()
        let missing2faItems = allItems.filter { item in
            if item.itemType == .login {
                if let payload = vaultState.decryptItem(item) {
                    return payload.totpSecret == nil || payload.totpSecret!.isEmpty
                }
            }
            return false
        }
        let pwnedItems = allItems.filter { auditPwnedItems[$0.id] != nil }
        
        let totalAudited = allItems.filter { $0.itemType == .login }.count
        
        let scorePercent: Int = {
            guard totalAudited > 0 else { return 100 }
            let deduction = Double(weakItems.count) * 25.0 + Double(reusedItems.count) * 20.0 + Double(pwnedItems.count) * 35.0 + Double(expiredItems.count) * 10.0
            let baseScore = 100.0 - (deduction / max(1.0, Double(totalAudited)))
            return max(0, min(100, Int(baseScore)))
        }()
        
        let scoreValue: Int = {
            let base = 600
            let scale = 464 // Maxes out at 1064
            return base + Int(Double(scorePercent) / 100.0 * Double(scale))
        }()
        
        let scoreLabel: String = {
            if scorePercent > 85 { return "FANTASTIC" }
            else if scorePercent > 65 { return "GOOD" }
            else if scorePercent > 45 { return "FAIR" }
            else { return "WEAK" }
        }()
        
        let scoreColor: Color = {
            if scorePercent > 85 { return .green }
            else if scorePercent > 65 { return .orange }
            else { return .red }
        }()
        
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let section = selectedWatchtowerSection {
                    // MARK: - WATCHTOWER DETAIL VIEW
                    HStack {
                        Button {
                            selectedWatchtowerSection = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back to Watchtower")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sectionTitle(for: section))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(sectionSubtitle(for: section))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                    
                    let items = itemsForSection(section, reused: reusedItems, weak: weakItems, expired: expiredItems, pwned: pwnedItems, missing2fa: missing2faItems)
                    
                    if items.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            Text("All Clear!")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text("No issues found in this category.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(items) { item in
                                Button {
                                    // Select in sidebar and focus item
                                    selectedCategory = item.itemType.toSidebarCategory()
                                    selectedItem = item
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: item.itemType.iconName)
                                                .foregroundColor(.accentColor)
                                                .font(.system(size: 14))
                                            Text(item.title)
                                                .font(.system(size: 13, weight: .semibold))
                                            Spacer()
                                            
                                            if section == .pwned, let leakCount = auditPwnedItems[item.id] {
                                                Text("\(leakCount) leaks")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color.red))
                                            }
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if section == .reused, let siblings = reusedMap[item.id], !siblings.isEmpty {
                                            Text("Reused on: \(siblings.joined(separator: ", "))")
                                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundColor(.red.opacity(0.8))
                                                .padding(.leading, 18)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(Color.secondary.opacity(0.08), lineWidth: 0.5)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    // MARK: - MAIN WATCHTOWER DASHBOARD
                    Text("Watchtower")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // Gauge & Summary Block
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Spacer()
                            WatchtowerGaugeView(
                                score: scoreValue,
                                percentage: Double(scorePercent) / 100.0,
                                label: scoreLabel,
                                color: scoreColor
                            )
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overall Security Score")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("Get alerts for any security issues that affect you. Your score gives an overall idea of how safe your credentials are. Review cards below to improve.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // HIBP check action
                            Button {
                                Task {
                                    await checkAllPasswordsForPwned()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: isAuditing ? "arrow.triangle.2.circlepath" : "globe")
                                        .rotationEffect(.degrees(isAuditing ? 360 : 0))
                                    Text(isAuditing ? "Auditing Vault... \(Int(auditProgress * 100))%" : "Scan compromised passwords (HIBP)")
                                        .lineLimit(1)
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                            }
                            .buttonStyle(.plain)
                            .disabled(isAuditing)
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.015), radius: 8, x: 0, y: 4)
                    )
                    
                    // Grid of 5 Cards (matching 1Password)
                    let columns = [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)]
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        WatchtowerCard(
                            count: weakItems.count,
                            title: "Weak passwords",
                            description: "Weak passwords are easy to guess. Replace them with strong, generated recipes.",
                            iconName: "exclamationmark.triangle.fill",
                            iconColor: .red,
                            actionLabel: "Show Items"
                        ) {
                            selectedWatchtowerSection = .weak
                        }
                        
                        WatchtowerCard(
                            count: reusedItems.count,
                            title: "Reused passwords",
                            description: "Using identical passwords across websites makes you highly vulnerable to credential stuffing.",
                            iconName: "arrow.rectanglepath",
                            iconColor: .orange,
                            actionLabel: "Show Items"
                        ) {
                            selectedWatchtowerSection = .reused
                        }
                        
                        WatchtowerCard(
                            count: pwnedItems.count,
                            title: "Leaked passwords",
                            description: "Compromised credentials found in public data breaches. Rotate these instantly.",
                            iconName: "personalhotspot",
                            iconColor: .red,
                            actionLabel: "Show Items"
                        ) {
                            selectedWatchtowerSection = .pwned
                        }
                        
                        WatchtowerCard(
                            count: expiredItems.count,
                            title: "Old passwords",
                            description: "Passwords or PINs that haven't been updated in more than 6 months.",
                            iconName: "clock.arrow.circlepath",
                            iconColor: .blue,
                            actionLabel: "Show Items"
                        ) {
                            selectedWatchtowerSection = .expired
                        }
                        
                        WatchtowerCard(
                            count: missing2faItems.count,
                            title: "Missing 2FA",
                            description: "Login credentials that benefit from two-factor codes, but don't have a secret TOTP token.",
                            iconName: "lock.shield",
                            iconColor: .purple,
                            actionLabel: "Show Items"
                        ) {
                            selectedWatchtowerSection = .missing2fa
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(24)
        }
    }
    
    private func sectionTitle(for section: WatchtowerSection) -> String {
        switch section {
        case .weak: return "Weak Passwords"
        case .reused: return "Reused Passwords"
        case .pwned: return "Leaked Passwords (Pwned)"
        case .expired: return "Old Passwords (Rotation Needed)"
        case .missing2fa: return "Logins Without 2FA"
        }
    }
    
    private func sectionSubtitle(for section: WatchtowerSection) -> String {
        switch section {
        case .weak: return "Weak passwords can be cracked easily. Replace them with strong generated values."
        case .reused: return "Reusing passwords across multiple services increases vulnerability. Assign unique ones."
        case .pwned: return "These credentials appeared in public breach databases. Rotate them immediately."
        case .expired: return "These passwords or banking PINs are older than 6 months and should be refreshed."
        case .missing2fa: return "Secure your logins by importing a 2FA TOTP secret key for these accounts."
        }
    }
    
    private func itemsForSection(
        _ section: WatchtowerSection,
        reused: [VaultItem],
        weak: [VaultItem],
        expired: [VaultItem],
        pwned: [VaultItem],
        missing2fa: [VaultItem]
    ) -> [VaultItem] {
        switch section {
        case .weak: return weak
        case .reused: return reused
        case .pwned: return pwned
        case .expired: return expired
        case .missing2fa: return missing2fa
        }
    }
    
    private func performLocalAudits() -> (reused: [VaultItem], weak: [VaultItem], expired: [VaultItem], reusedMap: [UUID: [String]]) {
        var reused = [VaultItem]()
        var weak = [VaultItem]()
        var expired = [VaultItem]()
        
        // Decrypt all items into local memory
        var decryptedMap = [UUID: VaultItemPayload]()
        for item in allItems {
            if let payload = vaultState.decryptItem(item) {
                decryptedMap[item.id] = payload
            }
        }
        
        // Find reused password ids
        let reusedIDs = AuditEngine.findReusedPasswordIDs(items: allItems, decryptedPayloads: decryptedMap)
        let reusedMap = AuditEngine.getReusedPasswordMap(items: allItems, decryptedPayloads: decryptedMap)
        
        for item in allItems {
            guard let payload = decryptedMap[item.id] else { continue }
            
            // Check reuse
            if reusedIDs.contains(item.id) {
                reused.append(item)
            }
            
            // Check strength
            if let password = payload.passwordValue, !password.isEmpty {
                let (strength, _) = AuditEngine.evaluateStrength(password)
                if strength == .weak {
                    weak.append(item)
                }
            }
            
            // Check rotation reminder
            if AuditEngine.isExpired(lastChanged: payload.passwordLastChanged) {
                expired.append(item)
            }
        }
        
        return (reused, weak, expired, reusedMap)
    }
    
    private func checkAllPasswordsForPwned() async {
        isAuditing = true
        auditProgress = 0.0
        auditPwnedItems.removeAll()
        
        let itemsToCheck = allItems.filter { item in
            if let payload = vaultState.decryptItem(item) {
                return !(payload.passwordValue ?? "").isEmpty
            }
            return false
        }
        
        guard !itemsToCheck.isEmpty else {
            isAuditing = false
            return
        }
        
        for (index, item) in itemsToCheck.enumerated() {
            guard let payload = vaultState.decryptItem(item), let password = payload.passwordValue else { continue }
            
            do {
                let count = try await AuditEngine.checkPwned(password: password)
                if count > 0 {
                    auditPwnedItems[item.id] = count
                }
            } catch {
                print("Failed to audit password for pwned database: \(error.localizedDescription)")
            }
            
            // Artificial delay to prevent API rate limits
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            
            withAnimation {
                auditProgress = Double(index + 1) / Double(itemsToCheck.count)
            }
        }
        
        isAuditing = false
    }
    
    // MARK: - Settings View Sub-panel
    
    @ViewBuilder
    private func renderSettingsView() -> some View {
        // Read properties to register SwiftUI observation dependencies in render settings scope
        let _ = vaultState.biometricUnlockEnabled
        let _ = vaultState.autoWipeAttemptsLimit
        let _ = vaultState.biometricUnlockAvailable
        
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Fortress Settings")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if !settingsSuccessMsg.isEmpty {
                    Text(settingsSuccessMsg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.08)))
                }
                
                if !settingsErrorMsg.isEmpty {
                    Text(settingsErrorMsg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
                }
                
                // Section: Biometrics
                VStack(alignment: .leading, spacing: 12) {
                    Text("BIOMETRIC SECURITY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.0)
                    
                    Toggle(isOn: Binding(
                        get: { vaultState.biometricUnlockEnabled },
                        set: { newValue in
                            if newValue {
                                settingsErrorMsg = ""
                                settingsSuccessMsg = ""
                                biometricsPassword = ""
                                showEnableBiometricsSheet = true
                            } else {
                                vaultState.disableBiometric()
                                settingsSuccessMsg = "Biometric unlock disabled."
                                settingsErrorMsg = ""
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unlock with Face ID / Touch ID")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Bypass Master Password typing on app launch.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(!vaultState.biometricUnlockAvailable)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColorOrUiColor: .windowBackgroundColor)))
                }
                
                // Section: Auto-Wipe
                VStack(alignment: .leading, spacing: 12) {
                    Text("AUTO-WIPE SECURITY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.0)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Auto-Wipe Threshold", selection: $vaultState.autoWipeAttemptsLimit) {
                            Text("Disabled").tag(0)
                            Text("3 failed attempts").tag(3)
                            Text("5 failed attempts").tag(5)
                            Text("10 failed attempts").tag(10)
                        }
                        .pickerStyle(.menu)
                        
                        Text("Factory reset (wipe all data and keys) after the selected number of consecutive failed unlock attempts.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColorOrUiColor: .windowBackgroundColor)))
                }
                
                // Section: Password Changes
                VStack(alignment: .leading, spacing: 12) {
                    Text("MASTER ACCESS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.0)
                    
                    Button {
                        showChangePasswordSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Change Master Password")
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColorOrUiColor: .windowBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                }
                
                // Section: Backup, Restore & Import
                VStack(alignment: .leading, spacing: 12) {
                    Text("BACKUP, RESTORE & IMPORT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.0)
                    
                    HStack(spacing: 12) {
                        Button {
                            showBackupSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("Export Backup")
                                Spacer()
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColorOrUiColor: .windowBackgroundColor)))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showRestoreSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("Import Backup")
                                Spacer()
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColorOrUiColor: .windowBackgroundColor)))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        showImportPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import from 1Password, Bitwarden, Chrome (CSV)...")
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColorOrUiColor: .windowBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                    
                    Text("Supports standard password manager exports. Maps headers like Title/Name, Username/Email, Password, Website/URL, Notes, and TOTP automatically.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                // Section: Factory Reset
                VStack(alignment: .leading, spacing: 12) {
                    Text("DANGER ZONE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.0)
                    
                    Button {
                        showResetConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                            Text("Wipe and Reset Fortress")
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
                
                // Password confirm prompt is now presented via modal sheet instead of inline input
            }
            .padding(24)
        }
        .onAppear {
            settingsSuccessMsg = ""
            settingsErrorMsg = ""
            biometricsPassword = ""
            oldPassword = ""
            newPassword = ""
            backupPassword = ""
        }
        .onDisappear {
            settingsSuccessMsg = ""
            settingsErrorMsg = ""
            biometricsPassword = ""
            oldPassword = ""
            newPassword = ""
            backupPassword = ""
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            VStack(spacing: 20) {
                Text("Change Master Password")
                    .font(.headline)
                
                SecureField("Current Master Password", text: $oldPassword)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("New Master Password (min 8 chars)", text: $newPassword)
                    .textFieldStyle(.roundedBorder)
                
                if !changePasswordError.isEmpty {
                    Text(changePasswordError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                HStack {
                    Button("Cancel") {
                        showChangePasswordSheet = false
                        oldPassword = ""
                        newPassword = ""
                        changePasswordError = ""
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button {
                        let old = oldPassword
                        let new = newPassword
                        
                        let (strength, _) = AuditEngine.evaluateStrength(new)
                        guard strength == .strong else {
                            changePasswordError = "New Master Password must meet 'Strong' criteria."
                            return
                        }
                        
                        oldPassword = ""
                        newPassword = ""
                        isProcessingSettings = true
                        changePasswordError = ""
                        
                        Task {
                            let success = await vaultState.changeMasterPassword(oldPassword: old, newPassword: new)
                            isProcessingSettings = false
                            if success {
                                settingsSuccessMsg = "Master Password updated successfully."
                                settingsErrorMsg = ""
                                showChangePasswordSheet = false
                            } else {
                                changePasswordError = vaultState.lastError ?? "Failed to change password."
                            }
                        }
                    } label: {
                        HStack {
                            if isProcessingSettings {
                                ProgressView().controlSize(.small)
                            }
                            Text("Confirm Change")
                        }
                    }
                    .disabled(newPassword.count < 8 || isProcessingSettings)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(Color(nsColorOrUiColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $showBackupSheet) {
            VStack(spacing: 20) {
                Text("Export Vault Backup")
                    .font(.headline)
                Text("Your backup will be fully encrypted with this password. Keep this password safe; without it, the backup cannot be imported.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                SecureField("Backup Password", text: $backupPassword)
                    .textFieldStyle(.roundedBorder)
                
                if !backupError.isEmpty {
                    Text(backupError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                HStack {
                    Button("Cancel") {
                        showBackupSheet = false
                        backupPassword = ""
                        backupError = ""
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button {
                        let passwordInput = backupPassword
                        backupPassword = ""
                        isProcessingSettings = true
                        backupError = ""
                        // Map items to sendable ExportedItems on the MainActor
                        let exportedItems = allItems.map { VaultBackup.ExportedItem(from: $0) }
                        
                        let backupURL = defaultBackupURL
                        Task {
                            do {
                                let data = try await Task.detached(priority: .userInitiated) {
                                    try BackupManager.exportBackup(exportedItems: exportedItems, password: passwordInput)
                                }.value
                                try data.write(to: backupURL)
                                
                                settingsSuccessMsg = "Backup saved successfully to: \(backupURL.path)"
                                settingsErrorMsg = ""
                                showBackupSheet = false
                            } catch {
                                backupError = "Export failed: \(error.localizedDescription)"
                            }
                            isProcessingSettings = false
                        }
                    } label: {
                        HStack {
                            if isProcessingSettings {
                                ProgressView().controlSize(.small)
                            }
                            Text("Export and Save")
                        }
                    }
                    .disabled(backupPassword.isEmpty || isProcessingSettings)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(Color(nsColorOrUiColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $showRestoreSheet) {
            VStack(spacing: 20) {
                Text("Import Vault Backup")
                    .font(.headline)
                Text("Enter the password that was used to encrypt the backup file at \(defaultBackupURL.lastPathComponent). All items will be merged into your current vault.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                SecureField("Backup Password", text: $backupPassword)
                    .textFieldStyle(.roundedBorder)
                
                if !restoreError.isEmpty {
                    Text(restoreError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                HStack {
                    Button("Cancel") {
                        showRestoreSheet = false
                        backupPassword = ""
                        restoreError = ""
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button {
                        let passwordInput = backupPassword
                        backupPassword = ""
                        isProcessingSettings = true
                        restoreError = ""
                        let backupURL = defaultBackupURL
                        Task {
                            do {
                                let data = try Data(contentsOf: backupURL)
                                let importedExportedItems = try await Task.detached(priority: .userInitiated) {
                                    try BackupManager.importBackup(packageData: data, password: passwordInput)
                                }.value
                                
                                // Insert items on the MainActor
                                for exportedItem in importedExportedItems {
                                    modelContext.insert(exportedItem.toVaultItem())
                                }
                                try modelContext.save()
                                
                                settingsSuccessMsg = "Restored \(importedExportedItems.count) items into the vault."
                                settingsErrorMsg = ""
                                showRestoreSheet = false
                            } catch {
                                restoreError = "Restore failed: \(error.localizedDescription)"
                            }
                            isProcessingSettings = false
                        }
                    } label: {
                        HStack {
                            if isProcessingSettings {
                                ProgressView().controlSize(.small)
                            }
                            Text("Restore Items")
                        }
                    }
                    .disabled(backupPassword.isEmpty || isProcessingSettings)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(Color(nsColorOrUiColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $showResetConfirm) {
            VStack(spacing: 20) {
                Text("Are you absolutely sure?")
                    .font(.headline)
                    .foregroundColor(.red)
                Text("This will permanently delete all passwords, cards, and secure keys stored in the database and Keychain. This action is irreversible.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack {
                    Button("Cancel") {
                        showResetConfirm = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Yes, Wipe Everything") {
                        // Delete all records
                        try? modelContext.delete(model: VaultItem.self)
                        try? modelContext.save()
                        vaultState.resetVault()
                        showResetConfirm = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(24)
            .frame(width: 300)
            .background(Color(nsColorOrUiColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $showEnableBiometricsSheet) {
            VStack(spacing: 20) {
                Text("Confirm Master Password")
                    .font(.system(.headline, design: .rounded))
                Text("Please confirm your Master Password to securely register Touch ID / Face ID.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                SecureField("Master Password", text: $biometricsPassword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        attemptEnableBiometrics()
                    }
                
                if !biometricsError.isEmpty {
                    Text(biometricsError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                HStack {
                    Button("Cancel") {
                        showEnableBiometricsSheet = false
                        biometricsPassword = ""
                        biometricsError = ""
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button {
                        attemptEnableBiometrics()
                    } label: {
                        HStack {
                            if isProcessingSettings {
                                ProgressView().controlSize(.small)
                            }
                            Text("Enable Biometrics")
                        }
                    }
                    .disabled(biometricsPassword.isEmpty || isProcessingSettings)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(Color(nsColorOrUiColor: .windowBackgroundColor))
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    let data = try Data(contentsOf: url)
                    if let text = String(data: data, encoding: .utf8) {
                        let parsedRows = CSVImporter.parseCSV(text: text)
                        var importCount = 0
                        for row in parsedRows {
                            if let item = CSVImporter.createVaultItemFromRow(row) {
                                modelContext.insert(item)
                                importCount += 1
                            }
                        }
                        try modelContext.save()
                        settingsSuccessMsg = "Successfully imported \(importCount) items from 1Password."
                        settingsErrorMsg = ""
                    } else {
                        settingsErrorMsg = "Failed to read CSV text content."
                    }
                } catch {
                    settingsErrorMsg = "Import failed: \(error.localizedDescription)"
                }
            case .failure(let error):
                settingsErrorMsg = "File selection failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func attemptEnableBiometrics() {
        let passwordInput = biometricsPassword
        biometricsPassword = ""
        isProcessingSettings = true
        biometricsError = ""
        
        Task {
            let success = await vaultState.enableBiometric(password: passwordInput)
            isProcessingSettings = false
            if success {
                settingsSuccessMsg = "Biometric unlock enabled successfully."
                settingsErrorMsg = ""
                showEnableBiometricsSheet = false
            } else {
                biometricsError = "Invalid Master Password."
            }
        }
    }
}

// Helper to convert Sidebar categories to template types
extension SidebarCategory {
    func toVaultItemType() -> VaultItemType {
        switch self {
        case .all, .bookmarks, .frequentlyUsed, .leastUsed, .login: return .login
        case .bankAccount: return .bankAccount
        case .creditCard: return .creditCard
        case .identity: return .identity
        case .secureNote: return .secureNote
        case .membership: return .membership
        case .audit, .settings: return .login
        }
    }
}

extension VaultItemType {
    func toSidebarCategory() -> SidebarCategory {
        switch self {
        case .login: return .login
        case .bankAccount: return .bankAccount
        case .creditCard: return .creditCard
        case .identity: return .identity
        case .secureNote: return .secureNote
        case .membership: return .membership
        }
    }
}

// MARK: - Watchtower & Import Models & Components

enum WatchtowerSection {
    case weak
    case reused
    case pwned
    case expired
    case missing2fa
}

struct WatchtowerGaugeView: View {
    let score: Int
    let percentage: Double
    let label: String
    let color: Color
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedPercentage: Double = 0.0
    @State private var displayScore: Int = 0
    @State private var displayLabel: String = "CALCULATING..."
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background Track Arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(Color.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(90))
                
                // Foreground Progress Arc
                Circle()
                    .trim(from: 0.15, to: 0.15 + CGFloat(animatedPercentage) * 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.7), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(90))
                
                VStack(spacing: 2) {
                    Text("\(displayScore)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(displayLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(displayLabel == "CALCULATING..." ? .secondary : color)
                        .tracking(1.5)
                }
                .offset(y: 4)
            }
            .frame(width: 150, height: 140)
        }
        .onAppear {
            animateGauge()
        }
        .onChange(of: score) { oldValue, newValue in
            animateGauge()
        }
    }
    
    private func animateGauge() {
        if reduceMotion {
            animatedPercentage = percentage
            displayScore = score
            displayLabel = label
        } else {
            animatedPercentage = 0.0
            displayScore = 0
            displayLabel = "CALCULATING..."
            
            withAnimation(.easeOut(duration: 1.0)) {
                animatedPercentage = percentage
            }
            
            // Count up score in a task
            Task {
                let duration: Double = 1.0
                let steps = 40
                let interval = duration / Double(steps)
                
                for step in 1...steps {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    let currentPercent = Double(step) / Double(steps)
                    displayScore = Int(Double(score) * currentPercent)
                }
                displayScore = score
                displayLabel = label
            }
        }
    }
}

struct WatchtowerCard: View {
    let count: Int
    let title: String
    let description: String
    let iconName: String
    let iconColor: Color
    let actionLabel: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(count)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(count > 0 ? .primary : .secondary)
                
                Spacer()
                
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(count > 0 ? iconColor : .secondary.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(count > 0 ? iconColor.opacity(0.08) : Color.secondary.opacity(0.04)))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            Button(action: action) {
                HStack {
                    Text(actionLabel)
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                }
                .foregroundColor(count > 0 ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
        }
        .padding(16)
        .frame(minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.015), radius: 8, x: 0, y: 4)
        )
    }
}

struct CSVImporter {
    static func parseCSV(text: String) -> [[String: String]] {
        var results = [[String: String]]()
        let lines = text.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return [] }
        
        let firstLine = lines[0]
        let headers = parseCSVLine(firstLine)
        guard !headers.isEmpty else { return [] }
        
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if line.isEmpty { continue }
            let fields = parseCSVLine(line)
            var rowDict = [String: String]()
            for (index, header) in headers.enumerated() {
                let cleanHeader = header.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
                if index < fields.count {
                    rowDict[cleanHeader] = fields[index].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }
            }
            if !rowDict.isEmpty {
                results.append(rowDict)
            }
        }
        return results
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields = [String]()
        var currentField = ""
        var inQuotes = false
        let characters = Array(line)
        var i = 0
        
        while i < characters.count {
            let char = characters[i]
            if char == "\"" {
                if inQuotes && i + 1 < characters.count && characters[i + 1] == "\"" {
                    currentField.append("\"")
                    i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
            i += 1
        }
        fields.append(currentField)
        return fields
    }
    
    static func createVaultItemFromRow(_ row: [String: String]) -> VaultItem? {
        let title = row["title"] ?? row["name"] ?? row["login_uri"] ?? "Imported Item"
        var type: VaultItemType = .login
        
        let username = row["username"] ?? row["email"] ?? row["login_username"] ?? ""
        let password = row["password"] ?? row["login_password"] ?? ""
        let url = row["url"] ?? row["website"] ?? row["website url"] ?? row["login_uri"] ?? ""
        let totp = row["one-time password"] ?? row["otp"] ?? row["totp"] ?? row["otpauth"] ?? row["login_totp"] ?? ""
        let notes = row["notes"] ?? row["note"] ?? row["description"] ?? ""
        
        if password.isEmpty && username.isEmpty && url.isEmpty && !notes.isEmpty {
            type = .secureNote
        }
        
        let payload = VaultItemPayload(
            customFields: [],
            passwordHistory: [],
            username: username.isEmpty ? nil : username,
            passwordValue: password.isEmpty ? nil : password,
            websiteUrl: url.isEmpty ? nil : url,
            totpSecret: totp.isEmpty ? nil : totp,
            passwordLastChanged: Date(),
            notesContent: notes.isEmpty ? nil : notes
        )
        
        do {
            let encrypted = try VaultState.shared.encryptItemPayload(payload)
            return VaultItem(
                title: title,
                itemTypeString: type.rawValue,
                encryptedData: encrypted
            )
        } catch {
            return nil
        }
    }
}
