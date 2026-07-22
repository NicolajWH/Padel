import SwiftUI
import SwiftData
import PadelKit

struct PlayHomeView: View {
    @Query(sort: \MatchRecord.createdAt, order: .reverse) private var matches: [MatchRecord]
    @Query private var americanos: [AmericanoRecord]
    @State private var showingJoin = false
    @StateObject private var locationProvider = LocationProvider()
    @State private var nearbyGameCount = 0

    private var ongoingMatch: MatchRecord? { matches.first { !$0.isFinished } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                if nearbyGameCount > 0 {
                    Button { showingJoin = true } label: { NearbyGamesBanner(count: nearbyGameCount) }
                        .buttonStyle(PremiumPressStyle())
                }

                if let ongoingMatch, let state = ongoingMatch.state {
                    NavigationLink { LiveMatchView(record: ongoingMatch, initialState: state) } label: { OngoingMatchCard(state: state) }
                        .buttonStyle(PremiumPressStyle())
                }

                NavigationLink { NewMatchSetupView() } label: {
                    PremiumImageCard(
                        assetName: "CourtHero", category: "MATCH", title: "New Match",
                        subtitle: "Create a match, invite players, and get started.", icon: "tennis.racket", cta: "Start Match"
                    )
                }
                .buttonStyle(PremiumPressStyle())

                Button { showingJoin = true } label: {
                    PremiumCard(cornerRadius: DesignSystem.Radius.card) {
                        HStack(spacing: 14) {
                            Image(systemName: "person.2.wave.2.fill").font(.title3).foregroundStyle(DesignSystem.padelBlue).frame(width: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Join Match").font(.headline).foregroundStyle(DesignSystem.textPrimary)
                                Text("Find a shared match nearby and join the court.").font(.subheadline).foregroundStyle(DesignSystem.textSecondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(DesignSystem.textSecondary)
                        }
                    }
                }
                .buttonStyle(PremiumPressStyle())

                if !matches.isEmpty {
                    HStack {
                        SectionHeader(title: "Recent Matches", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        NavigationLink("See All") { HistoryView() }.font(.subheadline.weight(.semibold)).foregroundStyle(DesignSystem.padelBlue)
                    }.padding(.top, 6)
                    ForEach(matches.prefix(5)) { record in
                        if let state = record.state {
                            NavigationLink {
                                record.isFinished ? AnyView(MatchSummaryView(state: state)) : AnyView(LiveMatchView(record: record, initialState: state))
                            } label: { ScoreRowCard(state: state, date: record.createdAt) }
                            .buttonStyle(PremiumPressStyle())
                        }
                    }
                }
            }.padding(DesignSystem.Spacing.large)
        }
        .padelBackground().screenTitle("Play")
        .sheet(isPresented: $showingJoin) { JoinMatchView() }
        .task { await checkForNearbyGames() }.refreshable { await checkForNearbyGames() }
    }

    private func checkForNearbyGames() async {
        guard let location = await locationProvider.currentLocationIfAuthorized(),
              let games = try? await SharedMatchController.fetchNearby(around: location) else { return }
        var knownIDs = Set(matches.map(\.id)); knownIDs.formUnion(americanos.map(\.id))
        nearbyGameCount = games.filter { game in
            switch game.content {
            case .match(let state): return !knownIDs.contains(state.id)
            case .americano(let session): return !knownIDs.contains(session.id)
            }
        }.count
    }
}

private struct NearbyGamesBanner: View {
    let count: Int
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.wave.2.fill").font(.title3)
            VStack(alignment: .leading, spacing: 2) { Text("Live games nearby!").font(.headline); Text("Tap to see who's playing and join in.").font(.caption).opacity(0.75) }
            Spacer(); Text("\(count)").font(.title3.bold().monospacedDigit())
        }.foregroundStyle(DesignSystem.appBackground).padding(16).frame(maxWidth: .infinity).background(DesignSystem.accentLime).clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

private struct OngoingMatchCard: View {
    let state: MatchState
    var body: some View {
        let snap = state.snapshot
        PremiumCard(background: DesignSystem.padelBlueDeep) {
            VStack(alignment: .leading, spacing: 10) {
                HStack { StatusPill(text: "In progress", color: DesignSystem.accentLime); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.7)) }
                Text("\(state.teamA.displayName) vs \(state.teamB.displayName)").font(.headline).foregroundStyle(.white).lineLimit(2)
                Text("\(snap.setsWonA)–\(snap.setsWonB)").font(.system(size: 30, weight: .heavy).monospacedDigit()).foregroundStyle(DesignSystem.accentLime)
                Label("Continue Match", systemImage: "play.fill").font(.subheadline.weight(.semibold)).foregroundStyle(DesignSystem.padelBlue)
            }
        }
    }
}

struct MatchRowView: View {
    let state: MatchState
    var showsChevron = true
    var body: some View { ScoreRowCard(state: state, showsChevron: showsChevron) }
}

struct TeamAvatarStack: View {
    let players: [Player]
    var body: some View { HStack(spacing: -10) { ForEach(players.prefix(4)) { PlayerAvatar(player: $0, size: 28) } } }
}

#Preview { NavigationStack { PlayHomeView() }.modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true) }
