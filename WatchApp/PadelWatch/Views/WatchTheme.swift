import SwiftUI

/// Watch-side mirror of the iOS design language: padel-court blues with a
/// padel-ball lime accent.
enum PadelTheme {
    static let courtBlue = Color(hex: "1B6CA8")
    static let courtDeep = Color(hex: "0C2B4E")
    static let lime = Color(hex: "C6ED3F")
    static let teamA = Color(hex: "4DA3FF")
    static let teamB = Color(hex: "FF7A59")
}

extension Color {
    init(hex: String) {
        var hexValue = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexValue = hexValue.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
