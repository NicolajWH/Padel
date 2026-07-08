import SwiftUI
import SwiftData
import PadelKit

struct AmericanoSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayerRecord.name) private var savedPlayers: [SavedPlayerRecord]

    @State private var sessionName = ""
    @AppStorage("defaultAmericanoPoints") private var pointsPerRound = 21
    @State private var numberOfRounds = 5
    @State private var format: AmericanoFormat
    @State private var fixedPartners = false

    /// Selection state. In free mode players fill numbered court-style slots,
    /// exactly like the match court; in fixed-partners mode they live in
    /// explicit two-slot pair cards. Both are order-agnostic for scheduling.
    @State private var freeSlots: [Player?] = [nil, nil, nil, nil]
    @State private var selectedFreeSlot: Int?
    @State private var pairSlots: [[Player?]] = [[nil, nil], [nil, nil]]
    @State private var selectedPairSlot: PairSlotID?

    @State private var manualName = ""
    @State private var ownerPlayer: Player?
    @State private var guestPlayers: [Player] = []

    init(initialFormat: AmericanoFormat = .americano) {
        _format = State(initialValue: initialFormat)
    }

    @StateObject private var locationProvider = LocationProvider()
    @State private var nearbyPlayerList: [Player] = []
    @State private var isSearchingNearby = false

    @State private var createdRecord: AmericanoRecord?
    @State private var navigate = false

    private struct PairSlotID: Hashable {
        let pair: Int
        let slot: Int
        init(_ pair: Int, _ slot: Int) { self.pair = pair; self.slot = slot }
    }

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

            playersSection

            Section("Round Settings") {
                Stepper("Points per round: \(pointsPerRound)", value: $pointsPerRound, in: 8...40, step: 1)
                Stepper("Number of rounds: \(numberOfRounds)", value: $numberOfRounds, in: 1...20)
            }

            Section {
                Button("Generate Schedule & Start") { start() }
                    .disabled(!isValid)
            } footer: {
                if courtCount > 0 {
                    let sitOuts = chosenPlayers.count % 4
                    if sitOuts == 0 {
                        Text("Players: \(chosenPlayers.count) · Courts per round: \(courtCount)")
                    } else {
                        Text("Players: \(chosenPlayers.count) · Courts per round: \(courtCount) · \(sitOuts) sit out each round — sit-outs rotate fairly so everyone plays the same number of rounds.")
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
        .onChange(of: fixedPartners) { _, enabled in
            withAnimation(.snappy) { convertSelection(toPairs: enabled) }
        }
        .task {
            prefillOwnName()
            await findNearbyPlayers()
        }
    }

    // MARK: Players section

    @ViewBuilder
    private var playersSection: some View {
        Section {
            Toggle(isOn: $fixedPartners) {
                Text("Fixed partners")
            }
        } footer: {
            Text("Turn on to sign up as fixed pairs — partners stay together all session and only opponents rotate. Points still count per player.")
        }

        Section {
            if fixedPartners {
                pairsBuilder
            } else {
                freeSlotsBuilder
            }
        } header: {
            Text(fixedPartners ? "Pairs (min. 2)" : "Players (min. 4, multiples of 4 work best)")
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
            Text("Tap or drag players to add them")
        }
    }

    private var freeSlotsBuilder: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(freeSlotRows, id: \.self) { row in
                HStack(spacing: 10) {
                    freeSlot(index: row[0])
                    if row.count > 1 {
                        freeSlot(index: row[1])
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            Text("\(selectedPlayers.count) players")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)
    }

    /// Free slots laid out two-per-row, mirroring the match court.
    private var freeSlotRows: [[Int]] {
        stride(from: 0, to: freeSlots.count, by: 2).map { start in
            Array(start..<min(start + 2, freeSlots.count))
        }
    }

    private func freeSlot(index: Int) -> some View {
        PlayerSlotView(
            player: freeSlots[index],
            accent: PadelTheme.courtBlue,
            isSelected: selectedFreeSlot == index,
            onTapEmpty: {
                withAnimation(.snappy) {
                    selectedFreeSlot = (selectedFreeSlot == index) ? nil : index
                }
            },
            onRemove: {
                withAnimation(.snappy) {
                    freeSlots[index] = nil
                    normalizeFreeSlots()
                    selectedFreeSlot = firstEmptyFreeSlot()
                }
            },
            onDrop: { id in dropIntoFreeSlot(id, index: index) }
        )
    }

    private var pairsBuilder: some View {
        VStack(spacing: 12) {
            ForEach(Array(pairSlots.enumerated()), id: \.offset) { index, pair in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Pair \(index + 1)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if pairSlots.count > 2 {
                            Button {
                                withAnimation(.snappy) { removePair(index) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 10) {
                        pairSlot(pair: index, slot: 0)
                        pairSlot(pair: index, slot: 1)
                    }
                }
            }

            Button {
                withAnimation(.snappy) { pairSlots.append([nil, nil]) }
            } label: {
                Label("Add Pair", systemImage: "plus")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowBackground(Color.clear)
    }

    private func pairSlot(pair: Int, slot: Int) -> some View {
        PlayerSlotView(
            player: pairSlots[pair][slot],
            accent: PadelTheme.courtBlue,
            isSelected: selectedPairSlot == PairSlotID(pair, slot),
            onTapEmpty: {
                withAnimation(.snappy) {
                    let id = PairSlotID(pair, slot)
                    selectedPairSlot = (selectedPairSlot == id) ? nil : id
                }
            },
            onRemove: {
                withAnimation(.snappy) {
                    pairSlots[pair][slot] = nil
                    selectedPairSlot = PairSlotID(pair, slot)
                }
            },
            onDrop: { id in dropIntoPairSlot(id, pair: pair, slot: slot) }
        )
    }

    // MARK: Selection model

    /// Players already chosen, regardless of mode.
    private var selectedPlayers: [Player] {
        fixedPartners ? pairSlots.flatMap { $0 }.compactMap { $0 } : freeSlots.compactMap { $0 }
    }

    /// The players a session will actually start with — complete pairs only
    /// when partners are fixed.
    private var chosenPlayers: [Player] {
        guard fixedPartners else { return freeSlots.compactMap { $0 } }
        return pairSlots.filter { $0.allSatisfy { $0 != nil } }.flatMap { $0 }.compactMap { $0 }
    }

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

    private var poolPlayers: [Player] {
        let chosen = Set(selectedPlayers.map { $0.name.lowercased() })
        return candidatePlayers.filter { !chosen.contains($0.name.lowercased()) }
    }

    private func isChosen(_ player: Player) -> Bool {
        selectedPlayers.contains { $0.name.lowercased() == player.name.lowercased() }
    }

    private func assign(_ player: Player) {
        guard !isChosen(player) else { return }
        withAnimation(.snappy) {
            if fixedPartners {
                guard let target = selectedPairSlot ?? firstEmptyPairSlot() else { return }
                pairSlots[target.pair][target.slot] = player
                selectedPairSlot = firstEmptyPairSlot()
            } else {
                let target = selectedFreeSlot ?? firstEmptyFreeSlot()
                if let target { freeSlots[target] = player } else { freeSlots.append(player) }
                normalizeFreeSlots()
                selectedFreeSlot = firstEmptyFreeSlot()
            }
        }
    }

    private func dropIntoFreeSlot(_ id: String, index: Int) -> Bool {
        if let source = freeSlots.firstIndex(where: { $0?.id.uuidString == id }) {
            guard source != index else { return false }
            withAnimation(.snappy) {
                let displaced = freeSlots[index]
                freeSlots[index] = freeSlots[source]
                freeSlots[source] = displaced
                normalizeFreeSlots()
            }
            return true
        }
        guard let player = candidatePlayers.first(where: { $0.id.uuidString == id }), !isChosen(player) else { return false }
        withAnimation(.snappy) {
            freeSlots[index] = player
            normalizeFreeSlots()
            selectedFreeSlot = firstEmptyFreeSlot()
        }
        return true
    }

    private func dropIntoPairSlot(_ id: String, pair: Int, slot: Int) -> Bool {
        if let source = findPairSlot(withID: id) {
            guard source != PairSlotID(pair, slot) else { return false }
            withAnimation(.snappy) {
                let displaced = pairSlots[pair][slot]
                pairSlots[pair][slot] = pairSlots[source.pair][source.slot]
                pairSlots[source.pair][source.slot] = displaced
            }
            return true
        }
        guard let player = candidatePlayers.first(where: { $0.id.uuidString == id }), !isChosen(player) else { return false }
        withAnimation(.snappy) {
            pairSlots[pair][slot] = player
            selectedPairSlot = firstEmptyPairSlot()
        }
        return true
    }

    private func firstEmptyFreeSlot() -> Int? {
        freeSlots.firstIndex(where: { $0 == nil })
    }

    /// Keep filled slots first, always leave one trailing empty slot to drop or
    /// tap into, and never show fewer than four — so the court can grow to any
    /// number of players while staying tidy.
    private func normalizeFreeSlots() {
        var slots: [Player?] = freeSlots.compactMap { $0 }.map { Optional($0) }
        slots.append(nil)
        while slots.count < 4 { slots.append(nil) }
        freeSlots = slots
    }

    private func firstEmptyPairSlot() -> PairSlotID? {
        for (p, pair) in pairSlots.enumerated() {
            for (s, value) in pair.enumerated() where value == nil {
                return PairSlotID(p, s)
            }
        }
        return nil
    }

    private func findPairSlot(withID id: String) -> PairSlotID? {
        for (p, pair) in pairSlots.enumerated() {
            for (s, value) in pair.enumerated() where value?.id.uuidString == id {
                return PairSlotID(p, s)
            }
        }
        return nil
    }

    private func removePair(_ index: Int) {
        guard pairSlots.count > 2 else { return }
        pairSlots.remove(at: index)
        selectedPairSlot = nil
    }

    /// Keep the picked players when the pairs toggle flips.
    private func convertSelection(toPairs: Bool) {
        if toPairs {
            let players = freeSlots.compactMap { $0 }
            var slots: [[Player?]] = []
            var index = 0
            while index < players.count {
                let second: Player? = index + 1 < players.count ? players[index + 1] : nil
                slots.append([players[index], second])
                index += 2
            }
            while slots.count < 2 { slots.append([nil, nil]) }
            pairSlots = slots
            freeSlots = [nil, nil, nil, nil]
            selectedFreeSlot = nil
        } else {
            freeSlots = pairSlots.flatMap { $0 }.compactMap { $0 }.map { Optional($0) }
            normalizeFreeSlots()
            pairSlots = [[nil, nil], [nil, nil]]
            selectedFreeSlot = firstEmptyFreeSlot()
        }
        selectedPairSlot = nil
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

    // MARK: Derived

    private var courtCount: Int { chosenPlayers.count / 4 }

    private var isValid: Bool { chosenPlayers.count >= 4 }

    /// The person setting up the session is almost always playing in it.
    private func prefillOwnName() {
        guard !UserProfile.name.isEmpty, selectedPlayers.isEmpty else { return }
        let owner = savedPlayers.first { $0.name.lowercased() == UserProfile.name.lowercased() }?.asPlayer
            ?? Player(name: UserProfile.name)
        ownerPlayer = owner
        if fixedPartners {
            pairSlots[0][0] = owner
            selectedPairSlot = PairSlotID(0, 1)
        } else {
            freeSlots[0] = owner
            normalizeFreeSlots()
            selectedFreeSlot = firstEmptyFreeSlot()
        }
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

    private func start() {
        let players = chosenPlayers
        let settings = AmericanoSettings(
            pointsPerRound: pointsPerRound,
            numberOfCourts: max(1, courtCount),
            numberOfRounds: numberOfRounds,
            format: format,
            fixedPartners: fixedPartners
        )
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
