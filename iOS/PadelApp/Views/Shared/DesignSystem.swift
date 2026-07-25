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
        static let compact: CGFloat = 13
        static let control: CGFloat = 15
        static let card: CGFloat = 16
        static let hero: CGFloat = 21
    }

    // Semantic tokens keep the visual language in one place and leave room for
    // a more extensive light appearance without changing individual screens.
    // Every surface is adaptive. Previously these were fixed night colours, so
    // selecting Light in Settings only changed system controls and left the app
    // itself dark. The light palette is inspired by a blue padel court with the
    // tennis-ball yellow retained as the high-energy accent.
    static let appBackground = Color(light: 0xF2F8FB, dark: 0x050A0E)
    static let backgroundElevated = Color(light: 0xE1F1F8, dark: 0x081119)
    static let surfacePrimary = Color(light: 0xFFFFFF, dark: 0x0C161E)
    static let surfaceElevated = Color(light: 0xD7EBF4, dark: 0x11202A)
    static let padelBlue = Color(light: 0x087EB7, dark: 0x238FC4)
    static let padelBlueLight = Color(light: 0x096D9D, dark: 0x54B7E3)
    static let padelBlueDeep = Color(light: 0x07577E, dark: 0x0C567D)
    static let accentLime = Color(light: 0xC9E900, dark: 0xDFFF3F)
    static let tabBarTint = Color(light: 0xC9E900, dark: 0xDFFF3F)
    static let textPrimary = Color(light: 0x092534, dark: 0xF7F8F9)
    static let textSecondary = Color(light: 0x496674, dark: 0xA1ACB5)
    static let borderSubtle = Color.primary.opacity(0.12)
    static let separatorSubtle = Color.primary.opacity(0.09)
    static let live = Color.orange

    // Compatibility aliases used by focused scoring views.
    static let heroGreen = padelBlue
    static let heroGreenDeep = padelBlueDeep
    static let heroHighlight = accentLime
    static var groupedBackground: Color { appBackground }
    static var cardBackground: Color { surfacePrimary }
}

private extension Color {
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}

enum PadelTheme {
    static let courtBlue = DesignSystem.padelBlue
    static let courtDeep = DesignSystem.padelBlueDeep
    static let night = DesignSystem.appBackground
    static let lime = DesignSystem.accentLime
    static let sky = DesignSystem.padelBlue
    static var emerald: Color { courtBlue }
    static var pine: Color { courtDeep }
    static var onyx: Color { night }
    static var gold: Color { lime }
    static var sage: Color { sky }
    static let teamA = DesignSystem.padelBlue
    static let teamB = Color(red: 0.95, green: 0.20, blue: 0.25)

    static func teamColor(_ side: TeamSide) -> Color { side == .teamA ? teamA : teamB }

    enum Radius {
        static let small = DesignSystem.Radius.compact
        static let medium = DesignSystem.Radius.control
        static let large = DesignSystem.Radius.hero
    }

    static var courtGradient: LinearGradient { LinearGradient(colors: [courtBlue, courtDeep], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var scoreboardGradient: LinearGradient { LinearGradient(colors: [courtDeep, night], startPoint: .top, endPoint: .bottom) }
    static var heroGradient: LinearGradient { LinearGradient(colors: [courtBlue.opacity(0.72), courtDeep], startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var limeGradient: LinearGradient { LinearGradient(colors: [lime.opacity(0.88), lime], startPoint: .topLeading, endPoint: .bottomTrailing) }
}

struct PadelBackground: View {
    var body: some View {
        LinearGradient(
            colors: [DesignSystem.backgroundElevated.opacity(0.8), DesignSystem.appBackground],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
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
            .foregroundStyle(DesignSystem.textPrimary)
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
                    .foregroundStyle(DesignSystem.padelBlue)
                    .accessibilityHidden(true)
            }
            Text(title).font(.title3.weight(.semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(DesignSystem.textPrimary)
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
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(color.opacity(0.16)).foregroundStyle(color).clipShape(Capsule())
    }
}

private struct ScreenTitleModifier: ViewModifier {
    let title: LocalizedStringKey
    func body(content: Content) -> some View {
        content.navigationTitle("").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .principal) { ScreenTitle(title: title) }
        }
    }
}

extension View {
    func screenTitle(_ title: LocalizedStringKey) -> some View { modifier(ScreenTitleModifier(title: title)) }
}
