import SwiftUI

/// Watch-side mirror of the iOS design language: deep emerald greens with a
/// champagne-gold accent.
enum PadelTheme {
    static let courtBlue = Color(hex: "1E5C45")
    static let courtDeep = Color(hex: "123D2E")
    static let lime = Color(hex: "E3C36B")
    static let teamA = Color(hex: "5B93D6")
    static let teamB = Color(hex: "E08A5B")
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
