import Foundation

public enum FastingPhaseState: String, Codable, Sendable {
    case fasting
    case eating
    case paused
}

public struct RecentMealSummary: Codable, Sendable {
    public var mealType: String
    public var totalCalories: Int
    public var note: String?

    public init(mealType: String, totalCalories: Int, note: String? = nil) {
        self.mealType = mealType
        self.totalCalories = totalCalories
        self.note = note
    }
}

public struct WatchSnapshotState: Codable, Sendable {
    public var generatedAt: Date
    public var phase: FastingPhaseState
    public var phaseEndsAt: Date
    public var todayCalories: Int
    public var recentMeals: [RecentMealSummary]
    public var dailyCalorieGoal: Int
    public var remainingCalories: Int
    public var todayActiveCalories: Int
    public var estimatedTDEE: Int
    public var eatingWindowStart: Date
    public var eatingWindowEnd: Date

    public init(
        generatedAt: Date,
        phase: FastingPhaseState,
        phaseEndsAt: Date,
        todayCalories: Int,
        recentMeals: [RecentMealSummary],
        dailyCalorieGoal: Int = 1600,
        remainingCalories: Int = 1600,
        todayActiveCalories: Int = 0,
        estimatedTDEE: Int = 0,
        eatingWindowStart: Date = .now,
        eatingWindowEnd: Date = .now
    ) {
        self.generatedAt = generatedAt
        self.phase = phase
        self.phaseEndsAt = phaseEndsAt
        self.todayCalories = todayCalories
        self.recentMeals = recentMeals
        self.dailyCalorieGoal = dailyCalorieGoal
        self.remainingCalories = remainingCalories
        self.todayActiveCalories = todayActiveCalories
        self.estimatedTDEE = estimatedTDEE
        self.eatingWindowStart = eatingWindowStart
        self.eatingWindowEnd = eatingWindowEnd
    }
}

public struct DashboardCardModel: Sendable {
    public var phaseTitle: String
    public var accentLabel: String
    public var remainingText: String
    public var caloriesText: String
    public var progressValue: Double

    public init(
        phaseTitle: String,
        accentLabel: String,
        remainingText: String,
        caloriesText: String,
        progressValue: Double
    ) {
        self.phaseTitle = phaseTitle
        self.accentLabel = accentLabel
        self.remainingText = remainingText
        self.caloriesText = caloriesText
        self.progressValue = progressValue
    }
}

public enum DashboardViewModel {
    public static func makeCard(
        snapshot: WatchSnapshotState,
        now: Date = Date(),
        fastingGoalHours: Int = 16
    ) -> DashboardCardModel {
        let remainingSeconds = max(snapshot.phaseEndsAt.timeIntervalSince(now), 0)
        let hours = Int(remainingSeconds) / 3600
        let minutes = (Int(remainingSeconds) % 3600) / 60
        let remainingText = String(format: "%02d小时 %02d分", hours, minutes)
        let progressBase = Double(fastingGoalHours * 3600)
        let consumed = progressBase - remainingSeconds
        let progressValue = min(max(consumed / progressBase, 0), 1)

        return DashboardCardModel(
            phaseTitle: snapshot.phase == .fasting ? "断食中" : "进食窗口",
            accentLabel: snapshot.phase == .fasting ? "保持燃脂节奏" : "记下最后一口",
            remainingText: remainingText,
            caloriesText: "\(snapshot.todayCalories) 千卡",
            progressValue: progressValue
        )
    }
}
