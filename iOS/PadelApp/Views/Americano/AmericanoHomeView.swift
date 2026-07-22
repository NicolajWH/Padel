import SwiftUI
import SwiftData
import PadelKit

struct AmericanoHomeView: View {
    @Query(sort: \AmericanoRecord.createdAt, order: .reverse) private var sessions: [AmericanoRecord]
    private var ongoing: AmericanoRecord? { sessions.first { !$0.isFinished && $0.session?.rounds.isEmpty == false } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let ongoing, let session = ongoing.session {
                    NavigationLink { AmericanoRoundScoringView(record: ongoing, session: session) } label: { OngoingAmericanoCard(session: session) }.buttonStyle(PremiumPressStyle())
                }
                NavigationLink { AmericanoSetupView(initialFormat: .americano) } label: {
                    PremiumImageCard(assetName: "AmericanoHero", category: "AMERICANO", title: "Ny Americano", subtitle: "Makkere roterer hver runde, så du spiller med og mod alle i gruppen.", icon: "arrow.triangle.2.circlepath", showsArrow: true, height: 228)
                }.buttonStyle(PremiumPressStyle())
                NavigationLink { AmericanoSetupView(initialFormat: .mexicano) } label: {
                    PremiumImageCard(assetName: "MexicanoHero", category: "MEXICANO", title: "Ny Mexicano", subtitle: "Hver runde baseres på stillingen, så du møder spillere på dit niveau.", icon: "chart.line.uptrend.xyaxis", showsArrow: true, height: 228)
                }.buttonStyle(PremiumPressStyle())
                FormatExplainer()
                if !sessions.isEmpty {
                    SectionHeader(title: "Seneste", systemImage: "clock.arrow.circlepath")
                    ForEach(sessions.prefix(5)) { record in
                        if let session = record.session {
                            NavigationLink { AmericanoStandingsView(record: record, session: session) } label: { AmericanoRowView(session: session) }.buttonStyle(PremiumPressStyle())
                        }
                    }
                }
            }.padding()
        }.contentMargins(.bottom, DesignSystem.Spacing.large, for: .scrollContent).padelBackground().screenTitle("Mix")
    }
}

private struct FormatExplainer: View {
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 15) {
                row(icon: "arrow.triangle.2.circlepath", title: "Americano", text: "Skiftende makkere gør spillet socialt og varieret.")
                Divider().overlay(DesignSystem.separatorSubtle)
                row(icon: "chart.line.uptrend.xyaxis", title: "Mexicano", text: "Den aktuelle stilling giver stadig mere jævnbyrdige kampe.")
            }
        }
    }
    private func row(icon: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(DesignSystem.padelBlue).frame(width: 32, height: 32).background(DesignSystem.padelBlue.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.subheadline.bold()).foregroundStyle(DesignSystem.textPrimary); Text(text).font(.footnote).foregroundStyle(DesignSystem.textSecondary) }
        }
    }
}

private struct OngoingAmericanoCard: View {
    let session: AmericanoSession
    var body: some View {
        PremiumCard(background: DesignSystem.padelBlueDeep) {
            VStack(alignment: .leading, spacing: 10) {
                HStack { StatusPill(text: "I gang", color: DesignSystem.accentLime); Text(session.settings.format.displayName).font(.caption).foregroundStyle(.white.opacity(0.7)); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.7)) }
                Text(session.name).font(.headline).foregroundStyle(.white)
                Label("Runde \(session.currentRoundIndex + 1) af \(session.plannedRoundCount)", systemImage: "arrow.triangle.2.circlepath").font(.subheadline.bold()).foregroundStyle(DesignSystem.accentLime)
            }
        }
    }
}

#Preview { NavigationStack { AmericanoHomeView() }.modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true) }
