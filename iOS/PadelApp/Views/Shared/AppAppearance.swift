import SwiftUI

enum AppAppearance: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appAppearance"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
