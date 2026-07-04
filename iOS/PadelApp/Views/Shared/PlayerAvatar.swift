import SwiftUI
import PadelKit

struct PlayerAvatar: View {
    let player: Player
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(Color(hex: player.colorHex))
            .frame(width: size, height: size)
            .overlay(
                Text(player.initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            )
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
