import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct ClipboardUtility {
    public static func copy(_ text: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

public struct SecureTextField: View {
    let label: String
    let value: String
    @State private var isRevealed = false
    @State private var showCopiedBadge = false
    
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.0)
            
            HStack(spacing: 12) {
                if isRevealed || value.isEmpty {
                    Text(value.isEmpty ? "Empty" : value)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(value.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(String(repeating: "•", count: min(12, max(6, value.count))))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    // Copy button
                    if !value.isEmpty {
                        Button {
                            ClipboardUtility.copy(value)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                showCopiedBadge = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showCopiedBadge = false
                                }
                            }
                        } label: {
                            Image(systemName: showCopiedBadge ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(showCopiedBadge ? .green : .accentColor)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(showCopiedBadge ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Copy to Clipboard")
                        .accessibilityLabel("Copy \(label)")
                        
                        // Reveal button
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isRevealed.toggle()
                            }
                        } label: {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.secondary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .help(isRevealed ? "Hide Value" : "Reveal Value")
                        .accessibilityLabel(isRevealed ? "Hide \(label)" : "Reveal \(label)")
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
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

// Helper to bridge light-mode/dark-mode compatible system background colors
extension Color {
    init(nsColorOrUiColor: NSColorOrUIColorType) {
        #if os(macOS)
        self.init(nsColor: nsColorOrUiColor)
        #else
        self.init(uiColor: nsColorOrUiColor)
        #endif
    }
}

#if os(macOS)
typealias NSColorOrUIColorType = NSColor
#else
typealias NSColorOrUIColorType = UIColor
extension UIColor {
    static var windowBackgroundColor: UIColor {
        return UIColor.secondarySystemGroupedBackground
    }
}
#endif
