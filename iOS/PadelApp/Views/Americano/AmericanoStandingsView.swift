import SwiftUI
import PadelKit

struct AmericanoStandingsView: View {
    let record: AmericanoRecord
    let session: AmericanoSession

    var body: some View {
        List {
            Section {
                ForEach(Array(session.standings.enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(index == 0 ? .yellow : .secondary)
                            .frame(width: 24)
                        PlayerAvatar(player: entry.player, size: 32)
                        VStack(alignment: .leading) {
                            Text(entry.player.name)
                            Text("\(entry.roundsPlayed) rounds played")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(entry.totalPoints)")
                            .font(.title3).bold()
                    }
                }
            } header: {
                Text("Standings")
            } footer: {
                if session.isComplete {
                    Text("Session complete.")
                } else {
                    Text("Updates live as rounds are played.")
                }
            }
        }
        .navigationTitle(session.name)
    }
}

#Preview {
    let players = (1...4).map { Player(name: "P\($0)") }
    let settings = AmericanoSettings.standard(playerCount: 4)
    let session = AmericanoSession(players: players, settings: settings, rounds: [])
    let record = AmericanoRecord.create(from: session)
    return NavigationStack {
        AmericanoStandingsView(record: record, session: session)
    }
}
