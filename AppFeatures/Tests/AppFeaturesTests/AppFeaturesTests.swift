import Foundation
import Testing
@testable import AppFeatures

@Test
func validatesProviderDraft() throws {
    let draft = AISettingsDraft(rawJSON: #"""
    {
      "name": "本地可用配置",
      "isEnabled": true,
      "endpoint": "https://api.fastinglens.cn/v1/chat/completions",
      "method": "POST",
      "headers": {
        "Authorization": "Bearer REAL_KEY",
        "Content-Type": "application/json"
      },
      "request": {
        "model": "food-vision",
        "temperature": 0.2,
        "systemPrompt": "请识别食物并估算热量。",
        "userTemplate": "请分析图片并返回严格 JSON。",
        "imageFieldMode": "base64",
        "bodyTemplate": "{\n  \"model\": {{model}},\n  \"messages\": []\n}"
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
    """#)
    let config = try draft.validate()

    #expect(config.name == "本地可用配置")
    #expect(config.behavior.timeoutSeconds == 30)
}

@Test
func buildsDashboardCardFromSnapshot() {
    let now = Date(timeIntervalSince1970: 0)
    let snapshot = WatchSnapshotState(
        generatedAt: now,
        phase: .fasting,
        phaseEndsAt: now.addingTimeInterval(2 * 3600 + 5 * 60),
        todayCalories: 640,
        recentMeals: []
    )

    let card = DashboardViewModel.makeCard(snapshot: snapshot, now: now, fastingGoalHours: 16)

    #expect(card.phaseTitle == "断食中")
    #expect(card.remainingText == "02小时 05分")
    #expect(card.caloriesText == "640 千卡")
}

@Test
func rejectsPlaceholderProviderDraft() {
    let draft = AISettingsDraft(rawJSON: #"""
    {
      "name": "示例配置",
      "isEnabled": true,
      "endpoint": "https://example.com/v1/chat/completions",
      "method": "POST",
      "headers": {
        "Authorization": "Bearer REPLACE_ME",
        "Content-Type": "application/json"
      },
      "request": {
        "model": "food-vision-1",
        "temperature": 0.2,
        "systemPrompt": "请识别食物并估算热量。",
        "userTemplate": "请分析图片并返回严格 JSON。",
        "imageFieldMode": "base64",
        "bodyTemplate": "{\n  \"model\": {{model}},\n  \"messages\": []\n}"
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
    """#)

    #expect(throws: AISettingsDraft.ValidationError.self) {
        try draft.validate()
    }
}
