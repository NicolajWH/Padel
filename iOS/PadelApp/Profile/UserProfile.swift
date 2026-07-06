import Foundation
import UIKit
import PadelKit

/// The local player's profile. The name lives in UserDefaults under the same
/// "profileName" key that Settings edits through @AppStorage.
enum UserProfile {
    static let nameKey = "profileName"

    static var name: String {
        (UserDefaults.standard.string(forKey: nameKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The owner name carried by the iPhone's device name, when there is
    /// one. On iOS 16+ UIDevice reports the generic "iPhone" unless the app
    /// has Apple's user-assigned-device-name entitlement, so this is often
    /// nil on real devices — the Settings text field's .name content type
    /// remains as the AutoFill fallback.
    static var deviceNameSuggestion: String? {
        DeviceOwnerName.parse(from: UIDevice.current.name)
    }

    /// Fills the profile name from the iPhone's name once, at launch, so the
    /// user never has to type it in Settings themselves.
    static func autofillNameIfNeeded() {
        guard name.isEmpty, let suggestion = deviceNameSuggestion else { return }
        UserDefaults.standard.set(suggestion, forKey: nameKey)
    }
}
