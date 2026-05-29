# Fortress

**Fortress** is a native, local-first, zero-knowledge password and credentials manager for iOS, macOS, and iPadOS. It is built entirely in SwiftUI and SwiftData, prioritizing user privacy, speed, and modern Apple design aesthetics.

---

## Features

- **Zero-Knowledge Security:** All data is encrypted locally using AES-256-GCM before writing to the database. The master key is derived using PBKDF2-SHA256 (100,000 iterations).
- **Native Biometrics:** Unlock your vault instantly and securely using Face ID or Touch ID, backed by the device's Secure Enclave and Keychain.
- **Apple-Style AutoFill Passwords:** Generate secure, alphanumeric passwords matching Apple's strong password criteria (excluding ambiguous characters).
- **Password Strength Meter & Auditing:** Real-time entropy checking, reused password detection, and visual strength indicators.
- **Watchtower (k-Anonymity Leak Check):** Check if your passwords have appeared in public breaches via a secure, local-hash-matching query to the *Have I Been Pwned* API without revealing your passwords.
- **Multi-Manager CSV Importer:** Easily import credentials exported from 1Password, Bitwarden, and Google Chrome.
- **Secure Encrypted Backups:** Export and import your vault securely as a binary file encrypted using a custom backup password.
- **Auto-Wipe Protection:** Configure the app to wipe the database and keychain credentials after a customized number of failed unlock attempts.

---

## Technical Architecture

Fortress utilizes a zero-knowledge key wrapping architecture:
- **Master Key (MK):** Derived from the Master Password and a unique salt using **PBKDF2-SHA256**.
- **Symmetric Master Key (SMK):** A cryptographically secure random 256-bit key. All item payloads are encrypted with the SMK.
- **Key Wrapping:** The SMK is encrypted using the derived Master Key and stored in the Keychain. Master password changes only require re-wrapping the SMK.
- **Item Encryption:** Each vault item is encrypted with the SMK using **AES-256-GCM** (providing authenticated encryption).

---

## Getting Started

### Prerequisites
- macOS Sonoma (14.0) or iOS 17.0 or newer.
- Xcode 15.0+ or Swift 5.9+ Toolchain.

### Build and Run using CLI
```bash
# Clone the repository
git clone https://github.com/yourusername/Fortress.git
cd Fortress

# Build the project
swift build

# Run the unit tests
swift test
```

### Build and Run using Xcode
1. Open the folder in Xcode or double-click the generated `Fortress.xcodeproj`.
2. Select your target device or simulator (macOS or iOS).
3. Press `Cmd + R` to build and run.

*Note: The project includes a `generate_xcodeproj.py` script that can be used to regenerate the Xcode project template if needed.*

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
