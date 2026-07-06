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

#Preview {
    WatchOfflineBadge()
}
