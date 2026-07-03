import Foundation

public struct Player: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var colorHex: String

    public init(id: UUID = UUID(), name: String, colorHex: String = Player.randomColorHex()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    /// A friendly palette of accent colors used to tell players apart across the app and watch face.
    public static let palette: [String] = [
        "FF6B6B", "4ECDC4", "FFD166", "6A4C93",
        "1A936F", "3A86FF", "F72585", "FB8500",
        "8338EC", "06D6A0", "EF476F", "118AB2"
    ]

    public static func randomColorHex() -> String {
        palette.randomElement() ?? "3A86FF"
    }

    public var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }
}
