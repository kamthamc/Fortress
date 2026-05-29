import SwiftUI

public struct MagicButton: View {
    @Binding var isMenuPresented: Bool
    
    public init(isMenuPresented: Binding<Bool>) {
        self._isMenuPresented = isMenuPresented
    }
    
    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isMenuPresented.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 8, x: 0, y: 4)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isMenuPresented ? 45 : 0))
            }
            .frame(width: 54, height: 54)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create New Vault Item")
        .accessibilityHint("Opens a menu to select the type of item to create.")
    }
}
