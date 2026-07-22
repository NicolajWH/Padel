import SwiftUI

struct AppCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.75)
            }
            .shadow(color: DesignSystem.heroGreenDeep.opacity(0.08), radius: 18, y: 8)
    }
}

extension View {
    func appCard() -> some View { modifier(AppCard()) }
    func padelCard() -> some View { appCard() }
}
