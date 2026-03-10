import Foundation

enum RuntimePhase: String, Codable, Sendable {
    case fasting
    case eating
}

struct RuntimeTimerState: Sendable {
    var phase: RuntimePhase
    var phaseStartedAt: Date
    var phaseEndsAt: Date
    var progressValue: Double
}

enum FastingTimerEngine {
    static func currentState(
        fastingHours: Int,
        eatingHours: Int,
        cycleStartedAt: Date,
        now: Date
    ) -> RuntimeTimerState {
        let fastingDuration = TimeInterval(fastingHours * 3600)
        let eatingDuration = TimeInterval(eatingHours * 3600)
        let cycleDuration = fastingDuration + eatingDuration
        let elapsed = max(now.timeIntervalSince(cycleStartedAt), 0)
        let offset = elapsed.truncatingRemainder(dividingBy: cycleDuration)

        if offset < fastingDuration {
            let phaseStartedAt = now.addingTimeInterval(-offset)
            let phaseEndsAt = phaseStartedAt.addingTimeInterval(fastingDuration)
            return RuntimeTimerState(
                phase: .fasting,
                phaseStartedAt: phaseStartedAt,
                phaseEndsAt: phaseEndsAt,
                progressValue: offset / fastingDuration
            )
        }

        let eatingOffset = offset - fastingDuration
        let phaseStartedAt = now.addingTimeInterval(-eatingOffset)
        let phaseEndsAt = phaseStartedAt.addingTimeInterval(eatingDuration)
        return RuntimeTimerState(
            phase: .eating,
            phaseStartedAt: phaseStartedAt,
            phaseEndsAt: phaseEndsAt,
            progressValue: eatingOffset / eatingDuration
        )
    }
}
