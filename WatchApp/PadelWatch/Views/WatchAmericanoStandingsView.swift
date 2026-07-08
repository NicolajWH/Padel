import SwiftUI
import PadelKit

struct WatchAmericanoStandingsView: View {
    let session: AmericanoSession

    var body: some View {
        List {
            ForEach(Array(session.standings.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(rankColor(index + 1))
                        .frame(width: 16)
                    Circle()
                        .fill(Color(hex: entry.player.displayColorHex))
                        .frame(width: 8, height: 8)
                    Text(entry.player.initials)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    Text("\(entry.totalPoints)")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(index == 0 ? PadelTheme.lime : .primary)
                }
            }
        }
        .navigationTitle("Standings")
    }

    private func rankColor(_ rank: Int) -> Color {
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
    let session = AmericanoSession(players: players, settings: .standard(playerCount: 4), rounds: [])
    return NavigationStack { WatchAmericanoStandingsView(session: session) }
}
