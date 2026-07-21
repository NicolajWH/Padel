import SwiftUI

struct AppCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
    }
}

extension View {
    func appCard() -> some View { modifier(AppCard()) }
    func padelCard() -> some View { appCard() }
}
