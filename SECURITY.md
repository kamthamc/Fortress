# Security Policy

## Security Model & Zero-Knowledge Architecture

Fortress is built on a local-first, zero-knowledge security model. Your master password never leaves your device and is never stored in plaintext anywhere.

### Key Derivation & Wrapping
- **Key Derivation Function (KDF):** Master keys are derived using PBKDF2-SHA256 with 100,000 iterations and a cryptographically secure 32-byte salt.
- **Symmetric Master Key (SMK):** A 256-bit AES key generated using the system's cryptographically secure pseudo-random number generator (`SecRandomCopyBytes`).
- **Key Wrapping:** The SMK is wrapped (encrypted) with the derived Master Key using AES-256-GCM. The wrapped SMK and salt are saved in the device's Keychain.
- **Item Payloads:** Individual credentials, credit cards, bank accounts, and notes are serialized into JSON, then encrypted with the unwrapped SMK using AES-256-GCM.

### Biometric Security & Keychain Isolation
- When biometric unlock is enabled, the derived Master Key is saved to a biometric-gated Keychain item.
- This item is protected by access control rules specifying user presence (`.userPresence`), ensuring the Master Key can only be accessed after a successful Touch ID, Face ID, or system passcode prompt.
- This key does not sync via iCloud Keychain and is bound to the Secure Enclave of the active device.

### Leak Check Privacy (Have I Been Pwned API)
Fortress uses **k-Anonymity** to verify password leaks:
1. Calculates the SHA-1 hash of the password.
2. Sends *only* the first 5 characters of the hash to the API.
3. Retrieves the list of matching suffix hashes.
4. Matches the suffix locally to count occurrences.
The API provider never receives your password or the full hash.

---

## Reporting a Vulnerability

We take the security of Fortress seriously. If you find a security vulnerability, please do not disclose it publicly or file a public GitHub issue. 

Please report vulnerabilities privately by emailing security@yourdomain.com (or create a private security advisory on GitHub).

We will investigate all reports and aim to provide a swift resolution.
