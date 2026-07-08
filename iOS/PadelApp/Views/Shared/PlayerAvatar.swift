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
            // A top-down sheen gives the flat circle a little dimension while
            // keeping the solid base behind the white initials for contrast.
            Circle().fill(
                LinearGradient(
                    colors: [.white.opacity(0.28), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            Text(player.initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().strokeBorder(.white.opacity(0.28), lineWidth: max(1, size * 0.035))
        )
        .shadow(color: base.opacity(0.3), radius: size * 0.14, y: size * 0.05)
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
