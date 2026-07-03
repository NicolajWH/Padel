import SwiftUI
import SwiftData
import PadelKit

struct AmericanoHomeView: View {
    @Query(sort: \AmericanoRecord.createdAt, order: .reverse) private var sessions: [AmericanoRecord]

    private var ongoing: AmericanoRecord? {
        sessions.first { !$0.isFinished && $0.session?.rounds.isEmpty == false }
    }

    var body: some View {
        List {
            if let ongoing, let session = ongoing.session {
                Section("Continue") {
                    NavigationLink {
                        AmericanoRoundScoringView(record: ongoing, session: session)
                    } label: {
                        AmericanoRowView(session: session)
                    }
                }
            }

            Section {
                NavigationLink {
                    AmericanoSetupView()
                } label: {
                    Label("New Americano", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            } footer: {
                Text("Set up a group, rotate partners automatically, and add up everyone's individual points — just like Americano padel, right on your Apple Watch.")
            }

            if !sessions.isEmpty {
                Section("Recent") {
                    ForEach(sessions.prefix(5)) { record in
                        if let session = record.session {
                            NavigationLink {
                                AmericanoStandingsView(record: record, session: session)
                            } label: {
                                AmericanoRowView(session: session)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Americano")
    }
}

#Preview {
    NavigationStack { AmericanoHomeView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
