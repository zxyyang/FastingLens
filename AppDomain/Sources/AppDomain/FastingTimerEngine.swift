import Foundation

public struct FastingTimerState: Sendable {
    public var phase: FastingPhase
    public var phaseStartedAt: Date
    public var phaseEndsAt: Date
    public var progressValue: Double

    public init(
        phase: FastingPhase,
        phaseStartedAt: Date,
        phaseEndsAt: Date,
        progressValue: Double
    ) {
        self.phase = phase
        self.phaseStartedAt = phaseStartedAt
        self.phaseEndsAt = phaseEndsAt
        self.progressValue = progressValue
    }
}

public enum FastingTimerEngine {
    public static func currentState(
        plan: FastingPlan,
        cycleStartedAt: Date,
        now: Date
    ) -> FastingTimerState {
        let fastingDuration = TimeInterval(plan.fastingHours * 3600)
        let eatingDuration = TimeInterval(plan.eatingHours * 3600)
        let totalDuration = fastingDuration + eatingDuration

        let elapsed = max(now.timeIntervalSince(cycleStartedAt), 0)
        let offset = elapsed.truncatingRemainder(dividingBy: totalDuration)

        if offset < fastingDuration {
            let phaseStartedAt = now.addingTimeInterval(-offset)
            let phaseEndsAt = phaseStartedAt.addingTimeInterval(fastingDuration)
            return FastingTimerState(
                phase: .fasting,
                phaseStartedAt: phaseStartedAt,
                phaseEndsAt: phaseEndsAt,
                progressValue: offset / fastingDuration
            )
        } else {
            let eatingOffset = offset - fastingDuration
            let phaseStartedAt = now.addingTimeInterval(-eatingOffset)
            let phaseEndsAt = phaseStartedAt.addingTimeInterval(eatingDuration)
            return FastingTimerState(
                phase: .eating,
                phaseStartedAt: phaseStartedAt,
                phaseEndsAt: phaseEndsAt,
                progressValue: eatingOffset / eatingDuration
            )
        }
    }
}
