import Foundation

public enum FastingPhase: String, Codable, Sendable {
    case fasting
    case eating
    case paused
}

public enum MealSource: String, Codable, Sendable {
    case aiRecognition
    case manualEntry
    case watchQuickLog
}

public struct UserProfile: Codable, Identifiable, Sendable {
    public var id: UUID
    public var displayName: String
    public var timezoneIdentifier: String
    public var fastingGoalHours: Int
    public var eatingWindowHours: Int

    public init(
        id: UUID = UUID(),
        displayName: String,
        timezoneIdentifier: String,
        fastingGoalHours: Int = 16,
        eatingWindowHours: Int = 8
    ) {
        self.id = id
        self.displayName = displayName
        self.timezoneIdentifier = timezoneIdentifier
        self.fastingGoalHours = fastingGoalHours
        self.eatingWindowHours = eatingWindowHours
    }
}

public struct FastingPlan: Codable, Identifiable, Sendable {
    public var id: UUID
    public var fastingHours: Int
    public var eatingHours: Int
    public var defaultStartHour: Int
    public var defaultStartMinute: Int
    public var remindersEnabled: Bool

    public init(
        id: UUID = UUID(),
        fastingHours: Int = 16,
        eatingHours: Int = 8,
        defaultStartHour: Int,
        defaultStartMinute: Int,
        remindersEnabled: Bool = true
    ) {
        self.id = id
        self.fastingHours = fastingHours
        self.eatingHours = eatingHours
        self.defaultStartHour = defaultStartHour
        self.defaultStartMinute = defaultStartMinute
        self.remindersEnabled = remindersEnabled
    }
}

public struct FastingSession: Codable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endsAt: Date
    public var phase: FastingPhase
    public var wasCompleted: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endsAt: Date,
        phase: FastingPhase,
        wasCompleted: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.phase = phase
        self.wasCompleted = wasCompleted
    }
}

public struct MealItem: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var portion: String
    public var estimatedCalories: Int

    public init(
        id: UUID = UUID(),
        name: String,
        portion: String,
        estimatedCalories: Int
    ) {
        self.id = id
        self.name = name
        self.portion = portion
        self.estimatedCalories = estimatedCalories
    }
}

public struct MealPhoto: Codable, Identifiable, Sendable {
    public var id: UUID
    public var localPath: String
    public var thumbnailPath: String?
    public var capturedAt: Date

    public init(
        id: UUID = UUID(),
        localPath: String,
        thumbnailPath: String? = nil,
        capturedAt: Date
    ) {
        self.id = id
        self.localPath = localPath
        self.thumbnailPath = thumbnailPath
        self.capturedAt = capturedAt
    }
}

public struct MealRecord: Codable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var mealType: String
    public var totalCalories: Int
    public var notes: String?
    public var source: MealSource
    public var items: [MealItem]
    public var photo: MealPhoto?

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        mealType: String,
        totalCalories: Int,
        notes: String? = nil,
        source: MealSource,
        items: [MealItem],
        photo: MealPhoto? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mealType = mealType
        self.totalCalories = totalCalories
        self.notes = notes
        self.source = source
        self.items = items
        self.photo = photo
    }
}

public struct RecognitionJob: Codable, Identifiable, Sendable {
    public enum Status: String, Codable, Sendable {
        case queued
        case running
        case succeeded
        case failed
    }

    public var id: UUID
    public var createdAt: Date
    public var providerName: String
    public var status: Status
    public var rawResponse: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        providerName: String,
        status: Status,
        rawResponse: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.providerName = providerName
        self.status = status
        self.rawResponse = rawResponse
    }
}

public struct ReminderRule: Codable, Identifiable, Sendable {
    public enum Trigger: String, Codable, Sendable {
        case eatingWindowStarts
        case eatingWindowEndsSoon
        case noMealLogged
    }

    public var id: UUID
    public var trigger: Trigger
    public var offsetMinutes: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        trigger: Trigger,
        offsetMinutes: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.trigger = trigger
        self.offsetMinutes = offsetMinutes
        self.isEnabled = isEnabled
    }
}

public struct WatchSnapshot: Codable, Sendable {
    public var generatedAt: Date
    public var phase: FastingPhase
    public var phaseEndsAt: Date
    public var todayCalories: Int
    public var recentMeals: [MealRecord]

    public init(
        generatedAt: Date,
        phase: FastingPhase,
        phaseEndsAt: Date,
        todayCalories: Int,
        recentMeals: [MealRecord]
    ) {
        self.generatedAt = generatedAt
        self.phase = phase
        self.phaseEndsAt = phaseEndsAt
        self.todayCalories = todayCalories
        self.recentMeals = recentMeals
    }
}
