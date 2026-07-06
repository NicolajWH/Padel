import SwiftUI
import UIKit
import SwiftData
import CoreLocation
import PadelKit

/// Finds shared games on courts near the user's location so they can join
/// with one tap — "Court 1", "Court 2", or an Americano session — no code
/// typing. Joining an Americano asks who you are so your row is highlighted.
/// Entering a code manually remains available as a fallback for when
/// location is off or the GPS fix is poor indoors.
struct JoinMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationProvider = LocationProvider()

    @State private var nearbyGames: [NearbyShared] = []
    @State private var isSearching = true
    @State private var searchFailed = false
    @State private var showingCodeEntry = false
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var pendingAmericano: AmericanoSession?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isSearching {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching for matches nearby…")
                                .foregroundStyle(.secondary)
                        }
                    } else if nearbyGames.isEmpty {
                        Group {
                            if locationProvider.isAuthorizationDenied {
                                Text("Location access is needed to find matches near you. Enable it for Padel in Settings, or join with a code below.")
                            } else if searchFailed {
                                Text("Couldn't search for matches nearby. Check your internet connection and try again.")
                            } else {
                                Text("No matches found nearby. Ask the player keeping score to turn on sharing in the live match.")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(nearbyGames) { game in
                            Button {
                                join(game)
                            } label: {
                                NearbyGameRow(game: game)
                            }
                            .buttonStyle(.plain)
                            .disabled(isJoining)
                        }
                    }
                } header: {
                    Text("Nearby Matches")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    if showingCodeEntry {
                        TextField("Match Code", text: $code)
                            .font(.system(.title3, design: .rounded).bold())
                            .kerning(2)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button {
                            joinWithCode()
                        } label: {
                            if isJoining {
                                ProgressView()
                            } else {
                                Text("Join Match")
                            }
                        }
                        .disabled(isJoining || SharedMatchController.normalize(code).count < 4)
                    } else {
                        Button("Enter code manually") {
                            showingCodeEntry = true
                        }
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("Join Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await search() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isSearching)
                }
            }
            .task {
                await search()
            }
            .sheet(item: $pendingAmericano) { session in
                WhoAreYouSheet(session: session) { player in
                    AmericanoIdentity.setPlayerID(player.id, for: session.id)
                    upsertAmericano(session)
                    pendingAmericano = nil
                    dismiss()
                }
            }
        }
    }

    private func search() async {
        isSearching = true
        searchFailed = false
        errorMessage = nil
        defer { isSearching = false }

        guard let location = await locationProvider.currentLocation() else {
            nearbyGames = []
            return
        }
        do {
            nearbyGames = try await SharedMatchController.fetchNearby(around: location)
        } catch {
            nearbyGames = []
            searchFailed = true
        }
    }

    private func joinWithCode() {
        let normalized = SharedMatchController.normalize(code)
        isJoining = true
        errorMessage = nil
        Task {
            do {
                let game = try await SharedMatchController.fetchShared(code: normalized)
                isJoining = false
                join(game)
            } catch {
                errorMessage = SharedMatchController.friendlyMessage(for: error)
                isJoining = false
            }
        }
    }

    private func join(_ game: NearbyShared) {
        switch game.content {
        case .match(let state):
            isJoining = true
            upsertMatch(state)
            dismiss()
        case .americano(let session):
            pendingAmericano = session
        }
    }

    private func upsertMatch(_ state: MatchState) {
        let matchID = state.id
        let descriptor = FetchDescriptor<MatchRecord>(predicate: #Predicate { $0.id == matchID })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(with: state)
        } else {
            modelContext.insert(MatchRecord.create(from: state))
        }
    }

    private func upsertAmericano(_ session: AmericanoSession) {
        let sessionID = session.id
        let descriptor = FetchDescriptor<AmericanoRecord>(predicate: #Predicate { $0.id == sessionID })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(with: session)
        } else {
            modelContext.insert(AmericanoRecord.create(from: session))
        }
    }
}

private struct NearbyGameRow: View {
    let game: NearbyShared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                switch game.content {
                case .match(let state):
                    Text("Court \(game.court)")
                        .font(.headline)
                    Text("\(state.teamA.displayName) vs \(state.teamB.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                case .americano(let session):
                    Text(session.name)
                        .font(.headline)
                    Text("\(session.settings.format.displayName) · \(session.players.count) players")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if case .match(let state) = game.content {
                let snap = state.snapshot
                Text("Sets \(snap.setsWonA)-\(snap.setsWonB)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private var icon: String {
        if case .americano = game.content { return "person.3.fill" }
        return "sportscourt.fill"
    }
}

/// Asks the joining player which participant they are, so their standings
/// row can be highlighted and points feel personal.
struct WhoAreYouSheet: View {
    let session: AmericanoSession
    let onPick: (Player) -> Void
    @AppStorage("profileName") private var profileName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(session.players) { player in
                        Button {
                            onPick(player)
                        } label: {
                            HStack(spacing: 12) {
                                PlayerAvatar(player: player, size: 32)
                                Text(player.name)
                                Spacer()
                                if isSuggested(player) {
                                    StatusPill(text: "You", color: .accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Pick your name so your standings row is highlighted on your phone.")
                }
            }
            .navigationTitle("Who are you?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func isSuggested(_ player: Player) -> Bool {
        let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        return player.name.localizedCaseInsensitiveContains(name) || name.localizedCaseInsensitiveContains(player.name)
    }
}

#Preview {
    JoinMatchView()
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
