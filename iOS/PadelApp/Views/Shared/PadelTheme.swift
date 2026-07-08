import SwiftUI
import UIKit
import PadelKit

/// The app's design language: padel-court blues with a padel-ball lime accent.
/// Dark "scoreboard" surfaces use the bright lime; tinted controls on light
/// surfaces use the system AccentColor (a darker lime) for contrast.
enum PadelTheme {
    // MARK: Brand palette
    static let courtBlue = Color(hex: "1B6CA8")
    static let courtDeep = Color(hex: "0C2B4E")
    static let night = Color(hex: "071A30")
    static let lime = Color(hex: "C6ED3F")
    /// A brighter sky tone used for glows and secondary accents on the
    /// dark scoreboard surfaces.
    static let sky = Color(hex: "4DA3FF")

    static let teamA = Color(hex: "4DA3FF")
    static let teamB = Color(hex: "FF7A59")

    static func teamColor(_ side: TeamSide) -> Color {
        side == .teamA ? teamA : teamB
    }

    // MARK: Shape tokens — one rounding scale across the whole app.
    enum Radius {
        static let small: CGFloat = 14
        static let medium: CGFloat = 20
        static let large: CGFloat = 24
    }

    // MARK: Gradients
    static var courtGradient: LinearGradient {
        LinearGradient(colors: [courtBlue, courtDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var scoreboardGradient: LinearGradient {
        LinearGradient(colors: [courtDeep, night], startPoint: .top, endPoint: .bottom)
    }

    /// A punchier hero gradient for the primary "in progress" cards, with a
    /// touch of sky at the top-leading edge so it reads as lit from above.
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [courtBlue, courtDeep, night],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Lime call-to-action gradient used on the brightest nudges.
    static var limeGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "D6F65A"), lime],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// A branded backdrop for the scroll-based home screens: the system grouped
/// background lit by a soft court-blue glow at the top, so every tab shares
/// the same atmosphere instead of a flat grey.
struct PadelBackground: View {
    var body: some View {
        Color(uiColor: .systemGroupedBackground)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [PadelTheme.courtBlue.opacity(0.16), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
            }
            .ignoresSafeArea()
    }
}

extension View {
    /// Applies the shared branded home-screen background.
    func padelBackground() -> some View {
        background(PadelBackground())
    }
}

/// Card container used across the dashboard-style screens.
struct PadelCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: PadelTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PadelTheme.Radius.medium, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

extension View {
    func padelCard() -> some View {
        modifier(PadelCard())
    }
}

/// A titled section heading for the scroll-based screens, optionally led by a
/// tinted glyph — the consistent replacement for ad-hoc bold `Text` headers.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }
            Text(title)
                .font(.title3.weight(.bold))
            Spacer(minLength: 0)
        }
    }
}

/// Small capsule status tag, e.g. "In progress" / "Finished", led by a filled
/// dot so its state reads at a glance.
struct StatusPill: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.18))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}
