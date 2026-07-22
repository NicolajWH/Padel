import SwiftUI
import UIKit
import PadelKit

struct PremiumImageCard: View {
    let assetName: String
    let category: LocalizedStringKey
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var icon: String? = nil
    var cta: LocalizedStringKey? = nil
    var showsArrow = false
    var height: CGFloat = 300

    var body: some View {
        let hasImage = UIImage(named: assetName) != nil
        ZStack(alignment: .bottomLeading) {
            DesignSystem.surfaceElevated
            if hasImage {
                Image(assetName)
                    .resizable().scaledToFill()
                    .contrast(1.06).saturation(0.92)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                LinearGradient(colors: [.clear, DesignSystem.appBackground.opacity(0.55), DesignSystem.appBackground.opacity(0.97)], startPoint: .top, endPoint: .bottom)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(category).font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(DesignSystem.accentLime)
                    Spacer()
                    if let icon { Image(systemName: icon).foregroundStyle(DesignSystem.accentLime) }
                }
                if !hasImage {
                    Label(assetName, systemImage: "photo")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignSystem.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(DesignSystem.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer(minLength: 24)
                Text(title).font(.system(.title2, design: .default, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.82)).fixedSize(horizontal: false, vertical: true)
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
        .frame(maxWidth: .infinity).frame(height: height)
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

    var body: some View {
        let snapshot = state.snapshot
        let winner = snapshot.winner
        PremiumCard(cornerRadius: DesignSystem.Radius.compact, padding: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 5) {
                    teamLine(initials: state.teamA.players.map(\.initials).joined(separator: "/"), score: snapshot.setsWonA, won: winner == .teamA)
                    teamLine(initials: state.teamB.players.map(\.initials).joined(separator: "/"), score: snapshot.setsWonB, won: winner == .teamB)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(state.isFinished ? "Afsluttet" : "I gang").font(.caption.weight(.semibold)).foregroundStyle(state.isFinished ? DesignSystem.textSecondary : DesignSystem.accentLime)
                    if let date { Text(date, style: .relative).font(.caption2).foregroundStyle(DesignSystem.textSecondary) }
                    Text("Padel").font(.caption2).foregroundStyle(DesignSystem.padelBlue)
                }
                if showsChevron { Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(DesignSystem.textSecondary).accessibilityHidden(true) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.teamA.displayName), \(snapshot.setsWonA), \(state.teamB.displayName), \(snapshot.setsWonB)")
    }

    private func teamLine(initials: String, score: Int, won: Bool) -> some View {
        HStack(spacing: 8) {
            Text(initials).font(.subheadline.weight(.semibold)).foregroundStyle(won ? DesignSystem.accentLime : DesignSystem.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            Text("\(score)").font(.title3.bold().monospacedDigit()).foregroundStyle(won ? DesignSystem.accentLime : DesignSystem.textPrimary).contentTransition(.numericText())
        }
    }
}
