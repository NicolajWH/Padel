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
                SectionHeader(title: "Matches", systemImage: "list.number")
                if matches.isEmpty { EmptyHistoryCard(icon: "tennis.racket", text: "No matches yet") }
                ForEach(matches) { record in
                    if let state = record.state {
                        NavigationLink { record.isFinished ? AnyView(MatchSummaryView(state: state)) : AnyView(LiveMatchView(record: record, initialState: state)) } label: { ScoreRowCard(state: state, date: record.createdAt) }
                            .buttonStyle(PremiumPressStyle())
                            .contextMenu { Button("Delete Match", systemImage: "trash", role: .destructive) { modelContext.delete(record) } }
                    }
                }
                SectionHeader(title: "Americano Sessions", systemImage: "person.3.fill").padding(.top, 12)
                if americanos.isEmpty { EmptyHistoryCard(icon: "arrow.triangle.2.circlepath", text: "Your Americano and Mexicano sessions will appear here.") }
                ForEach(americanos) { record in
                    if let session = record.session {
                        NavigationLink { AmericanoStandingsView(record: record, session: session) } label: { AmericanoRowView(session: session) }
                            .buttonStyle(PremiumPressStyle())
                            .contextMenu { Button("Delete Session", systemImage: "trash", role: .destructive) { modelContext.delete(record) } }
                    }
                }
            }.padding()
        }.padelBackground().screenTitle("History")
    }
}

private struct EmptyHistoryCard: View {
    let icon: String; let text: LocalizedStringKey
    var body: some View { PremiumCard { HStack(spacing: 12) { Image(systemName: icon).foregroundStyle(DesignSystem.padelBlue); Text(text).font(.subheadline).foregroundStyle(DesignSystem.textSecondary) } } }
}

struct AmericanoRowView: View {
    let session: AmericanoSession
    var body: some View {
        PremiumCard(cornerRadius: DesignSystem.Radius.compact, padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: session.settings.format == .americano ? "arrow.triangle.2.circlepath" : "chart.line.uptrend.xyaxis").foregroundStyle(DesignSystem.padelBlue).frame(width: 34, height: 34).background(DesignSystem.padelBlue.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 4) { Text(session.name).font(.subheadline.bold()).foregroundStyle(DesignSystem.textPrimary); Text("\(session.players.count) players · \(session.plannedRoundCount) rounds").font(.caption).foregroundStyle(DesignSystem.textSecondary) }
                Spacer()
                if session.isComplete { Image(systemName: "checkmark.circle.fill").foregroundStyle(DesignSystem.accentLime) } else { StatusPill(text: "In progress", color: DesignSystem.accentLime) }
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(DesignSystem.textSecondary)
            }
        }.accessibilityElement(children: .combine)
    }
}

#Preview { NavigationStack { HistoryView() }.modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true) }
