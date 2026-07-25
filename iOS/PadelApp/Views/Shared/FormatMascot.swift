import SwiftUI
import PadelKit

extension AmericanoFormat {
    /// Uses the same artwork as the corresponding format button on Mix.
    var mascotAssetName: String {
        switch self {
        case .americano: return "AmericanoHero"
        case .mexicano: return "MexicanoHero"
        }
    }
}

/// A thumbnail of the format artwork used on Mix. Keeping one shared mapping
/// ensures setup and format selection always use the same visual identity.
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
