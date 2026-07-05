import SwiftUI
import UIKit
import SwiftData
import PadelKit

struct PlayHomeView: View {
    @Query(sort: \MatchRecord.createdAt, order: .reverse) private var matches: [MatchRecord]
    @Query private var americanos: [AmericanoRecord]
    @State private var showingJoin = false
    @StateObject private var locationProvider = LocationProvider()
    @State private var nearbyGameCount = 0

    private var ongoingMatch: MatchRecord? {
        matches.first { !$0.isFinished }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if nearbyGameCount > 0 {
                    Button {
                        showingJoin = true
                    } label: {
                        NearbyGamesBanner(count: nearbyGameCount)
                    }
                    .buttonStyle(.plain)
                }

                if let ongoingMatch, let state = ongoingMatch.state {
                    NavigationLink {
                        LiveMatchView(record: ongoingMatch, initialState: state)
                    } label: {
                        OngoingMatchCard(state: state)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    NavigationLink {
                        NewMatchSetupView()
                    } label: {
                        ActionCard(
                            title: "New Match",
                            systemImage: "plus.circle.fill",
                            prominent: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingJoin = true
                    } label: {
                        ActionCard(
                            title: "Join Match",
                            systemImage: "person.2.wave.2.fill",
                            prominent: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("Score a padel match with real scoring rules — deuce or golden point, sets and tiebreaks. Share it live with everyone on court and on Apple Watch.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                if !matches.isEmpty {
                    Text("Recent")
                        .font(.title3.bold())
                        .padding(.top, 8)

                    ForEach(matches.prefix(5)) { record in
                        if let state = record.state {
                            NavigationLink {
                                record.isFinished
                                    ? AnyView(MatchSummaryView(state: state))
                                    : AnyView(LiveMatchView(record: record, initialState: state))
                            } label: {
                                MatchRowView(state: state)
                                    .padelCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Play")
        .sheet(isPresented: $showingJoin) {
            JoinMatchView()
        }
        .task {
            await checkForNearbyGames()
        }
        .refreshable {
            await checkForNearbyGames()
        }
    }

    /// Quietly looks for shared games at the user's location when the tab
    /// appears — never prompts for permission, and hides games we already
    /// joined. This is the "you're at the court, want in?" nudge.
    private func checkForNearbyGames() async {
        guard let location = await locationProvider.currentLocationIfAuthorized(),
              let games = try? await SharedMatchController.fetchNearby(around: location) else {
            return
        }
        var knownIDs = Set(matches.map(\.id))
        knownIDs.formUnion(americanos.map(\.id))
        nearbyGameCount = games.filter { game in
            switch game.content {
            case .match(let state): return !knownIDs.contains(state.id)
            case .americano(let session): return !knownIDs.contains(session.id)
            }
        }.count
    }
}

/// Lime nudge shown when there are shared games at the user's location
/// that they haven't joined yet.
private struct NearbyGamesBanner: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.title3)
                .foregroundStyle(PadelTheme.night)
            VStack(alignment: .leading, spacing: 2) {
                Text("Live games nearby!")
                    .font(.headline)
                    .foregroundStyle(PadelTheme.night)
                Text("Tap to see who's playing and join in.")
                    .font(.caption)
                    .foregroundStyle(PadelTheme.night.opacity(0.75))
            }
            Spacer()
            Text("\(count)")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(PadelTheme.night)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PadelTheme.lime)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: PadelTheme.lime.opacity(0.4), radius: 8, y: 4)
    }
}

/// Hero card for the match currently in progress.
private struct OngoingMatchCard: View {
    let state: MatchState

    var body: some View {
        let snap = state.snapshot
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusPill(text: "In progress", color: PadelTheme.lime)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text("\(state.teamA.displayName) vs \(state.teamB.displayName)")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Sets \(snap.setsWonA)-\(snap.setsWonB)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(PadelTheme.lime)
                Text(snap.isTiebreak ? "\(snap.tiebreakPointsA)-\(snap.tiebreakPointsB)" : "\(snap.gamePointLabelA)-\(snap.gamePointLabelB)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Label("Continue Match", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PadelTheme.lime)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PadelTheme.courtGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: PadelTheme.courtDeep.opacity(0.35), radius: 10, y: 6)
    }
}

/// Square-ish tappable card for primary actions on home screens.
struct ActionCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let prominent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(prominent ? PadelTheme.lime : Color.accentColor)
            Text(title)
                .font(.headline)
                .foregroundStyle(prominent ? .white : .primary)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(
            Group {
                if prominent {
                    AnyShapeStyle(PadelTheme.courtGradient)
                } else {
                    AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

struct MatchRowView: View {
    let state: MatchState

    var body: some View {
        let snap = state.snapshot
        HStack(spacing: 12) {
            TeamAvatarStack(players: state.teamA.players + state.teamB.players)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(state.teamA.displayName) vs \(state.teamB.displayName)")
                    .font(.subheadline).bold()
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Sets \(snap.setsWonA)-\(snap.setsWonB)")
                    if !state.isFinished {
                        StatusPill(text: "In progress", color: .orange)
                    } else if let winner = snap.winner {
                        Text("\(state.team(winner).displayName) won")
                            .foregroundStyle(.green)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

/// Overlapping avatar bubbles for up to four players.
struct TeamAvatarStack: View {
    let players: [Player]

    var body: some View {
        HStack(spacing: -10) {
            ForEach(players.prefix(4)) { player in
                PlayerAvatar(player: player, size: 28)
                    .overlay(Circle().strokeBorder(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 2))
            }
        }
    }
}

#Preview {
    NavigationStack { PlayHomeView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
