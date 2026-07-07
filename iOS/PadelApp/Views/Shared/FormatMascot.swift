import SwiftUI
import PadelKit

extension AmericanoFormat {
    /// Asset-catalog name of the illustrated poster mascot for this format.
    var mascotAssetName: String {
        switch self {
        case .americano: return "MascotAmericano"
        case .mexicano: return "MascotMexicano"
        }
    }
}

/// The poster mascot for a tournament format — an American theme for
/// **Americano**, a Mexican theme for **Mexicano** — shown as a rounded
/// square thumbnail. Keeps one shared mapping so every screen stays in sync.
struct FormatMascot: View {
    let format: AmericanoFormat
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 14

    var body: some View {
        Image(format.mascotAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        FormatMascot(format: .americano, size: 140, cornerRadius: 22)
        FormatMascot(format: .mexicano, size: 140, cornerRadius: 22)
    }
    .padding()
}
