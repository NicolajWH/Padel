import SwiftUI
import PadelKit

/// Shown when a Mix session is over: the final standings plus a single "End
/// Match" action. This is the only place standings surface during a session —
/// they're intentionally hidden while points are being counted — so the wearer
/// gets a clean summary and a clear way to close things out.
struct WatchAmericanoResultView: View {
    let session: AmericanoSession
    /// Close the session and return to the home menu.
    var onEnd: () -> Void = {}

    var body: some View {
        let standings = session.standings
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(PadelTheme.lime)
                    .font(.title2)
                    .shadow(color: PadelTheme.lime.opacity(0.6), radius: 8)

                if let winner = standings.first {
                    Text("\(winner.player.name) Wins")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }

                Text("Final Standings")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(spacing: 4) {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { index, entry in
                        StandingRow(rank: index + 1, entry: entry, isLeader: index == 0)
                    }
                }

                Button(action: onEnd) {
                    Label("End Match", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .tint(PadelTheme.lime)
                .padding(.top, 4)
            }
            .padding()
        }
    }
}

private struct StandingRow: View {
    let rank: Int
    let entry: AmericanoStandingsEntry
    let isLeader: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("\(rank)")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundStyle(rankColor)
                .frame(width: 16)
            Circle()
                .fill(Color(hex: entry.player.displayColorHex))
                .frame(width: 8, height: 8)
            Text(entry.player.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            Text("\(entry.totalPoints)")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(isLeader ? PadelTheme.lime : .primary)
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "E5B80B")
        case 2: return Color(hex: "9EA7AD")
        case 3: return Color(hex: "B87333")
        default: return .secondary
        }
    }
}

#Preview {
    let players = (1...4).map { Player(name: "P\($0)") }
    let settings = AmericanoSettings.standard(playerCount: 4)
    let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
    let session = AmericanoSession(players: players, settings: settings, rounds: rounds)
    return WatchAmericanoResultView(session: session)
}
