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

                HStack(spacing: 12) {
                    NavigationLink {
                        AmericanoSetupView(initialFormat: .americano)
                    } label: {
                        FormatCard(title: "New Americano", format: .americano)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AmericanoSetupView(initialFormat: .mexicano)
                    } label: {
                        FormatCard(title: "New Mexicano", format: .mexicano)
                    }
                    .buttonStyle(.plain)
                }

                FormatExplainer()

                if !sessions.isEmpty {
                    SectionHeader(title: "Recent", systemImage: "clock.arrow.circlepath")
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
        .padelBackground()
        .screenTitle("Mix")
    }
}

/// Side-by-side intro to the two tournament formats, so the page explains
/// the choice instead of hiding Mexicano inside the setup form.
private struct FormatExplainer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            row(
                format: .americano,
                title: "Americano",
                text: "Partners rotate every round, so you play with — and against — everyone in the group."
            )
            Divider()
            row(
                format: .mexicano,
                title: "Mexicano",
                text: "Each round is drawn from the live standings, so you always face players at your level."
            )
        }
        .padelCard()
    }

    private func row(format: AmericanoFormat, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            FormatMascot(format: format, size: 46, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Tappable format card using the same ink-and-tennis visual language as
/// the rest of the app. Purposeful symbols distinguish the formats without
/// introducing a separate illustration style on the Mix tab.
private struct FormatCard: View {
    let title: LocalizedStringKey
    let format: AmericanoFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: format == .americano ? "arrow.triangle.2.circlepath" : "chart.line.uptrend.xyaxis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(PadelTheme.night)
                    .frame(width: 38, height: 38)
                    .background(PadelTheme.lime)
                    .clipShape(Circle())
                    .shadow(color: PadelTheme.lime.opacity(0.35), radius: 8, y: 4)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer(minLength: 4)

            Text(format.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PadelTheme.lime)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 164)
        .background(PadelTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: PadelTheme.night.opacity(0.25), radius: 14, y: 8)
    }
}

private struct OngoingAmericanoCard: View {
    let session: AmericanoSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusPill(text: "In progress", color: PadelTheme.lime)
                Text(session.settings.format.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
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
        .background(PadelTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: PadelTheme.Radius.large, style: .continuous))
        .shadow(color: PadelTheme.courtDeep.opacity(0.4), radius: 14, y: 8)
    }
}

#Preview {
    NavigationStack { AmericanoHomeView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
