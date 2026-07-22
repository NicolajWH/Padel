import SwiftUI
import SwiftData
import PadelKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MatchRecord.createdAt, order: .reverse) private var matches: [MatchRecord]
    @Query(sort: \AmericanoRecord.createdAt, order: .reverse) private var americanos: [AmericanoRecord]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Kampe", systemImage: "list.number")
                if matches.isEmpty { EmptyHistoryCard(icon: "tennis.racket", text: "Ingen kampe endnu") }
                ForEach(matches) { record in
                    if let state = record.state {
                        NavigationLink { record.isFinished ? AnyView(MatchSummaryView(state: state)) : AnyView(LiveMatchView(record: record, initialState: state)) } label: { ScoreRowCard(state: state, date: record.createdAt) }
                            .buttonStyle(PremiumPressStyle())
                            .contextMenu { Button("Slet kamp", systemImage: "trash", role: .destructive) { modelContext.delete(record) } }
                    }
                }
                SectionHeader(title: "Americano-sessioner", systemImage: "person.3.fill").padding(.top, 8)
                if americanos.isEmpty { EmptyHistoryCard(icon: "arrow.triangle.2.circlepath", text: "Dine Americano- og Mexicano-sessioner vises her.") }
                ForEach(americanos) { record in
                    if let session = record.session {
                        NavigationLink { AmericanoStandingsView(record: record, session: session) } label: { AmericanoRowView(session: session) }
                            .buttonStyle(PremiumPressStyle())
                            .contextMenu { Button("Slet session", systemImage: "trash", role: .destructive) { modelContext.delete(record) } }
                    }
                }
            }.padding()
        }.contentMargins(.bottom, DesignSystem.Spacing.large, for: .scrollContent).padelBackground().screenTitle("Historik")
    }
}

private struct EmptyHistoryCard: View {
    let icon: String; let text: LocalizedStringKey
    var body: some View { PremiumCard { HStack(spacing: 12) { Image(systemName: icon).foregroundStyle(DesignSystem.padelBlue); Text(text).font(.subheadline).foregroundStyle(DesignSystem.textSecondary) } } }
}

struct AmericanoRowView: View {
    let session: AmericanoSession

    private var latestCompletedRound: AmericanoRound? {
        session.rounds.last(where: session.isRoundComplete)
    }

    var body: some View {
        PremiumCard(cornerRadius: DesignSystem.Radius.compact, padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: session.settings.format == .americano ? "arrow.triangle.2.circlepath" : "chart.line.uptrend.xyaxis").foregroundStyle(DesignSystem.padelBlueLight).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name).font(.subheadline.bold()).foregroundStyle(DesignSystem.textPrimary)
                        Text("\(session.players.count) spillere · \(session.plannedRoundCount) runder").font(.caption).foregroundStyle(DesignSystem.textSecondary)
                    }
                    Spacer()
                    if !session.isComplete { StatusPill(text: "I gang", color: DesignSystem.accentLime) }
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(DesignSystem.textSecondary)
                }
                if let round = latestCompletedRound {
                    Divider().overlay(DesignSystem.separatorSubtle)
                    Text("Senest afsluttede runde \(round.index + 1)").font(.caption2).foregroundStyle(DesignSystem.textSecondary)
                    ForEach(round.matchups) { matchup in
                        let score = matchup.score(target: session.settings.pointsPerRound)
                        VStack(spacing: 3) {
                            teamScore(matchup.teamA, points: score.a, won: score.a > score.b)
                            teamScore(matchup.teamB, points: score.b, won: score.b > score.a)
                        }
                    }
                }
            }
        }.accessibilityElement(children: .combine)
    }

    private func teamScore(_ team: Team, points: Int, won: Bool) -> some View {
        HStack {
            Text(team.players.map(\.initials).joined(separator: " / "))
                .font(.caption.weight(won ? .semibold : .regular))
            Spacer()
            Text("\(points)")
                .font(.subheadline.bold().monospacedDigit())
        }
        .foregroundStyle(won ? DesignSystem.accentLime : DesignSystem.textPrimary)
    }
}

#Preview { NavigationStack { HistoryView() }.modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true) }
