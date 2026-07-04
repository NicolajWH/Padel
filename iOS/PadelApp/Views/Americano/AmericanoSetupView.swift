import SwiftUI
import SwiftData
import PadelKit

struct AmericanoSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayerRecord.name) private var savedPlayers: [SavedPlayerRecord]

    @State private var sessionName = "Americano"
    @State private var playerNames: [String] = ["", "", "", ""]
    @AppStorage("defaultAmericanoPoints") private var pointsPerRound = 21
    @State private var numberOfRounds = 5

    @State private var createdRecord: AmericanoRecord?
    @State private var navigate = false

    var body: some View {
        Form {
            Section("Session") {
                TextField("Name", text: $sessionName)
            }

            Section("Players (min. 4, multiples of 4 work best)") {
                ForEach(playerNames.indices, id: \.self) { index in
                    TextField("Player \(index + 1)", text: $playerNames[index])
                }
                .onDelete { offsets in playerNames.remove(atOffsets: offsets) }

                Button {
                    playerNames.append("")
                } label: {
                    Label("Add Player", systemImage: "plus")
                }
            }

            if !savedPlayers.isEmpty {
                Section("Quick Add From Saved Players") {
                    ForEach(savedPlayers) { player in
                        Button {
                            fill(name: player.name)
                        } label: {
                            PlayerRow(player: player.asPlayer)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Round Settings") {
                Stepper("Points per round: \(pointsPerRound)", value: $pointsPerRound, in: 8...40, step: 1)
                Stepper("Number of rounds: \(numberOfRounds)", value: $numberOfRounds, in: 1...20)
            }

            Section {
                Button("Generate Schedule & Start") { start() }
                    .disabled(!isValid)
            } footer: {
                if courtCount > 0 {
                    Text("\(validNames.count) players on \(courtCount) court\(courtCount == 1 ? "" : "s") per round.")
                }
            }
        }
        .navigationTitle("New Americano")
        .navigationDestination(isPresented: $navigate) {
            if let createdRecord, let session = createdRecord.session {
                AmericanoRoundScoringView(record: createdRecord, session: session)
            }
        }
    }

    private var validNames: [String] {
        playerNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var courtCount: Int { validNames.count / 4 }

    private var isValid: Bool { validNames.count >= 4 }

    private func fill(name: String) {
        if let emptyIndex = playerNames.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            playerNames[emptyIndex] = name
        } else {
            playerNames.append(name)
        }
    }

    private func start() {
        let players = validNames.map { Player(name: $0) }
        let settings = AmericanoSettings(pointsPerRound: pointsPerRound, numberOfCourts: max(1, courtCount), numberOfRounds: numberOfRounds)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
        let session = AmericanoSession(name: sessionName.isEmpty ? "Americano" : sessionName, players: players, settings: settings, rounds: rounds)
        let record = AmericanoRecord.create(from: session)
        modelContext.insert(record)
        createdRecord = record
        navigate = true
    }
}

#Preview {
    NavigationStack { AmericanoSetupView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
