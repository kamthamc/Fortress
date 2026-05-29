import SwiftUI
import SwiftData

public struct MainView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isUnlocking = false
    
    @Bindable private var vaultState = VaultState.shared
    
    public init() {}
    
    public var body: some View {
        Group {
            if !vaultState.isSetup {
                SetupView()
            } else if !vaultState.isUnlocked {
                renderLockScreen()
            } else {
                DashboardView()
            }
        }
        .onAppear {
            vaultState.checkSetupState()
            // Auto trigger biometrics on start if enabled
            if vaultState.isSetup && vaultState.biometricUnlockEnabled {
                _ = vaultState.unlockWithBiometrics()
            }
        }
    }
    
    @ViewBuilder
    private func renderLockScreen() -> some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Text("FORTRESS")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundColor(.primary)
                
                Text("Enter your Master Password to decrypt and access your credentials.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            
            VStack(spacing: 16) {
                SecureField("Master Password", text: $password)
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
                    .disabled(isUnlocking)
                    .onSubmit {
                        attemptUnlock()
                    }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 12) {
                    Button(action: attemptUnlock) {
                        HStack(spacing: 8) {
                            if isUnlocking {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Decrypting...")
                            } else {
                                Text("Unlock Vault")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 8).fill((password.isEmpty || isUnlocking) ? Color.accentColor.opacity(0.5) : Color.accentColor))
                    }
                    .buttonStyle(.plain)
                    .disabled(password.isEmpty || isUnlocking)
                    .keyboardShortcut(.defaultAction)
                    
                    // Biometric Unlock Quick Button
                    if vaultState.biometricUnlockEnabled {
                        Button {
                            guard !isUnlocking else { return }
                            let success = vaultState.unlockWithBiometrics()
                            if !success {
                                errorMessage = vaultState.lastError ?? "Biometric authentication failed."
                            }
                        } label: {
                            Image(systemName: "faceid")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUnlocking)
                        .help("Unlock with biometrics")
                    }
                }
            }
            .frame(maxWidth: 300)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColorOrUiColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColorOrUiColor: .windowBackgroundColor).opacity(0.95))
    }
    
    private func attemptUnlock() {
        guard !password.isEmpty && !isUnlocking else { return }
        isUnlocking = true
        errorMessage = ""
        
        Task {
            let success = await vaultState.unlockVault(password: password)
            isUnlocking = false
            if success {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                    password = ""
                    errorMessage = ""
                }
            } else {
                errorMessage = vaultState.lastError ?? "Incorrect Master Password. Please try again."
            }
        }
    }
}
