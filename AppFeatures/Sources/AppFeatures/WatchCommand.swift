import Foundation

public enum WatchCommandAction: String, Codable, Sendable {
    case startFasting
    case openEatingWindow
    case logQuickMeal
}

public struct WatchCommand: Codable, Sendable {
    public var action: WatchCommandAction
    public var calories: Int?
    public var createdAt: Date

    public init(action: WatchCommandAction, calories: Int? = nil, createdAt: Date = .now) {
        self.action = action
        self.calories = calories
        self.createdAt = createdAt
    }
}
