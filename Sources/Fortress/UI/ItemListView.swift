import SwiftUI
import SwiftData

public enum SortField: String, CaseIterable, Identifiable {
    case title = "Title"
    case createdDate = "Date Created"
    case modifiedDate = "Date Modified"
    case frequentlyUsed = "Frequently Used"
    case recentlyUsed = "Recently Used"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .title: return "textformat.abc"
        case .createdDate: return "calendar.badge.plus"
        case .modifiedDate: return "calendar.badge.clock"
        case .frequentlyUsed: return "bolt.fill"
        case .recentlyUsed: return "clock.fill"
        }
    }
}

public struct ItemListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let items: [VaultItem]
    @Binding var selectedItem: VaultItem?
    @Binding var searchQuery: String
    let category: SidebarCategory
    
    @Query(sort: \VaultItem.title) private var allItems: [VaultItem]
    @State private var sortField: SortField = .title
    @State private var sortAscending: Bool = true
    
    public init(items: [VaultItem], selectedItem: Binding<VaultItem?>, searchQuery: Binding<String>, category: SidebarCategory) {
        self.items = items
        self._selectedItem = selectedItem
        self._searchQuery = searchQuery
        self.category = category
    }
    
    // Helper methods for sort direction labels
    private func descendingLabel(for field: SortField) -> String {
        switch field {
        case .title: return "Z-A"
        case .createdDate, .modifiedDate, .recentlyUsed: return "Newest First"
        case .frequentlyUsed: return "Most Used"
        }
    }
    
    private func ascendingLabel(for field: SortField) -> String {
        switch field {
        case .title: return "A-Z"
        case .createdDate, .modifiedDate, .recentlyUsed: return "Oldest First"
        case .frequentlyUsed: return "Least Used"
        }
    }

    // Filters and sorts based on active sortField, sortAscending, and search query
    private var sortedAndFilteredItems: [VaultItem] {
        let filtered: [VaultItem]
        if searchQuery.isEmpty {
            filtered = items
        } else {
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            filtered = items.filter { item in
                // Match Title
                if item.title.localizedCaseInsensitiveContains(query) { return true }
                
                // Match Type Raw Name
                if item.itemTypeString.localizedCaseInsensitiveContains(query) { return true }
                
                // Match Decrypted Fields
                if let payload = VaultState.shared.decryptItem(item) {
                    if let username = payload.username, username.localizedCaseInsensitiveContains(query) { return true }
                    if let website = payload.websiteUrl, website.localizedCaseInsensitiveContains(query) { return true }
                    if let bank = payload.bankName, bank.localizedCaseInsensitiveContains(query) { return true }
                    if let notes = payload.notesContent, notes.localizedCaseInsensitiveContains(query) { return true }
                    if let account = payload.accountNumber, account.localizedCaseInsensitiveContains(query) { return true }
                    if let routing = payload.routingOrIFSC, routing.localizedCaseInsensitiveContains(query) { return true }
                    if let cardholder = payload.cardholderName, cardholder.localizedCaseInsensitiveContains(query) { return true }
                    if let cardNum = payload.cardNumber, cardNum.localizedCaseInsensitiveContains(query) { return true }
                    if let fullName = payload.fullName, fullName.localizedCaseInsensitiveContains(query) { return true }
                    if let passport = payload.passportNumber, passport.localizedCaseInsensitiveContains(query) { return true }
                    if let idNum = payload.idNumber, idNum.localizedCaseInsensitiveContains(query) { return true }
                    if let org = payload.organization, org.localizedCaseInsensitiveContains(query) { return true }
                    if let memId = payload.membershipId, memId.localizedCaseInsensitiveContains(query) { return true }
                    if let policy = payload.policyNumber, policy.localizedCaseInsensitiveContains(query) { return true }
                    if let licClass = payload.licenseClass, licClass.localizedCaseInsensitiveContains(query) { return true }
                    if let addr = payload.address, addr.localizedCaseInsensitiveContains(query) { return true }
                    
                    // Match custom fields
                    for field in payload.customFields {
                        if field.label.localizedCaseInsensitiveContains(query) ||
                           field.value.localizedCaseInsensitiveContains(query) {
                            return true
                        }
                    }
                }
                return false
            }
        }
        
        let sorted: [VaultItem]
        switch sortField {
        case .title:
            sorted = filtered.sorted { 
                let c = $0.title.localizedCompare($1.title)
                return sortAscending ? (c == .orderedAscending) : (c == .orderedDescending)
            }
        case .createdDate:
            sorted = filtered.sorted {
                return sortAscending ? ($0.createdAt < $1.createdAt) : ($0.createdAt > $1.createdAt)
            }
        case .modifiedDate:
            sorted = filtered.sorted {
                return sortAscending ? ($0.updatedAt < $1.updatedAt) : ($0.updatedAt > $1.updatedAt)
            }
        case .frequentlyUsed:
            sorted = filtered.sorted {
                if $0.usageCount == $1.usageCount {
                    return $0.title.localizedCompare($1.title) == .orderedAscending
                }
                return sortAscending ? ($0.usageCount < $1.usageCount) : ($0.usageCount > $1.usageCount)
            }
        case .recentlyUsed:
            sorted = filtered.sorted {
                let d1 = $0.lastAccessedAt ?? Date.distantPast
                let d2 = $1.lastAccessedAt ?? Date.distantPast
                if d1 == d2 {
                    return $0.title.localizedCompare($1.title) == .orderedAscending
                }
                return sortAscending ? (d1 < d2) : (d1 > d2)
            }
        }
        return sorted
    }
    
    private var reusedPasswordIDs: Set<UUID> {
        var decryptedMap = [UUID: VaultItemPayload]()
        for item in allItems {
            if let payload = VaultState.shared.decryptItem(item) {
                decryptedMap[item.id] = payload
            }
        }
        return AuditEngine.findReusedPasswordIDs(items: allItems, decryptedPayloads: decryptedMap)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search Bar (Things style: light, simple borders)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search \(category.rawValue.lowercased())...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1.0)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 10)
            
            // Header Title & Sorting
            HStack {
                Text(category.rawValue)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    // Header text displaying item count sorted
                    Text("\(sortedAndFilteredItems.count) ITEMS SORTED BY")
                        .font(.caption)
                    
                    ForEach(SortField.allCases) { field in
                        Button {
                            sortField = field
                            // Sensible order defaults: titles start A-Z, dates start newest, usage starts most used
                            if field == .title {
                                sortAscending = true
                            } else {
                                sortAscending = false
                            }
                        } label: {
                            HStack {
                                if sortField == field {
                                    Image(systemName: "checkmark")
                                }
                                Image(systemName: field.iconName)
                                Text(field.rawValue)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        sortAscending = false
                    } label: {
                        HStack {
                            if !sortAscending {
                                Image(systemName: "checkmark")
                            }
                            Text(descendingLabel(for: sortField))
                        }
                    }
                    
                    Button {
                        sortAscending = true
                    } label: {
                        HStack {
                            if sortAscending {
                                Image(systemName: "checkmark")
                            }
                            Text(ascendingLabel(for: sortField))
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.and.down.text.horizontal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                }
                .menuStyle(.button)
                .frame(width: 32)
                .help("Sort Items")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // List Items
            if sortedAndFilteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchQuery.isEmpty ? "No Items Yet" : "No Matching Items")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sortedAndFilteredItems) { item in
                            ItemRowView(
                                item: item,
                                isSelected: selectedItem?.id == item.id,
                                isReused: reusedPasswordIDs.contains(item.id)
                            ) {
                                withAnimation(reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.75)) {
                                    selectedItem = item
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80) // Leave space for Magic Button on mobile
                }
            }
        }
        .background(Color(nsColorOrUiColor: .listBackgroundColor))
        .onChange(of: category, initial: true) { oldValue, newValue in
            switch newValue {
            case .frequentlyUsed:
                sortField = .frequentlyUsed
                sortAscending = false // Most used first
            case .leastUsed:
                sortField = .frequentlyUsed
                sortAscending = true // Least used first
            default:
                sortField = .title
                sortAscending = true
            }
        }
    }
}

