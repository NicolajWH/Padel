import SwiftUI
import PadelKit

enum DesignSystem {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 16
        static let card: CGFloat = 22
    }

    static let heroGreen = Color(red: 0.07, green: 0.28, blue: 0.20)
    static let heroGreenDeep = Color(red: 0.035, green: 0.16, blue: 0.12)
    static let heroHighlight = Color(red: 0.55, green: 0.90, blue: 0.67)
    static let live = Color.orange

    static var groupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var cardBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }
}

/// Compatibility palette for focused scoring screens. New general UI should
/// prefer semantic colors and `Color.accentColor`.
enum PadelTheme {
    static let courtBlue = DesignSystem.heroGreen
    static let courtDeep = DesignSystem.heroGreenDeep
    static let night = DesignSystem.heroGreenDeep
    static let lime = DesignSystem.heroHighlight
    static let sky = Color(red: 0.44, green: 0.71, blue: 0.60)
    static var emerald: Color { courtBlue }
    static var pine: Color { courtDeep }
    static var onyx: Color { night }
    static var gold: Color { lime }
    static var sage: Color { sky }
    static let teamA = Color(red: 0.36, green: 0.58, blue: 0.84)
    static let teamB = Color(red: 0.88, green: 0.54, blue: 0.36)

    static func teamColor(_ side: TeamSide) -> Color { side == .teamA ? teamA : teamB }

    enum Radius {
        static let small: CGFloat = 14
        static let medium = DesignSystem.Radius.control
        static let large = DesignSystem.Radius.card
    }

    static var courtGradient: LinearGradient {
        LinearGradient(colors: [courtBlue, courtDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var scoreboardGradient: LinearGradient {
        LinearGradient(colors: [courtDeep, night], startPoint: .top, endPoint: .bottom)
    }
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [courtBlue, courtDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var limeGradient: LinearGradient {
        LinearGradient(colors: [Color.accentColor.opacity(0.82), Color.accentColor], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct PadelBackground: View {
    var body: some View {
        DesignSystem.groupedBackground.ignoresSafeArea()
    }
}

extension View {
    func padelBackground() -> some View { background(PadelBackground()) }
}

struct ScreenTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(.title2, design: .serif, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            Text(title).font(.title3.weight(.semibold))
            Spacer(minLength: 0)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct StatusPill: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(text).font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.16))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

private struct ScreenTitleModifier: ViewModifier {
    let title: LocalizedStringKey

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { ScreenTitle(title: title) }
            }
    }
}

extension View {
    func screenTitle(_ title: LocalizedStringKey) -> some View {
        modifier(ScreenTitleModifier(title: title))
    }
}
