import SwiftUI

public enum SidebarCategory: String, CaseIterable, Identifiable {
    case all = "All Items"
    case bookmarks = "Bookmarks"
    case frequentlyUsed = "Frequently Used"
    case leastUsed = "Least Used"
    case login = "Logins"
    case bankAccount = "Bank Accounts"
    case creditCard = "Cards"
    case identity = "Identities"
    case secureNote = "Secure Notes"
    case membership = "Memberships"
    case audit = "Watchtower"
    case settings = "Settings"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "tray.2"
        case .bookmarks: return "star"
        case .frequentlyUsed: return "bolt.fill"
        case .leastUsed: return "hourglass"
        case .login: return "key.horizontal.fill"
        case .bankAccount: return "building.columns.fill"
        case .creditCard: return "creditcard.fill"
        case .identity: return "person.crop.rectangle.stack.fill"
        case .secureNote: return "lock.doc.fill"
        case .membership: return "person.text.rectangle.fill"
        case .audit: return "binoculars"
        case .settings: return "gearshape"
        }
    }
}

public struct SidebarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedCategory: SidebarCategory
    let itemCounts: [SidebarCategory: Int]
    
    public init(selectedCategory: Binding<SidebarCategory>, itemCounts: [SidebarCategory: Int]) {
        self._selectedCategory = selectedCategory
        self.itemCounts = itemCounts
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Sidebar Header
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("FORTRESS")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            
            // Sidebar Lists
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    // Group 1: General
                    sectionHeader("VAULT")
                    sidebarItem(.all)
                    sidebarItem(.bookmarks)
                    sidebarItem(.frequentlyUsed)
                    sidebarItem(.leastUsed)
                    
                    Divider()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                    
                    // Group 2: Templates
                    sectionHeader("CATEGORIES")
                    sidebarItem(.login)
                    sidebarItem(.bankAccount)
                    sidebarItem(.creditCard)
                    sidebarItem(.identity)
                    sidebarItem(.secureNote)
                    sidebarItem(.membership)
                    
                    Divider()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                    
                    // Group 3: Utility & Config
                    sectionHeader("UTILITIES")
                    sidebarItem(.audit)
                    sidebarItem(.settings)
                }
                .padding(.horizontal, 10)
            }
            
            // Locking block at the bottom
            Spacer()
            
            Button {
                VaultState.shared.lock()
            } label: {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Lock Vault")
                    Spacer()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.red)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 200, maxWidth: 280)
        .background(Color(nsColorOrUiColor: .sidebarBackgroundColor))
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.secondary.opacity(0.7))
            .tracking(1.2)
            .padding(.leading, 16)
            .padding(.bottom, 4)
    }
    
    private func sidebarItem(_ category: SidebarCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.75)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.iconName)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 20, alignment: .center)
                
                Text(category.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .primary : .primary.opacity(0.8))
                
                Spacer()
                
                // Badge counts (only for non-settings/audit keys)
                if let count = itemCounts[category], count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                        )
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#if os(macOS)
extension NSColor {
    static var sidebarBackgroundColor: NSColor {
        return NSColor.windowBackgroundColor // Sidebar standard
    }
}
#else
extension UIColor {
    static var sidebarBackgroundColor: UIColor {
        return UIColor.systemGroupedBackground
    }
}
#endif
