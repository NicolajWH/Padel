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

    /// The colour used to draw this player everywhere in the app — their
    /// avatar circle, chips and standings badges. It is derived *from the
    /// name* rather than the stored `colorHex`, so the same person always
    /// reads as the same colour across the app: matches and Americanos
    /// re-create players with fresh UUIDs (identity across saved history is
    /// the normalized name, not the id), which used to give one person a
    /// different random colour on every screen.
    public var displayColorHex: String {
        let key = PlayerKey.normalize(name)
        guard !key.isEmpty else { return Player.palette[0] }
        // FNV-1a over the name. A *stable* hash on purpose — Swift's built-in
        // Hasher is seeded randomly per process, so it would repaint every
        // player on each launch.
        var hash: UInt64 = 1469598103934665603
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return Player.palette[Int(hash % UInt64(Player.palette.count))]
    }
}
