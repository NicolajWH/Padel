import SwiftUI
import UIKit
import PadelKit

struct AmericanoStandingsView: View {
    let record: AmericanoRecord
    let session: AmericanoSession
    @State private var shareImage: Image?

    var body: some View {
        List {
            Section {
                ForEach(Array(session.standings.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 12) {
                        RankBadge(rank: index + 1)
                        PlayerAvatar(player: entry.player, size: 32)
                        VStack(alignment: .leading) {
                            Text(entry.player.name)
                                .font(.subheadline.weight(index == 0 ? .bold : .regular))
                            Text("\(entry.roundsPlayed) rounds played")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if entry.player.id == AmericanoIdentity.playerID(for: session.id) {
                            StatusPill(text: "You", color: .accentColor)
                        }
                        Spacer()
                        Text("\(entry.totalPoints)")
                            .font(.system(.title3, design: .rounded)).bold()
                            .foregroundStyle(index == 0 ? Color.accentColor : .primary)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let shareImage {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview("\(session.name) standings", image: shareImage)
                    )
                }
            }
        }
        .onAppear { renderShareImage() }
        .onChange(of: session) { _, _ in renderShareImage() }
    }

    /// Renders the standings as an image so the organizer can drop the final
    /// (or live) table straight into the group chat.
    @MainActor
    private func renderShareImage() {
        let renderer = ImageRenderer(content: StandingsShareCard(session: session))
        renderer.scale = 3
        if let image = renderer.uiImage {
            shareImage = Image(uiImage: image)
        }
    }
}

/// Fixed-size standings snapshot used only for share exports.
private struct StandingsShareCard: View {
    let session: AmericanoSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.title2.bold())
                Text(session.createdAt.formatted(date: .abbreviated, time: .omitted) + (session.isComplete ? " · Final standings" : " · Live standings"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(Array(session.standings.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 10) {
                        RankBadge(rank: index + 1)
                        Text(entry.player.name)
                            .font(.subheadline.weight(index == 0 ? .bold : .regular))
                            .lineLimit(1)
                        Spacer()
                        Text("\(entry.totalPoints)")
                            .font(.system(.subheadline, design: .rounded).bold())
                    }
                }
            }

            Text("Scored with Padel")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 360)
        .background(Color(uiColor: .systemBackground))
    }
}

/// Rank number with medal colors for the top three.
struct RankBadge: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.system(.subheadline, design: .rounded).bold())
            .foregroundStyle(rank <= 3 ? .white : Color.secondary)
            .frame(width: 26, height: 26)
            .background(
                Circle().fill(badgeColor)
            )
    }

    private var badgeColor: Color {
        switch rank {
        case 1: return Color(hex: "E5B80B")
        case 2: return Color(hex: "9EA7AD")
        case 3: return Color(hex: "B87333")
        default: return Color(uiColor: .tertiarySystemFill)
        }
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
