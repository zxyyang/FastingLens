import Foundation
import Testing
@testable import AppDomain

@Test
func decodesAIProviderConfig() throws {
    let json = """
    {
      "name": "My Food Vision",
      "isEnabled": true,
      "endpoint": "https://example.com/v1/chat/completions",
      "method": "POST",
      "headers": {
        "Authorization": "Bearer test",
        "Content-Type": "application/json"
      },
      "request": {
        "model": "food-vision-1",
        "temperature": 0.2,
        "systemPrompt": "You identify food and calories.",
        "userTemplate": "Analyze this meal image and return JSON.",
        "imageFieldMode": "base64"
      },
      "response": {
        "format": "json",
        "rootPath": "choices.0.message.content",
        "schemaVersion": "meal-v1"
      },
      "behavior": {
        "timeoutSeconds": 30,
        "requiresManualConfirmation": true,
        "minConfidenceToAutofill": 0.8,
        "saveRequestLog": true,
        "saveResponseLog": true
      }
    }
    """

    let data = try #require(json.data(using: .utf8))
    let config = try JSONDecoder().decode(AIProviderConfig.self, from: data)

    #expect(config.name == "My Food Vision")
    #expect(config.request.imageFieldMode == .base64)
    #expect(config.response.schemaVersion == "meal-v1")
    #expect(config.behavior.requiresManualConfirmation)
}

@Test
func computesFastingPhaseFromCycleStart() {
    let start = Date(timeIntervalSince1970: 0)
    let now = start.addingTimeInterval(5 * 3600 + 30 * 60)
    let plan = FastingPlan(defaultStartHour: 20, defaultStartMinute: 0)

    let state = FastingTimerEngine.currentState(plan: plan, cycleStartedAt: start, now: now)

    #expect(state.phase == .fasting)
    #expect(Int(state.phaseEndsAt.timeIntervalSince(start)) == 16 * 3600)
    #expect(state.progressValue > 0.34 && state.progressValue < 0.35)
}

@Test
func computesEatingPhaseAfterFastingEnds() {
    let start = Date(timeIntervalSince1970: 0)
    let now = start.addingTimeInterval(18 * 3600)
    let plan = FastingPlan(defaultStartHour: 20, defaultStartMinute: 0)

    let state = FastingTimerEngine.currentState(plan: plan, cycleStartedAt: start, now: now)

    #expect(state.phase == .eating)
    #expect(Int(state.phaseEndsAt.timeIntervalSince(start)) == 24 * 3600)
    #expect(state.progressValue == 0.25)
}
