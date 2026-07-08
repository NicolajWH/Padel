import SwiftUI

/// Small warning shown on the scoring screens while the paired iPhone is out
/// of range. Scoring keeps working locally and the score syncs automatically
/// once the phone is back in reach — but until then the other players won't
/// see live updates, which is exactly what this badge tells the wearer.
struct WatchOfflineBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 9, weight: .semibold))
            Text("Offline")
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.orange.opacity(0.18)))
    }
}

/// Live heart rate from the running workout session — the visible proof that a
/// match (regular or Mix) is recording to Health while it's being scored.
struct WatchHeartRateBadge: View {
    let bpm: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "heart.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
            Text("\(Int(bpm))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }
}

#Preview {
    WatchOfflineBadge()
}
