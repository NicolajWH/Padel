import SwiftUI
import PadelKit

struct PlayerAvatar: View {
    let player: Player
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [DesignSystem.heroGreen, DesignSystem.heroGreenDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Text(player.initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(DesignSystem.heroHighlight)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: DesignSystem.heroGreenDeep.opacity(0.28), radius: 5, y: 3)
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
