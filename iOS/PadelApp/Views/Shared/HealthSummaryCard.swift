import SwiftUI

/// A compact, always-visible overview of the padel workouts recorded by Apple
/// Watch. Loading happens automatically; the user never has to reveal the data
/// with an extra button.
struct HealthSummaryCard: View {
    @ObservedObject var store: HealthWorkoutSummaryStore

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeader(title: "Padel Health", systemImage: "heart.fill")
                    Spacer()
                    Text("Last 30 days")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.textSecondary)
                }

                if store.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading health data…")
                            .foregroundStyle(DesignSystem.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72)
                } else if let summary = store.summary {
                    HStack(spacing: 8) {
                        metric(value: summary.formattedDuration, label: "Time", icon: "clock.fill")
                        metric(value: summary.formattedCalories, label: "Energy", icon: "flame.fill")
                    }
                    HStack(spacing: 8) {
                        metric(value: summary.formattedAverageHeartRate, label: "Avg. pulse", icon: "waveform.path.ecg")
                        metric(value: summary.workoutCount.formatted(), label: "Workouts", icon: "figure.tennis")
                    }
                } else {
                    ContentUnavailableView(
                        "Health data unavailable",
                        systemImage: "heart.slash",
                        description: Text(store.loadFailed ? "Check Padel's Health access in iPhone Settings." : "Health data is not available on this iPhone.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
        }
        .task { await store.load() }
    }

    private func metric(value: String, label: LocalizedStringKey, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DesignSystem.padelBlueLight)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(DesignSystem.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(12)
        .background(DesignSystem.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.compact, style: .continuous))
    }
}
