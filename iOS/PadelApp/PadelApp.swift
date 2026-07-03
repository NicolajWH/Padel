import SwiftUI
import SwiftData

@main
struct PadelApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var connectivity = PhoneConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(connectivity)
        }
        .modelContainer(sharedModelContainer)
    }
}
