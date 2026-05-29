# Contributing to Fortress

Thank you for your interest in contributing to Fortress! We welcome bug reports, feature requests, and code contributions.

---

## Code of Conduct

Please be respectful, collaborative, and constructive when participating in our community.

---

## Getting Started

1. Fork the repository on GitHub.
2. Clone your fork locally:
   ```bash
   git clone https://github.com/yourusername/Fortress.git
   cd Fortress
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/my-amazing-feature
   ```
4. Verify that the tests build and pass:
   ```bash
   swift test
   ```

---

## Development Guidelines

### Concurrency
All asynchronous operations should run off the main thread.
- Use `Task.detached` for CPU-intensive tasks like key derivation (`CryptoEngine.deriveKey`), backups, and exports.
- Use `@MainActor` or `await MainActor.run` when mutating `@Observable` states that affect the UI.

### Security and Concurrency Warning Free
Make sure your changes do not introduce compilation warnings in Swift 6 language mode. Pay close attention to Sendability when transferring objects across task boundaries.

### SF Symbols compatibility
Only use SF Symbols that are compatible with the target platforms (iOS 17+ and macOS 14+). Avoid newer symbols that are not available in older platform SDK runtimes.

---

## Submitting Pull Requests

1. Commit your changes with descriptive messages.
2. Push your changes to your fork.
3. Open a Pull Request from your feature branch to the `main` branch of the original repository.
4. Ensure all unit tests pass on CI/CD pipelines.
