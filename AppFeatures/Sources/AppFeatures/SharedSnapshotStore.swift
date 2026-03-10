import Foundation

public enum SharedSnapshotStore {
    public static let appGroupID = "group.com.flipos.fastinglens"
    private static let snapshotKey = "shared.watch.snapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public static func save(snapshot: WatchSnapshotState) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    public static func loadSnapshot() -> WatchSnapshotState? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WatchSnapshotState.self, from: data)
    }

    public static func initialSnapshot(now: Date = .now) -> WatchSnapshotState {
        WatchSnapshotState(
            generatedAt: now,
            phase: .fasting,
            phaseEndsAt: now.addingTimeInterval(16 * 3600),
            todayCalories: 0,
            recentMeals: []
        )
    }
}
