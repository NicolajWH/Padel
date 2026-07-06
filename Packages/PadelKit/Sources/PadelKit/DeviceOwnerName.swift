import Foundation

/// Extracts the owner's name from a device name so the app can prefill the
/// user's profile name — "Nicolaj's iPhone" (English), "Nicolajs iPhone"
/// (Danish genitive) and "iPhone (Nicolaj)" all yield "Nicolaj".
///
/// Returns nil for generic names like "iPhone" or "iPad Pro", which is all
/// UIDevice reports on iOS 16+ unless the app has Apple's
/// user-assigned-device-name entitlement.
public enum DeviceOwnerName {
    private static let deviceWords = ["iPhone", "iPad", "iPod touch"]

    public static func parse(from deviceName: String) -> String? {
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // "iPhone (Nicolaj)" — the personalized style some locales use.
        for device in deviceWords {
            if trimmed.range(of: device + " (", options: [.caseInsensitive, .anchored]) != nil,
               trimmed.hasSuffix(")") {
                let inner = trimmed.dropFirst(device.count + 2).dropLast()
                let candidate = String(inner).trimmingCharacters(in: .whitespacesAndNewlines)
                if isName(candidate) { return candidate }
            }
        }

        // "Nicolaj's iPhone" / "Mads' iPad" — apostrophe genitive keeps the
        // name intact. Checked before the bare-suffix pass so names that end
        // in "s" ("Mads'") aren't shortened below.
        for genitive in ["'s", "’s", "'", "’"] {
            for device in deviceWords {
                if let candidate = dropping(suffix: genitive + " " + device, from: trimmed),
                   isName(candidate) {
                    return candidate
                }
            }
        }

        // "Nicolajs iPhone" — Danish/Norwegian genitive adds a bare "s"
        // directly to the name, so drop it again.
        for device in deviceWords {
            if let candidate = dropping(suffix: " " + device, from: trimmed) {
                if candidate.count > 2, candidate.lowercased().hasSuffix("s") {
                    let withoutGenitive = String(candidate.dropLast())
                    if isName(withoutGenitive) { return withoutGenitive }
                }
                if isName(candidate) { return candidate }
            }
        }

        // Generic device names ("iPhone", "iPad Pro", "iPhone 15") carry no
        // owner name.
        for device in deviceWords {
            if trimmed.localizedCaseInsensitiveCompare(device) == .orderedSame { return nil }
            if trimmed.range(of: device + " ", options: [.caseInsensitive, .anchored]) != nil { return nil }
        }

        // A fully custom device name ("Nicolaj") is its own best guess.
        return isName(trimmed) ? trimmed : nil
    }

    private static func dropping(suffix: String, from name: String) -> String? {
        guard name.count > suffix.count,
              name.range(of: suffix, options: [.caseInsensitive, .anchored, .backwards]) != nil
        else { return nil }
        return String(name.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isName(_ candidate: String) -> Bool {
        !candidate.isEmpty && candidate.rangeOfCharacter(from: .letters) != nil
    }
}
