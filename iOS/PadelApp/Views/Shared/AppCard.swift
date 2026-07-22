import SwiftUI

struct PremiumCard<Content: View>: View {
    var cornerRadius: CGFloat = DesignSystem.Radius.card
    var padding: CGFloat = DesignSystem.Spacing.large
    var background = DesignSystem.surfacePrimary
    var isPressable = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.borderSubtle, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.34), radius: 18, y: 8)
    }
}

struct AppCard: ViewModifier {
    func body(content: Content) -> some View { PremiumCard { content } }
}

extension View {
    func appCard() -> some View { modifier(AppCard()) }
    func padelCard() -> some View { appCard() }
}

struct PremiumPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.987 : 1)
            .animation(.spring(duration: 0.22, bounce: 0.08), value: configuration.isPressed)
    }
}
