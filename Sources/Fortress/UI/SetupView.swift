import SwiftUI

public struct SetupView: View {
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var strengthText = ""
    @State private var strengthScore = 0.0
    @State private var strengthColor = Color.red
    @State private var isProcessing = false
    
    private let vaultState = VaultState.shared
    
    public init() {}
    
    private func checkStrength() {
        let (strength, score) = AuditEngine.evaluateStrength(password)
        strengthScore = score
        
        switch strength {
        case .weak:
            strengthText = "Weak Password"
            strengthColor = .red
        case .moderate:
            strengthText = "Moderate Password"
            strengthColor = .orange
        case .strong:
            strengthText = "Strong Password"
            strengthColor = .green
        }
    }
    
    public var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 8)
                
                Text("Welcome to Fortress")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Set up a strong Master Password to encrypt your credentials. This password encrypts your vault locally and cannot be recovered if lost.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            
            VStack(spacing: 20) {
                // Password fields
                VStack(alignment: .leading, spacing: 8) {
                    Text("MASTER PASSWORD")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.0)
                    
                                    SecureField("Choose a master password", text: $password)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .disabled(isProcessing)
                        .onChange(of: password) { _, _ in
                            checkStrength()
                        }
                    
                    if !password.isEmpty {
                        // Strength meter
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(strengthText)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(strengthColor)
                                Spacer()
                                Text("\(Int(strengthScore * 100))%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 4)
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(strengthColor)
                                        .frame(width: geo.size.width * CGFloat(strengthScore), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.top, 4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONFIRM PASSWORD")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.0)
                    
                    SecureField("Confirm your password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .disabled(isProcessing)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    guard password.count >= 8 else {
                        errorMessage = "Master password must be at least 8 characters long."
                        return
                    }
                    let (strength, _) = AuditEngine.evaluateStrength(password)
                    guard strength == .strong else {
                        errorMessage = "Please choose a stronger master password (must meet the 'Strong' criteria below)."
                        return
                    }
                    guard password == confirmPassword else {
                        errorMessage = "Passwords do not match."
                        return
                    }
                    
                    isProcessing = true
                    errorMessage = ""
                    
                    Task {
                        let success = await vaultState.setupVault(password: password)
                        isProcessing = false
                        if !success {
                            errorMessage = vaultState.lastError ?? "Setup failed."
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Generating Secure Keys...")
                        } else {
                            Text("Create Secure Vault")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((password.isEmpty || confirmPassword.isEmpty || isProcessing) ? Color.accentColor.opacity(0.5) : Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .disabled(password.isEmpty || confirmPassword.isEmpty || isProcessing)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 10)
            }
            .frame(maxWidth: 380)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColorOrUiColor: .windowBackgroundColor).opacity(0.95))
    }
}
