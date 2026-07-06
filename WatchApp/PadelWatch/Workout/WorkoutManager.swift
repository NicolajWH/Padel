import Foundation
import HealthKit

/// Runs an Apple Watch workout session alongside scoring, so a padel match
/// records heart rate, active calories, and time in the Health app — and so
/// watchOS keeps the app alive in the foreground for the whole match instead
/// of suspending it mid-set.
///
/// Everything degrades gracefully: if HealthKit is unavailable or the user
/// declines authorization, scoring works exactly as before and no workout is
/// recorded. All failures are swallowed into `isRunning == false`.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()

    @Published private(set) var isRunning = false
    /// Latest heart rate in beats per minute, 0 until the first sample arrives.
    @Published private(set) var heartRate: Double = 0
    /// Total active energy burned this session, in kilocalories.
    @Published private(set) var activeCalories: Double = 0

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var isStarting = false

    /// Starts a workout if none is running. Safe to call from every scoring
    /// screen's onAppear — repeat calls while running or starting are no-ops.
    func startIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable(), !isRunning, !isStarting else { return }
        isStarting = true
        Task {
            await start()
            isStarting = false
        }
    }

    /// Ends the running workout and saves it to Health. No-op when idle.
    func end() {
        guard isRunning else { return }
        session?.end()
    }

    private func start() async {
        let share: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]
        let read: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]
        do {
            try await store.requestAuthorization(toShare: share, read: read)
        } catch {
            return
        }

        // HealthKit has no padel activity type, so matches are recorded as
        // tennis — the closest match for rings and calorie estimation.
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .tennis
        configuration.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            isRunning = true
        } catch {
            reset()
        }
    }

    private func finishAndSave() async {
        guard let builder else {
            reset()
            return
        }
        do {
            try await builder.endCollection(at: Date())
            try await builder.finishWorkout()
        } catch {
            // Authorization was revoked mid-session or saving failed — the
            // workout is lost but scoring is unaffected.
        }
        reset()
    }

    private func reset() {
        session = nil
        builder = nil
        isRunning = false
        heartRate = 0
        activeCalories = 0
    }

    private func consume(statistics: HKStatistics?) {
        guard let statistics else { return }
        switch statistics.quantityType {
        case HKQuantityType(.heartRate):
            let unit = HKUnit.count().unitDivided(by: .minute())
            heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? heartRate
        case HKQuantityType(.activeEnergyBurned):
            activeCalories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? activeCalories
        default:
            break
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended else { return }
        Task { @MainActor in
            await self.finishAndSave()
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.reset()
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)
            Task { @MainActor in
                self.consume(statistics: statistics)
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
