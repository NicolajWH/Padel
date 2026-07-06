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
                        FormatCard(
                            title: "New Americano",
                            format: .americano,
                            prominent: true
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AmericanoSetupView(initialFormat: .mexicano)
                    } label: {
                        FormatCard(
                            title: "New Mexicano",
                            format: .mexicano,
                            prominent: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                FormatExplainer()

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
            FormatMascot(format: format, size: 38)
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

/// Tappable format card on the Americano home screen, fronted by its playful
/// mascot — a cowboy for Americano, a charro for Mexicano.
private struct FormatCard: View {
    let title: LocalizedStringKey
    let format: AmericanoFormat
    let prominent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormatMascot(format: format, size: 52)
            Text(title)
                .font(.headline)
                .foregroundStyle(prominent ? .white : .primary)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(
            prominent
                ? AnyShapeStyle(PadelTheme.courtGradient)
                : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
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
        .background(PadelTheme.courtGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: PadelTheme.courtDeep.opacity(0.35), radius: 10, y: 6)
    }
}

#Preview {
    NavigationStack { AmericanoHomeView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
