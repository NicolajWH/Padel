import SwiftUI
import UIKit
import PadelKit

struct PremiumImageCard: View {
    let assetName: String
    let category: LocalizedStringKey?
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    var icon: String? = nil
    var cta: LocalizedStringKey? = nil
    var showsArrow = false
    var height: CGFloat = 300
    var showsImageGradient = true
    var showsTitle = true
    var topContentInset: CGFloat = 0

    var body: some View {
        let hasImage = UIImage(named: assetName) != nil
        GeometryReader { geometry in
        ZStack(alignment: .bottomLeading) {
            DesignSystem.surfaceElevated
            if hasImage {
                Image(assetName)
                    .resizable().scaledToFill()
                    .saturation(1.0)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                if showsImageGradient {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.58),
                            .init(color: DesignSystem.appBackground.opacity(0.2), location: 0.72),
                            .init(color: DesignSystem.appBackground.opacity(0.9), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    if let category {
                        Text(category).font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(DesignSystem.accentLime)
                    }
                    Spacer()
                    if let icon { Image(systemName: icon).foregroundStyle(DesignSystem.accentLime) }
                }
                .padding(.top, topContentInset)
                if !hasImage {
                    Label(assetName, systemImage: "photo")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignSystem.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(DesignSystem.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer(minLength: 24)
                if showsTitle {
                    Text(title).font(.system(.title2, design: .default, weight: .bold)).foregroundStyle(.white)
                }
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.82)).fixedSize(horizontal: false, vertical: true)
                }
                if cta != nil || showsArrow {
                    HStack {
                        if let cta {
                            Text(cta).font(.subheadline.weight(.bold)).foregroundStyle(DesignSystem.appBackground)
                                .padding(.horizontal, 16).frame(minHeight: 44).background(DesignSystem.accentLime)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        Spacer()
                        if showsArrow { Image(systemName: "arrow.up.right").font(.subheadline.bold()).foregroundStyle(DesignSystem.accentLime) }
                    }
                }
            }
            .padding(20)
        }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.hero, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: DesignSystem.Radius.hero, style: .continuous).strokeBorder(.white.opacity(0.13)) }
        .shadow(color: .black.opacity(0.38), radius: 20, y: 9)
        .accessibilityElement(children: .combine)
    }
}

struct ScoreRowCard: View {
    let state: MatchState
    var date: Date? = nil
    var showsChevron = true
    var isFinished: Bool? = nil

    var body: some View {
        let snapshot = state.snapshot
        let winner = snapshot.winner
        PremiumCard(cornerRadius: DesignSystem.Radius.compact, padding: 12) {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("Runder")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignSystem.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.7)
                    Spacer()
                    Text((isFinished ?? state.isFinished) ? "Afsluttet" : "I gang")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle((isFinished ?? state.isFinished) ? DesignSystem.textSecondary : DesignSystem.accentLime)
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(DesignSystem.textSecondary)
                            .accessibilityHidden(true)
                    }
                }

                teamLine(
                    initials: state.teamA.players.map(\.initials).joined(separator: "/"),
                    scores: roundScores(for: .teamA),
                    color: PadelTheme.teamA,
                    won: winner == .teamA
                )
                teamLine(
                    initials: state.teamB.players.map(\.initials).joined(separator: "/"),
                    scores: roundScores(for: .teamB),
                    color: PadelTheme.teamB,
                    won: winner == .teamB
                )

                if let date {
                    HStack {
                        Text(date, style: .relative)
                        Spacer()
                        Text("Padel")
                    }
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.teamA.displayName), \(scoreDescription(for: .teamA)), \(state.teamB.displayName), \(scoreDescription(for: .teamB))")
    }

    /// A match is normally one set. History therefore presents the games in
    /// each played set (for example 6–4), rather than the unhelpful 1–0 set tally.
    private func roundScores(for side: TeamSide) -> [Int] {
        let snapshot = state.snapshot
        var scores = snapshot.completedSets.map { side == .teamA ? $0.teamAGames : $0.teamBGames }
        if !snapshot.isMatchOver {
            scores.append(side == .teamA ? snapshot.currentSetGamesA : snapshot.currentSetGamesB)
        }
        return scores.isEmpty ? [0] : scores
    }

    private func scoreDescription(for side: TeamSide) -> String {
        roundScores(for: side).map(String.init).joined(separator: ", ")
    }

    private func teamLine(initials: String, scores: [Int], color: Color, won: Bool) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(color)
                .frame(width: 4, height: 28)
                .accessibilityHidden(true)
            Text(initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 5) {
                ForEach(Array(scores.enumerated()), id: \.offset) { _, score in
                    Text("\(score)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(won ? color : DesignSystem.textPrimary)
                        .frame(minWidth: 30, minHeight: 30)
                        .background(color.opacity(won ? 0.2 : 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentTransition(.numericText())
                }
            }
        }
    }
}
