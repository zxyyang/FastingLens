import HealthKit
import Observation

@MainActor
@Observable
final class HealthKitManager {
    private let store = HKHealthStore()

    var isAuthorized = false
    var todaySteps: Int = 0
    var todayActiveCalories: Int = 0
    var todayBasalCalories: Int = 0

    var estimatedTDEE: Int {
        todayBasalCalories + todayActiveCalories
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func calorieDeficit(intake: Int) -> Int {
        estimatedTDEE - intake
    }

    func requestAuthorization() async {
        guard isAvailable else { return }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    func refreshTodayData() async {
        guard isAvailable, isAuthorized else { return }

        async let steps = queryTodaySum(for: .stepCount, unit: .count())
        async let active = queryTodaySum(for: .activeEnergyBurned, unit: .kilocalorie())
        async let basal = queryTodaySum(for: .basalEnergyBurned, unit: .kilocalorie())

        todaySteps = await Int(steps)
        todayActiveCalories = await Int(active)
        todayBasalCalories = await Int(basal)
    }

    private func queryTodaySum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let quantityType = HKQuantityType(identifier)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
