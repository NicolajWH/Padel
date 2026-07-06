import SwiftUI
import SwiftData

@main
struct PadelApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self])
        // The app has the CloudKit entitlement (for shared live scoring via the
        // public database), which makes SwiftData's default .automatic mode try
        // to CloudKit-sync this local store. That requires models without
        // .unique attributes and crashes at launch otherwise — so opt the local
        // store out explicitly.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var connectivity = PhoneConnectivityManager.shared

    init() {
        UserProfile.autofillNameIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(connectivity)
        }
        .modelContainer(sharedModelContainer)
    }
}
