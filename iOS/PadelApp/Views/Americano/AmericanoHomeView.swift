import SwiftUI
import UIKit
import SwiftData
import PadelKit

struct AmericanoHomeView: View {
    @Query(sort: \AmericanoRecord.createdAt, order: .reverse) private var sessions: [AmericanoRecord]

    private var ongoing: AmericanoRecord? {
        sessions.first { !$0.isFinished && $0.session?.rounds.isEmpty == false }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let ongoing, let session = ongoing.session {
                    NavigationLink {
                        AmericanoRoundScoringView(record: ongoing, session: session)
                    } label: {
                        OngoingAmericanoCard(session: session)
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    AmericanoSetupView()
                } label: {
                    ActionCard(
                        title: "New Americano",
                        systemImage: "person.3.fill",
                        prominent: true
                    )
                }
                .buttonStyle(.plain)

                Text("Set up a group, rotate partners automatically, and add up everyone's individual points — just like Americano padel, right on your Apple Watch.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                if !sessions.isEmpty {
                    Text("Recent")
                        .font(.title3.bold())
                        .padding(.top, 8)

                    ForEach(sessions.prefix(5)) { record in
                        if let session = record.session {
                            NavigationLink {
                                AmericanoStandingsView(record: record, session: session)
                            } label: {
                                AmericanoRowView(session: session)
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
        .navigationTitle("Americano")
    }
}

private struct OngoingAmericanoCard: View {
    let session: AmericanoSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusPill(text: "In progress", color: PadelTheme.lime)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(session.name)
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                Label("\(session.players.count)", systemImage: "person.3.fill")
                Label("\(session.currentRoundIndex + 1)/\(session.plannedRoundCount)", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PadelTheme.lime)

            if let leader = session.standings.first {
                Text("\(leader.player.name) leads")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PadelTheme.courtGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: PadelTheme.courtDeep.opacity(0.35), radius: 10, y: 6)
    }
}

#Preview {
    NavigationStack { AmericanoHomeView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
