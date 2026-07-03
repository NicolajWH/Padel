import SwiftUI
import SwiftData
import PadelKit

struct NewMatchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayerRecord.name) private var savedPlayers: [SavedPlayerRecord]

    @State private var teamAPlayer1 = ""
    @State private var teamAPlayer2 = ""
    @State private var teamBPlayer1 = ""
    @State private var teamBPlayer2 = ""

    @AppStorage("defaultGoldenPoint") private var goldenPoint = false
    @AppStorage("defaultSetsToWin") private var setsToWin = 2
    @State private var finalSetMatchTiebreak = false
    @State private var firstServer: TeamSide = .teamA

    @State private var createdRecord: MatchRecord?
    @State private var navigate = false

    var body: some View {
        Form {
            Section("Team A") {
                TextField("Player 1", text: $teamAPlayer1)
                TextField("Player 2", text: $teamAPlayer2)
            }
            Section("Team B") {
                TextField("Player 1", text: $teamBPlayer1)
                TextField("Player 2", text: $teamBPlayer2)
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

            Section("Scoring") {
                Toggle("Golden Point (sudden death at 40-40)", isOn: $goldenPoint)
                Picker("Match Format", selection: $setsToWin) {
                    Text("Single Set").tag(1)
                    Text("Best of 3 Sets").tag(2)
                }
                if setsToWin == 2 {
                    Toggle("Match Tiebreak for Deciding Set", isOn: $finalSetMatchTiebreak)
                }
                Picker("First Serve", selection: $firstServer) {
                    Text("Team A").tag(TeamSide.teamA)
                    Text("Team B").tag(TeamSide.teamB)
                }
            }

            Section {
                Button("Start Match") { startMatch() }
                    .disabled(!isValid)
            }
        }
        .navigationTitle("New Match")
        .navigationDestination(isPresented: $navigate) {
            if let createdRecord, let state = createdRecord.state {
                LiveMatchView(record: createdRecord, initialState: state)
            }
        }
    }

    private var isValid: Bool {
        [teamAPlayer1, teamAPlayer2, teamBPlayer1, teamBPlayer2]
            .allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func fill(name: String) {
        if teamAPlayer1.isEmpty { teamAPlayer1 = name }
        else if teamAPlayer2.isEmpty { teamAPlayer2 = name }
        else if teamBPlayer1.isEmpty { teamBPlayer1 = name }
        else if teamBPlayer2.isEmpty { teamBPlayer2 = name }
    }

    private func startMatch() {
        let teamA = Team(players: [Player(name: teamAPlayer1), Player(name: teamAPlayer2)])
        let teamB = Team(players: [Player(name: teamBPlayer1), Player(name: teamBPlayer2)])
        let settings = MatchSettings(
            goldenPoint: goldenPoint,
            setsToWin: setsToWin,
            finalSetIsMatchTiebreak: finalSetMatchTiebreak
        )
        let state = MatchState(settings: settings, teamA: teamA, teamB: teamB, firstServer: firstServer)
        let record = MatchRecord.create(from: state)
        modelContext.insert(record)
        createdRecord = record
        navigate = true
    }
}

#Preview {
    NavigationStack { NewMatchSetupView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
