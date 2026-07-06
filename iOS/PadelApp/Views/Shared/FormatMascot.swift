import SwiftUI
import PadelKit

/// Playful themed emoji for the two tournament formats: a cowboy 🤠 for
/// **Americano** and a taco 🌮 for **Mexicano**. Kept as a small reusable view
/// so the whole app shares one mapping and it's trivial to swap a glyph.
struct FormatMascot: View {
    let format: AmericanoFormat
    var size: CGFloat = 56

    private var emoji: String {
        switch format {
        case .americano: return "🤠"
        case .mexicano: return "🌮"
        }
    }

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.82))
            .frame(width: size, height: size)
            .minimumScaleFactor(0.5)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        FormatMascot(format: .americano, size: 120)
        FormatMascot(format: .mexicano, size: 120)
    }
    .padding()
}
