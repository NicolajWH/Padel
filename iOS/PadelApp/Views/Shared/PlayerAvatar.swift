import SwiftUI
import PadelKit

struct CartoonAvatarView: View {
    let playerName: String
    var assetName: String? = nil
    var size: CGFloat = 40
    var accent: Color = DesignSystem.padelBlue

    private var initials: String {
        playerName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
    private var variantColor: Color {
        let colors = [DesignSystem.padelBlueDeep, Color(hex: "245E62"), Color(hex: "7A5526"), Color(hex: "315C43")]
        let stableValue = playerName.unicodeScalars.reduce(UInt(0)) { ($0 &* 31) &+ UInt($1.value) }
        return colors[Int(stableValue % UInt(colors.count))]
    }

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [variantColor.opacity(0.82), variantColor], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(.white.opacity(0.12)).frame(width: size * 0.48, height: size * 0.36).offset(x: -size * 0.14, y: -size * 0.16)
            Text(initials).font(.system(size: size * 0.34, weight: .bold, design: .rounded)).foregroundStyle(DesignSystem.accentLime)
            if let assetName { Image(assetName).resizable().scaledToFill() }
        }
        .frame(width: size, height: size).clipShape(Circle())
        .overlay(Circle().strokeBorder(accent.opacity(0.85), lineWidth: 1.5))
        .accessibilityElement(children: .ignore).accessibilityLabel(playerName)
    }
}

struct PlayerAvatar: View {
    let player: Player
    var size: CGFloat = 36
    /// Optional catalog name for an original, bundled cartoon avatar. Initials
    /// remain the offline fallback while those local assets are being prepared.
    var assetName: String? = nil
    var body: some View { CartoonAvatarView(playerName: player.name, assetName: assetName, size: size) }
}

struct PlayerRow: View {
    let player: Player
    var body: some View { HStack(spacing: 12) { PlayerAvatar(player: player, size: 32); Text(player.name) } }
}
