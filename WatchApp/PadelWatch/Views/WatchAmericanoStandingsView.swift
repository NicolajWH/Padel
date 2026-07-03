import SwiftUI
import PadelKit

struct WatchAmericanoStandingsView: View {
    let session: AmericanoSession

    var body: some View {
        List {
            ForEach(Array(session.standings.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Text("\(index + 1)").font(.caption).foregroundStyle(index == 0 ? .yellow : .secondary)
                    Text(entry.player.name).font(.system(size: 13)).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer()
                    Text("\(entry.totalPoints)").font(.headline)
                }
            }
        }
        .navigationTitle("Standings")
    }
}

#Preview {
    let players = (1...4).map { Player(name: "P\($0)") }
    let session = AmericanoSession(players: players, settings: .standard(playerCount: 4), rounds: [])
    return NavigationStack { WatchAmericanoStandingsView(session: session) }
}
