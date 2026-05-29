import SwiftUI
import SwiftData

@main
struct FortressApp: App {
    // Standard SwiftData Model Container for versioned vault schema
    let container: ModelContainer
    
    init() {
        let schema = Schema([VaultItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("Failed to initialize SwiftData model container, attempting to reset store: \(error.localizedDescription)")
            // On schema migration mismatch, clear the local SQLite files and retry initialization
            let url = config.url
            let fileManager = FileManager.default
            let sqliteURL = url
            let shmURL = url.deletingPathExtension().appendingPathExtension("sqlite-shm")
            let walURL = url.deletingPathExtension().appendingPathExtension("sqlite-wal")
            
            try? fileManager.removeItem(at: sqliteURL)
            try? fileManager.removeItem(at: shmURL)
            try? fileManager.removeItem(at: walURL)
            
            do {
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not initialize SwiftData model container after reset: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .modelContainer(container)
                .frame(minWidth: 700, minHeight: 450) // Premium desktop layout sizing
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        #endif
    }
}
