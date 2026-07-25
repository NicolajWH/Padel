import Foundation
import HealthKit

struct HealthWorkoutSummary: Sendable {
    let workoutCount: Int
    let duration: TimeInterval
    let activeCalories: Double
    let averageHeartRate: Double?
    let maximumHeartRate: Double?

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0 min"
    }

    var formattedCalories: String {
        activeCalories.formatted(.number.precision(.fractionLength(0))) + " kcal"
    }

    var formattedAverageHeartRate: String { formattedHeartRate(averageHeartRate) }
    var formattedMaximumHeartRate: String { formattedHeartRate(maximumHeartRate) }

    private func formattedHeartRate(_ value: Double?) -> String {
        guard let value else { return String(localized: "No data", table: "Health") }
        return value.formatted(.number.precision(.fractionLength(0))) + " bpm"
    }
}

@MainActor
final class HealthWorkoutSummaryStore: ObservableObject {
    @Published private(set) var summary: HealthWorkoutSummary?
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    private let healthStore = HKHealthStore()

    func load() async {
        guard HKHealthStore.isHealthDataAvailable(), !isLoading else { return }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        let types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: types)
            let calendar = Calendar.current
            let end = Date()
            let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
            let workouts = try await tennisWorkouts(from: start, to: end)

            var calories = 0.0
            var weightedHeartRate = 0.0
            var heartRateDuration = 0.0
            var maximumHeartRate: Double?
            let bpm = HKUnit.count().unitDivided(by: .minute())

            for workout in workouts {
                calories += workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                // A workout remains useful even when heart-rate access was not
                // granted (or an individual sample is temporarily unavailable).
                // Do not discard the complete summary because an optional
                // metric could not be read.
                let statistics = try? await heartRateStatistics(for: workout)
                if let average = statistics?.averageQuantity()?.doubleValue(for: bpm) {
                    weightedHeartRate += average * workout.duration
                    heartRateDuration += workout.duration
                }
                if let maximum = statistics?.maximumQuantity()?.doubleValue(for: bpm) {
                    maximumHeartRate = max(maximumHeartRate ?? maximum, maximum)
                }
            }

            summary = HealthWorkoutSummary(
                workoutCount: workouts.count,
                duration: workouts.reduce(0) { $0 + $1.duration },
                activeCalories: calories,
                averageHeartRate: heartRateDuration > 0 ? weightedHeartRate / heartRateDuration : nil,
                maximumHeartRate: maximumHeartRate
            )
        } catch {
            summary = nil
            loadFailed = true
        }
    }

    private func tennisWorkouts(from start: Date, to end: Date) async throws -> [HKWorkout] {
        let date = HKQuery.predicateForSamples(withStart: start, end: end)
        let activity = HKQuery.predicateForWorkouts(with: .tennis)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [date, activity])

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples as? [HKWorkout] ?? []) }
            }
            healthStore.execute(query)
        }
    }

    private func heartRateStatistics(for workout: HKWorkout) async throws -> HKStatistics? {
        guard let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKStatistics?, Error>) in
            let query = HKStatisticsQuery(
                quantityType: heartRate,
                quantitySamplePredicate: HKQuery.predicateForObjects(from: workout),
                options: [.discreteAverage, .discreteMax]
            ) { _, statistics, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: statistics) }
            }
            healthStore.execute(query)
        }
    }
}
