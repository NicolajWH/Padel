import SwiftUI
import SwiftData
import PadelKit

struct NewMatchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayerRecord.name) private var savedPlayers: [SavedPlayerRecord]

    /// The four match slots: 0/1 = Team A, 2/3 = Team B.
    @State private var slots: [Player?] = [nil, nil, nil, nil]
    @State private var selectedSlot: Int?
    @State private var manualName = ""
    /// Owner and guest players aren't in the saved list, so we keep stable
    /// copies here — their ids must survive re-renders for drag-and-drop.
    @State private var ownerPlayer: Player?
    @State private var guestPlayers: [Player] = []

    @StateObject private var locationProvider = LocationProvider()
    @State private var nearbyPlayerList: [Player] = []
    @State private var isSearchingNearby = false

    @AppStorage("defaultGoldenPoint") private var goldenPoint = false
    @AppStorage("defaultSetsToWin") private var setsToWin = 2
    @State private var finalSetMatchTiebreak = false
    @State private var firstServer: TeamSide = .teamA

    @State private var createdRecord: MatchRecord?
    @State private var navigate = false

    var body: some View {
        Form {
            Section {
                TeamBuilder(
                    slots: $slots,
                    selectedSlot: $selectedSlot,
                    onDropFromPool: { idString, target in assignByID(idString, to: target) }
                )
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            } footer: {
                Text("Tap a slot then a player, or drag players onto the court. Everyone can only be picked once.")
            }

            Section {
                HStack {
                    TextField("Add a guest player", text: $manualName)
                        .submitLabel(.done)
                        .onSubmit(addGuest)
                    Button(action: addGuest) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.plain)
                }

                if isSearchingNearby && nearbyPlayerList.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Looking for players nearby…")
                            .foregroundStyle(.secondary)
                    }
                }

                if poolPlayers.isEmpty {
                    if !isSearchingNearby {
                        Text("Add players above, or save players to quick-pick them here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(poolPlayers) { player in
                            PlayerChip(player: player) { assign(player) }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Players")
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
                    Text("Your Team").tag(TeamSide.teamA)
                    Text("Their Team").tag(TeamSide.teamB)
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
        .task {
            prefillOwnName()
            await findNearbyPlayers()
        }
    }

    private var isValid: Bool {
        slots.allSatisfy { $0 != nil }
    }

    /// Every player who could be assigned, de-duplicated by name so the same
    /// person can't appear twice via different sources.
    private var candidatePlayers: [Player] {
        var seen = Set<String>()
        var result: [Player] = []
        func add(_ players: [Player]) {
            for player in players {
                let key = player.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                result.append(player)
            }
        }
        add([ownerPlayer].compactMap { $0 })
        add(savedPlayers.map(\.asPlayer))
        add(nearbyPlayerList)
        add(guestPlayers)
        return result
    }

    /// Candidates not already standing on the court.
    private var poolPlayers: [Player] {
        let assigned = Set(slots.compactMap { $0?.name.lowercased() })
        return candidatePlayers.filter { !assigned.contains($0.name.lowercased()) }
    }

    private func assign(_ player: Player) {
        let assigned = Set(slots.compactMap { $0?.name.lowercased() })
        guard !assigned.contains(player.name.lowercased()) else { return }
        guard let target = selectedSlot ?? slots.firstIndex(where: { $0 == nil }) else { return }
        withAnimation(.snappy) {
            slots[target] = player
            selectedSlot = slots.firstIndex(where: { $0 == nil })
        }
    }

    /// Resolves a dragged pool chip by id and drops it into `target`.
    private func assignByID(_ idString: String, to target: Int) -> Bool {
        guard let player = candidatePlayers.first(where: { $0.id.uuidString == idString }) else { return false }
        withAnimation(.snappy) {
            slots[target] = player
            selectedSlot = slots.firstIndex(where: { $0 == nil })
        }
        return true
    }

    private func addGuest() {
        let trimmed = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existing = candidatePlayers.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            assign(existing)
        } else {
            let player = Player(name: trimmed)
            guestPlayers.append(player)
            assign(player)
        }
        manualName = ""
    }

    /// The person creating the match is almost always playing in it.
    private func prefillOwnName() {
        guard !UserProfile.name.isEmpty, slots.allSatisfy({ $0 == nil }) else { return }
        let owner = savedPlayers.first { $0.name.lowercased() == UserProfile.name.lowercased() }?.asPlayer
            ?? Player(name: UserProfile.name)
        ownerPlayer = owner
        slots[0] = owner
        selectedSlot = 1
    }

    /// Looks up who else is at the court right now — and publishes our own
    /// presence so their phones see us too.
    private func findNearbyPlayers() async {
        isSearchingNearby = true
        defer { isSearchingNearby = false }
        guard let location = await locationProvider.currentLocation() else { return }
        await NearbyPlayersService.publish(name: UserProfile.name, location: location)
        let found = (try? await NearbyPlayersService.fetchNearby(around: location)) ?? []
        nearbyPlayerList = found.map { Player(name: $0.name) }
    }

    private func startMatch() {
        guard let a1 = slots[0], let a2 = slots[1], let b1 = slots[2], let b2 = slots[3] else { return }
        let teamA = Team(players: [a1, a2])
        let teamB = Team(players: [b1, b2])
        let settings = MatchSettings(
            goldenPoint: goldenPoint,
            setsToWin: setsToWin,
            finalSetIsMatchTiebreak: finalSetMatchTiebreak
        )
        let state = MatchState(teamA: teamA, teamB: teamB, settings: settings, firstServer: firstServer)
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
