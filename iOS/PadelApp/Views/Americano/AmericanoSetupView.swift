import SwiftUI
import SwiftData
import PadelKit

struct AmericanoSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayerRecord.name) private var savedPlayers: [SavedPlayerRecord]

    @State private var sessionName = ""
    @State private var playerNames: [String] = ["", "", "", ""]
    @AppStorage("defaultAmericanoPoints") private var pointsPerRound = 21
    @State private var numberOfRounds = 5
    @State private var format: AmericanoFormat

    init(initialFormat: AmericanoFormat = .americano) {
        _format = State(initialValue: initialFormat)
    }

    @StateObject private var locationProvider = LocationProvider()
    @State private var nearbyPlayers: [NearbyPlayer] = []
    @State private var isSearchingNearby = false

    @State private var createdRecord: AmericanoRecord?
    @State private var navigate = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    FormatMascot(format: format, size: 150, cornerRadius: 22)
                        .padding(.vertical, 4)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                TextField(format.displayName, text: $sessionName)
                Picker("Format", selection: $format) {
                    ForEach(AmericanoFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Session")
            } footer: {
                switch format {
                case .americano:
                    Text("Partners and opponents rotate so everyone plays with everyone. All rounds are drawn up front.")
                case .mexicano:
                    Text("Each round is drawn from the live standings — 1st + 4th play 2nd + 3rd — so games get more even as you go. The next round appears when all courts finish.")
                }
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

            if isSearchingNearby || !availableNearbyPlayers.isEmpty {
                Section {
                    if isSearchingNearby && nearbyPlayers.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Looking for players nearby…")
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(availableNearbyPlayers) { player in
                        Button {
                            fill(name: player.name)
                        } label: {
                            Label(player.name, systemImage: "person.wave.2.fill")
                        }
                    }
                } header: {
                    Text("Players Nearby")
                } footer: {
                    Text("Players who have Padel open nearby appear here automatically — tap a name to add it.")
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
                    let sitOuts = validNames.count % 4
                    if sitOuts == 0 {
                        Text("Players: \(validNames.count) · Courts per round: \(courtCount)")
                    } else {
                        Text("Players: \(validNames.count) · Courts per round: \(courtCount) · \(sitOuts) sit out each round — sit-outs rotate fairly so everyone plays the same number of rounds.")
                    }
                }
            }
        }
        .navigationTitle(format == .mexicano ? String(localized: "New Mexicano") : String(localized: "New Americano"))
        .navigationDestination(isPresented: $navigate) {
            if let createdRecord, let session = createdRecord.session {
                AmericanoRoundScoringView(record: createdRecord, session: session)
            }
        }
        .task {
            prefillOwnName()
            await findNearbyPlayers()
        }
    }

    private var validNames: [String] {
        playerNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Nearby players not already typed into one of the slots.
    private var availableNearbyPlayers: [NearbyPlayer] {
        let used = Set(validNames.map { $0.lowercased() })
        return nearbyPlayers.filter { !used.contains($0.name.lowercased()) }
    }

    /// The person setting up the Americano is almost always playing in it.
    private func prefillOwnName() {
        guard !UserProfile.name.isEmpty, validNames.isEmpty, !playerNames.isEmpty else { return }
        playerNames[0] = UserProfile.name
    }

    /// Looks up who else is at the court right now — and publishes our own
    /// presence so their phones see us too.
    private func findNearbyPlayers() async {
        isSearchingNearby = true
        defer { isSearchingNearby = false }
        guard let location = await locationProvider.currentLocation() else { return }
        await NearbyPlayersService.publish(name: UserProfile.name, location: location)
        nearbyPlayers = (try? await NearbyPlayersService.fetchNearby(around: location)) ?? []
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
        let settings = AmericanoSettings(pointsPerRound: pointsPerRound, numberOfCourts: max(1, courtCount), numberOfRounds: numberOfRounds, format: format)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
        let session = AmericanoSession(name: sessionName.isEmpty ? format.displayName : sessionName, players: players, settings: settings, rounds: rounds)
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
