import SwiftUI
import PadelKit

struct PlayerAvatar: View {
    let player: Player
    var size: CGFloat = 36

    /// Derived from the player's name so the same person is the same colour
    /// on every screen — see `Player.displayColorHex`.
    private var base: Color { Color(hex: player.displayColorHex) }

    var body: some View {
        ZStack {
            Circle().fill(base)
            Text(player.initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().strokeBorder(Color(uiColor: .separator).opacity(0.45), lineWidth: 1)
        )
        .shadow(color: Color.primary.opacity(0.08), radius: 2, y: 1)
    }
}

struct PlayerRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 12) {
            PlayerAvatar(player: player, size: 32)
            Text(player.name)
        }
    }
}
