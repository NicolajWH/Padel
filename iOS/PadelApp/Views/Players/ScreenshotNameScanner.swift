import Foundation
import Vision
import UIKit

/// On-device OCR that pulls likely player names out of a screenshot — e.g. a
/// screenshot of a friends list in another app such as MATCHi, which has no
/// public API to read friends from.
///
/// Uses Apple's Vision framework, so it runs entirely on the phone with no
/// network, no account, and no photo-library permission (the picker that
/// supplies the image runs out of process). Recognized lines are filtered down
/// to things that look like full names and handed to the user to review and
/// edit before anything is saved.
enum ScreenshotNameScanner {

    /// OCRs a single image and returns the candidate names in top-to-bottom order.
    static func names(from imageData: Data) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
                    continuation.resume(returning: [])
                    return
                }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                // Names shouldn't be "corrected" into dictionary words.
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["da-DK", "en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    // Vision's origin is bottom-left, so a larger y sits higher
                    // on screen — sort descending to read the list top to bottom.
                    let lines = observations
                        .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                        .compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: filterNames(lines))
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// UI chrome that shows up in a MATCHi-style screenshot but isn't a name.
    private static let blocklist: Set<String> = [
        "venner", "hjem", "spil", "bookinger", "profil", "niveauer",
        "padel", "tilføj", "invitér venner", "inviter venner",
        "friends", "invite friends", "levels", "add", "settings"
    ]

    private static func filterNames(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in lines {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isLikelyName(name) else { continue }
            if seen.insert(name.lowercased()).inserted {
                result.append(name)
            }
        }
        return result
    }

    /// Heuristic: a full name is a couple of capitalised, letters-only words.
    /// This drops times ("16.56"), avatar initials ("CH"), menu dots ("…"),
    /// numbers and single-word UI labels, keeping "Kim Christian Hove Thomsen".
    private static func isLikelyName(_ s: String) -> Bool {
        guard s.count >= 3, s.count <= 40 else { return false }
        if blocklist.contains(s.lowercased()) { return false }

        let words = s.split(separator: " ")
        guard words.count >= 2 else { return false }

        let allowed = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'."))
        if s.unicodeScalars.contains(where: { !allowed.contains($0) }) { return false }

        // Every word starts with an uppercase letter (rules out "Invitér venner").
        for word in words {
            guard let first = word.first, first.isUppercase else { return false }
        }
        return true
    }
}