// MARK: - Row View Component

struct ItemRowView: View {
    let item: VaultItem
    let isSelected: Bool
    let isReused: Bool
    let action: () -> Void
    
    var subtitle: String {
        if let payload = VaultState.shared.decryptItem(item) {
            switch item.itemType {
            case .login:
                return payload.username ?? "No Username"
            case .bankAccount:
                return payload.bankName ?? "Bank Account"
            case .creditCard:
                if let num = payload.cardNumber, num.count >= 4 {
                    return "Card ending in \(num.suffix(4))"
                }
                return "Credit Card"
            case .identity:
                return payload.fullName ?? "Identity"
            case .secureNote:
                return payload.notesContent?.prefix(40).replacingOccurrences(of: "\n", with: " ") ?? "Empty Note"
            case .membership:
                return payload.organization ?? "Membership"
            }
        }
        return "Locked"
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Item Icon inside circular badge
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.15) : Color.accentColor.opacity(0.08))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: item.itemType.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? .white : .accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Indicators: Reused / Bookmark / Shared / Expired
                HStack(spacing: 6) {
                    if isReused {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .red)
                            .help("Reused Password")
                    }
                    if item.isShared {
                        Image(systemName: "shareplay")
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .blue)
                    }
                    if item.isBookmarked {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .orange)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSelected ? .white.opacity(0.5) : .secondary.opacity(0.5))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(nsColorOrUiColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.02), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#if os(macOS)
extension NSColor {
    static var listBackgroundColor: NSColor {
        return NSColor.controlBackgroundColor
    }
}
#else
extension UIColor {
    static var listBackgroundColor: UIColor {
        return UIColor.systemBackground
    }
}
#endif
