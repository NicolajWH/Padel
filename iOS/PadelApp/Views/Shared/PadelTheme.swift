import SwiftUI
import UIKit
import PadelKit

/// The app's design language: padel-court blues with a padel-ball lime accent.
/// Dark "scoreboard" surfaces use the bright lime; tinted controls on light
/// surfaces use the system AccentColor (a darker lime) for contrast.
enum PadelTheme {
    static let courtBlue = Color(hex: "1B6CA8")
    static let courtDeep = Color(hex: "0C2B4E")
    static let night = Color(hex: "071A30")
    static let lime = Color(hex: "C6ED3F")

    static let teamA = Color(hex: "4DA3FF")
    static let teamB = Color(hex: "FF7A59")

    static func teamColor(_ side: TeamSide) -> Color {
        side == .teamA ? teamA : teamB
    }

    static var courtGradient: LinearGradient {
        LinearGradient(colors: [courtBlue, courtDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var scoreboardGradient: LinearGradient {
        LinearGradient(colors: [courtDeep, night], startPoint: .top, endPoint: .bottom)
    }
}

/// Card container used across the dashboard-style screens.
struct PadelCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

extension View {
    func padelCard() -> some View {
        modifier(PadelCard())
    }
}

/// Small capsule status tag, e.g. "In progress" / "Finished".
struct StatusPill: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
