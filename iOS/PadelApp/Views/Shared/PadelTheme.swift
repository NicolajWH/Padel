import SwiftUI
import UIKit
import PadelKit

/// The app's design language: a private padel-club palette of deep emerald
/// greens with a champagne-gold accent. Dark "scoreboard" surfaces glow with
/// the champagne gold; tinted controls on light surfaces use the system
/// AccentColor (a deep emerald in light mode, champagne gold in dark) so the
/// brand reads correctly against every background.
enum PadelTheme {
    // MARK: Brand palette
    //
    // The original token names (`courtBlue`, `lime`, `sky`) are kept because
    // they're referenced across the whole app; they now point at the emerald
    // + champagne-gold identity. The semantic aliases below (`emerald`,
    // `gold`, `sage`) are the preferred names for new code.

    /// Primary emerald — the "court" green, used for hero surfaces.
    static let courtBlue = Color(hex: "1E5C45")
    /// Deep pine, the mid-tone of the scoreboard gradients.
    static let courtDeep = Color(hex: "123D2E")
    /// Onyx-green, the darkest surface and the dark-text colour on gold fills.
    static let night = Color(hex: "0A2119")
    /// Champagne gold — the prestige accent that glows on the dark surfaces.
    static let lime = Color(hex: "E3C36B")
    /// A soft sage highlight for glows and secondary accents on dark surfaces.
    static let sky = Color(hex: "6FB49A")

    // Preferred semantic aliases for new code.
    static var emerald: Color { courtBlue }
    static var pine: Color { courtDeep }
    static var onyx: Color { night }
    static var gold: Color { lime }
    static var sage: Color { sky }

    /// Team colours — a cool sapphire against a warm clay so the two sides
    /// stay maximally distinguishable (and colour-blind friendly) on top of
    /// the green surfaces.
    static let teamA = Color(hex: "5B93D6")
    static let teamB = Color(hex: "E08A5B")

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

    /// Champagne-gold call-to-action gradient used on the brightest nudges —
    /// a lit top edge falling to the core gold so it reads like brushed metal.
    static var limeGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F0DA92"), lime, Color(hex: "CBA84E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// A branded backdrop for the scroll-based home screens: the system grouped
/// background lit by a soft emerald wash and a warm champagne highlight at the
/// top, so every tab shares the same club-lounge atmosphere instead of a flat
/// grey.
struct PadelBackground: View {
    var body: some View {
        Color(uiColor: .systemGroupedBackground)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [PadelTheme.emerald.opacity(0.14), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)
            }
            .overlay(alignment: .topTrailing) {
                RadialGradient(
                    colors: [PadelTheme.gold.opacity(0.14), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
                .frame(height: 300)
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

extension PadelTheme {
    /// Dresses the navigation bars in a serif display face, giving the whole
    /// app an editorial, members-club feel. Called once at launch. Only the
    /// title fonts are overridden — the backgrounds keep the system's default
    /// blur so per-screen `.toolbarBackground` (e.g. the scoreboard) still
    /// wins.
    static func configureAppearance() {
        func serif(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        }

        let largeTitle: [NSAttributedString.Key: Any] = [.font: serif(34, weight: .bold)]
        let inlineTitle: [NSAttributedString.Key: Any] = [.font: serif(17, weight: .semibold)]

        let opaque = UINavigationBarAppearance()
        opaque.configureWithDefaultBackground()
        opaque.largeTitleTextAttributes = largeTitle
        opaque.titleTextAttributes = inlineTitle

        let transparent = UINavigationBarAppearance()
        transparent.configureWithTransparentBackground()
        transparent.largeTitleTextAttributes = largeTitle
        transparent.titleTextAttributes = inlineTitle

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = opaque
        bar.compactAppearance = opaque
        bar.scrollEdgeAppearance = transparent
    }
}

/// Card container used across the dashboard-style screens. A hairline that is
/// brighter at the top edge gives each card a subtle "lit from above" bevel,
/// for a more crafted, tactile feel than a flat stroke.
struct PadelCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: PadelTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PadelTheme.Radius.medium, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.primary.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
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
                .font(.system(.title3, design: .serif).weight(.bold))
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
