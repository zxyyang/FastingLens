import AppFeatures
import Foundation
import Observation
import WidgetKit

struct StoredMealItem: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var portion: String
    var estimatedCalories: Int

    init(id: UUID = UUID(), name: String, portion: String, estimatedCalories: Int) {
        self.id = id
        self.name = name
        self.portion = portion
        self.estimatedCalories = estimatedCalories
    }
}

struct StoredMealRecord: Codable, Identifiable, Sendable {
    var id: UUID
    var loggedAt: Date
    var mealType: String
    var totalCalories: Int
    var notes: String
    var imageFileName: String?
    var items: [StoredMealItem]

    init(
        id: UUID = UUID(),
        loggedAt: Date,
        mealType: String,
        totalCalories: Int,
        notes: String,
        imageFileName: String? = nil,
        items: [StoredMealItem]
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.mealType = mealType
        self.totalCalories = totalCalories
        self.notes = notes
        self.imageFileName = imageFileName
        self.items = items
    }
}

struct StoredFastingPlan: Codable, Sendable {
    var fastingHours: Int
    var eatingHours: Int
    var cycleStartedAt: Date
    var remindersEnabled: Bool

    static let `default` = StoredFastingPlan(
        fastingHours: 16,
        eatingHours: 8,
        cycleStartedAt: .now,
        remindersEnabled: true
    )
}

struct StoredWeightRecord: Codable, Identifiable, Sendable {
    var id: UUID
    var date: Date
    var weight: Double

    init(id: UUID = UUID(), date: Date = .now, weight: Double) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}

struct StoredWaterRecord: Codable, Identifiable, Sendable {
    var id: UUID
    var date: Date
    var milliliters: Int
    var note: String

    private enum CodingKeys: String, CodingKey {
        case id, date, milliliters, cups, note
    }

    init(id: UUID = UUID(), date: Date = .now, ml: Int, note: String = "") {
        self.id = id
        self.date = date
        self.milliliters = ml
        self.note = note
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? .now
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        if let ml = try container.decodeIfPresent(Int.self, forKey: .milliliters) {
            milliliters = ml
        } else if let cups = try container.decodeIfPresent(Int.self, forKey: .cups) {
            milliliters = cups * 250
        } else {
            milliliters = 250
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(milliliters, forKey: .milliliters)
        try container.encode(note, forKey: .note)
    }
}

struct StoredUserSettings: Codable, Sendable {
    var displayName: String
    var assistantName: String
    var startWeight: Double
    var targetWeight: Double
    var dailyCalorieGoal: Int
    var dailyWaterGoal: Int
    var defaultMealType: String
    var saveOriginalPhotos: Bool
    var avatarImageData: Data?

    static let `default` = StoredUserSettings(
        displayName: "我的断食",
        assistantName: "小燃",
        startWeight: 65,
        targetWeight: 60,
        dailyCalorieGoal: 1600,
        dailyWaterGoal: 2000,
        defaultMealType: "正餐",
        saveOriginalPhotos: true,
        avatarImageData: nil
    )
}

struct RecognitionLogEntry: Codable, Identifiable, Sendable {
    var id: UUID
    var createdAt: Date
    var status: String
    var providerName: String
    var details: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        status: String,
        providerName: String,
        details: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.status = status
        self.providerName = providerName
        self.details = details
    }
}

struct PersistedAppState: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case plan
        case settings
        case providerJSONString
        case assistantSystemPromptTemplate
        case meals
        case weights
        case waters
        case logs
        case chatSessions
        case activeChatSessionID
    }

    var plan: StoredFastingPlan
    var settings: StoredUserSettings
    var providerJSONString: String
    var assistantSystemPromptTemplate: String
    var meals: [StoredMealRecord]
    var weights: [StoredWeightRecord]
    var waters: [StoredWaterRecord]
    var logs: [RecognitionLogEntry]
    var chatSessions: [StoredChatSession]
    var activeChatSessionID: UUID?

    static let initial = PersistedAppState(
        plan: .default,
        settings: .default,
        providerJSONString: "",
        assistantSystemPromptTemplate: defaultAssistantSystemPromptTemplate,
        meals: [],
        weights: [],
        waters: [],
        logs: [],
        chatSessions: [],
        activeChatSessionID: nil
    )

    init(
        plan: StoredFastingPlan,
        settings: StoredUserSettings,
        providerJSONString: String,
        assistantSystemPromptTemplate: String,
        meals: [StoredMealRecord],
        weights: [StoredWeightRecord],
        waters: [StoredWaterRecord],
        logs: [RecognitionLogEntry],
        chatSessions: [StoredChatSession],
        activeChatSessionID: UUID?
    ) {
        self.plan = plan
        self.settings = settings
        self.providerJSONString = providerJSONString
        self.assistantSystemPromptTemplate = assistantSystemPromptTemplate
        self.meals = meals
        self.weights = weights
        self.waters = waters
        self.logs = logs
        self.chatSessions = chatSessions
        self.activeChatSessionID = activeChatSessionID
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        plan = try container.decodeIfPresent(StoredFastingPlan.self, forKey: .plan) ?? .default
        settings = try container.decodeIfPresent(StoredUserSettings.self, forKey: .settings) ?? .default
        providerJSONString = try container.decodeIfPresent(String.self, forKey: .providerJSONString) ?? ""
        assistantSystemPromptTemplate = try container.decodeIfPresent(String.self, forKey: .assistantSystemPromptTemplate) ?? defaultAssistantSystemPromptTemplate
        meals = try container.decodeIfPresent([StoredMealRecord].self, forKey: .meals) ?? []
        weights = try container.decodeIfPresent([StoredWeightRecord].self, forKey: .weights) ?? []
        waters = try container.decodeIfPresent([StoredWaterRecord].self, forKey: .waters) ?? []
        logs = try container.decodeIfPresent([RecognitionLogEntry].self, forKey: .logs) ?? []
        chatSessions = try container.decodeIfPresent([StoredChatSession].self, forKey: .chatSessions) ?? []
        activeChatSessionID = try container.decodeIfPresent(UUID.self, forKey: .activeChatSessionID)
    }
}

struct MealRecognitionResult: Codable, Sendable {
    struct FoodItem: Codable, Identifiable, Sendable {
        var id: UUID
        var name: String
        var portion: String
        var estimatedCalories: Int

        init(id: UUID = UUID(), name: String, portion: String, estimatedCalories: Int) {
            self.id = id
            self.name = name
            self.portion = portion
            self.estimatedCalories = estimatedCalories
        }
    }

    var mealType: String
    var foodItems: [FoodItem]
    var estimatedTotalCalories: Int
    var confidence: Double
    var notes: String
}

@MainActor
@Observable
final class AppState {
    private let defaults = UserDefaults.standard
    private let stateKey = "fastinglens.persisted.state"
    private let imageDirectoryName = "MealPhotos"
    private let reminderScheduler = ReminderScheduler.shared
    let healthKit = HealthKitManager()

    var persisted = PersistedAppState.initial
    var latestRecognition: MealRecognitionResult?
    var isRecognizing = false
    var isAssistantResponding = false
    var assistantStreamingText = ""
    var captureErrorMessage: String?
    var assistantErrorMessage: String?
    private let watchSync = PhoneWatchSyncBridge()
    private var watchObserver: NSObjectProtocol?

    init() {
        load()
        ensureActiveChatSession()
        watchObserver = NotificationCenter.default.addObserver(
            forName: .fastingLensWatchCommandDidReceive,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let command = notification.object as? WatchCommand else { return }
            Task { @MainActor [weak self] in
                self?.applyWatchCommand(command)
            }
        }
        pushSnapshot()
        reminderScheduler.reschedule(plan: persisted.plan, snapshot: dashboardSnapshot)
        Task { await healthKit.requestAuthorization(); await healthKit.refreshTodayData() }
    }

    var dashboardSnapshot: WatchSnapshotState {
        let timer = FastingTimerEngine.currentState(
            fastingHours: persisted.plan.fastingHours,
            eatingHours: persisted.plan.eatingHours,
            cycleStartedAt: persisted.plan.cycleStartedAt,
            now: .now
        )

        let budget = persisted.settings.dailyCalorieGoal
        let intake = todayCalories
        let exercise = healthKit.todayActiveCalories
        let remaining = max(budget - intake + exercise, 0)

        // Calculate eating window times
        let cycleDuration = TimeInterval((persisted.plan.fastingHours + persisted.plan.eatingHours) * 3600)
        let elapsed = Date.now.timeIntervalSince(persisted.plan.cycleStartedAt).truncatingRemainder(dividingBy: cycleDuration)
        let currentCycleStart = Date.now.addingTimeInterval(-elapsed)
        let eatStart = currentCycleStart.addingTimeInterval(TimeInterval(persisted.plan.fastingHours * 3600))
        let eatEnd = eatStart.addingTimeInterval(TimeInterval(persisted.plan.eatingHours * 3600))

        return WatchSnapshotState(
            generatedAt: .now,
            phase: timer.phase == .fasting ? .fasting : .eating,
            phaseEndsAt: timer.phaseEndsAt,
            todayCalories: intake,
            recentMeals: persisted.meals
                .sorted { $0.loggedAt > $1.loggedAt }
                .prefix(3)
                .map { RecentMealSummary(mealType: $0.mealType, totalCalories: $0.totalCalories, note: $0.notes) },
            dailyCalorieGoal: budget,
            remainingCalories: remaining,
            todayActiveCalories: exercise,
            estimatedTDEE: healthKit.estimatedTDEE,
            eatingWindowStart: eatStart,
            eatingWindowEnd: eatEnd
        )
    }

    var todayCalories: Int {
        let calendar = Calendar.current
        return persisted.meals
            .filter { calendar.isDateInToday($0.loggedAt) }
            .reduce(0) { $0 + $1.totalCalories }
    }

    var todayWaterML: Int {
        let calendar = Calendar.current
        return persisted.waters
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.milliliters }
    }

    var currentWeight: Double {
        persisted.weights.sorted { $0.date > $1.date }.first?.weight ?? persisted.settings.startWeight
    }

    var weightProgress: Double {
        let start = persisted.settings.startWeight
        let target = persisted.settings.targetWeight
        guard start != target else { return 1 }
        let total = start - target
        let completed = start - currentWeight
        return min(max(completed / total, 0), 1)
    }

    var joinedDays: Int {
        max(Calendar.current.dateComponents([.day], from: persisted.plan.cycleStartedAt, to: .now).day ?? 0, 0) + 1
    }

    var completedCheckInDates: Set<Date> {
        let calendar = Calendar.current
        let mealDays = persisted.meals.map { calendar.startOfDay(for: $0.loggedAt) }
        let waterDays = persisted.waters.map { calendar.startOfDay(for: $0.date) }
        let weightDays = persisted.weights.map { calendar.startOfDay(for: $0.date) }
        return Set(mealDays + waterDays + weightDays)
    }

    var activeChatMessages: [StoredChatMessage] {
        guard let activeChatSessionID = persisted.activeChatSessionID,
              let session = persisted.chatSessions.first(where: { $0.id == activeChatSessionID }) else {
            return []
        }
        return session.messages
    }

    var chatSessions: [StoredChatSession] {
        persisted.chatSessions.sorted { $0.startedAt > $1.startedAt }
    }

    var activeChatSessionID: UUID? {
        persisted.activeChatSessionID
    }

    func updateProviderJSONString(_ value: String) {
        persisted.providerJSONString = value
        save()
    }

    func updateAssistantSystemPromptTemplate(_ value: String) {
        persisted.assistantSystemPromptTemplate = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultAssistantSystemPromptTemplate : value
        save()
    }

    func updateUserSettings(
        displayName: String,
        assistantName: String,
        startWeight: Double,
        targetWeight: Double,
        dailyCalorieGoal: Int,
        dailyWaterGoal: Int,
        defaultMealType: String,
        saveOriginalPhotos: Bool
    ) {
        let currentAvatar = persisted.settings.avatarImageData
        persisted.settings = StoredUserSettings(
            displayName: displayName.isEmpty ? StoredUserSettings.default.displayName : displayName,
            assistantName: assistantName.isEmpty ? StoredUserSettings.default.assistantName : assistantName,
            startWeight: startWeight,
            targetWeight: targetWeight,
            dailyCalorieGoal: dailyCalorieGoal,
            dailyWaterGoal: dailyWaterGoal,
            defaultMealType: defaultMealType.isEmpty ? StoredUserSettings.default.defaultMealType : defaultMealType,
            saveOriginalPhotos: saveOriginalPhotos,
            avatarImageData: currentAvatar
        )
        save()
    }

    func updateAvatar(_ data: Data?) {
        persisted.settings.avatarImageData = data
        save()
    }

    func updatePlan(fastingHours: Int, eatingHours: Int, cycleStartedAt: Date, remindersEnabled: Bool) {
        persisted.plan = StoredFastingPlan(
            fastingHours: fastingHours,
            eatingHours: eatingHours,
            cycleStartedAt: cycleStartedAt,
            remindersEnabled: remindersEnabled
        )
        save()
        pushSnapshot()
        reminderScheduler.reschedule(plan: persisted.plan, snapshot: dashboardSnapshot)
    }

    func addMeal(_ meal: StoredMealRecord) {
        persisted.meals.insert(meal, at: 0)
        save()
        pushSnapshot()
        reminderScheduler.reschedule(plan: persisted.plan, snapshot: dashboardSnapshot)
    }

    func recordWeight(_ weight: Double, date: Date = .now) {
        persisted.weights.insert(StoredWeightRecord(date: date, weight: weight), at: 0)
        save()
    }

    func recordWater(ml: Int = 250, note: String = "", date: Date = .now) {
        persisted.waters.insert(StoredWaterRecord(date: date, ml: ml, note: note), at: 0)
        save()
    }

    func removeMeals(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            persisted.meals.remove(at: offset)
        }
        save()
    }

    func appendLog(status: String, providerName: String, details: String) {
        persisted.logs.insert(
            RecognitionLogEntry(status: status, providerName: providerName, details: details),
            at: 0
        )
        persisted.logs = Array(persisted.logs.prefix(20))
        save()
    }

    func recognizeMeal(imageData: Data) async {
        isRecognizing = true
        captureErrorMessage = nil
        defer { isRecognizing = false }

        let providerDraft = AISettingsDraft(rawJSON: persisted.providerJSONString)

        do {
            let config = try providerDraft.validate()
            let service = MealRecognitionService()
            let result = try await service.recognize(imageData: imageData, provider: config)
            latestRecognition = result
            appendLog(
                status: "成功",
                providerName: config.name,
                details: "识别出 \(result.foodItems.count) 个食物项，置信度 \(Int(result.confidence * 100))%"
            )
        } catch {
            captureErrorMessage = error.localizedDescription
            let providerName = (try? providerDraft.validate().name) ?? "未知配置源"
            appendLog(status: "失败", providerName: providerName, details: error.localizedDescription)
        }
    }

    func commitRecognition(_ recognition: MealRecognitionResult, imageData: Data?) {
        let imageFileName: String?
        if persisted.settings.saveOriginalPhotos, let imageData {
            imageFileName = try? storeImage(data: imageData)
        } else {
            imageFileName = nil
        }
        let meal = StoredMealRecord(
            loggedAt: .now,
            mealType: recognition.mealType.isEmpty ? persisted.settings.defaultMealType : recognition.mealType,
            totalCalories: recognition.estimatedTotalCalories,
            notes: recognition.notes,
            imageFileName: imageFileName,
            items: recognition.foodItems.map {
                StoredMealItem(name: $0.name, portion: $0.portion, estimatedCalories: $0.estimatedCalories)
            }
        )
        addMeal(meal)
        self.latestRecognition = nil
    }

    func resetLatestRecognition() {
        latestRecognition = nil
        captureErrorMessage = nil
    }

    func imageURL(for fileName: String) -> URL {
        imageDirectoryURL.appendingPathComponent(fileName)
    }

    func startNewChatSession() {
        let session = StoredChatSession(
            title: "新的对话",
            messages: [
                StoredChatMessage(
                    role: .assistant,
                    content: "\(persisted.settings.assistantName) 已上线。直接告诉我你今天吃了什么，或者发一张照片。"
                )
            ]
        )
        persisted.chatSessions.insert(session, at: 0)
        persisted.activeChatSessionID = session.id
        save()
    }

    func appendAssistantNote(_ content: String) {
        appendChatMessage(
            StoredChatMessage(
                role: .assistant,
                content: content
            )
        )
    }

    func selectChatSession(_ id: UUID) {
        guard persisted.chatSessions.contains(where: { $0.id == id }) else { return }
        persisted.activeChatSessionID = id
        save()
    }

    func renameChatSession(_ id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = persisted.chatSessions.firstIndex(where: { $0.id == id }) else { return }
        persisted.chatSessions[index].title = trimmed
        save()
    }

    func deleteChatSession(_ id: UUID) {
        guard let index = persisted.chatSessions.firstIndex(where: { $0.id == id }) else { return }
        persisted.chatSessions.remove(at: index)

        if persisted.chatSessions.isEmpty {
            persisted.activeChatSessionID = nil
            startNewChatSession()
            return
        }

        if persisted.activeChatSessionID == id {
            persisted.activeChatSessionID = persisted.chatSessions.first?.id
        }
        save()
    }

    func sendAssistantMessage(text: String, imageData: Data?) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty || imageData != nil else { return }

        assistantErrorMessage = nil
        assistantStreamingText = ""
        isAssistantResponding = true
        defer {
            isAssistantResponding = false
            assistantStreamingText = ""
        }

        let providerDraft = AISettingsDraft(rawJSON: persisted.providerJSONString)

        do {
            let provider = try providerDraft.validate()
            let imageFileName = persisted.settings.saveOriginalPhotos && imageData != nil ? try? storeImage(data: imageData!) : nil

            let userDisplayText = trimmedText.isEmpty ? "请帮我识别这张餐食图片。" : trimmedText
            appendChatMessage(
                StoredChatMessage(
                    role: .user,
                    content: userDisplayText,
                    imageFileName: imageFileName
                )
            )

            let service = AssistantChatService()
            var nextPrompt = trimmedText.isEmpty ? "请识别这张餐食图片中的所有食物，给出每个食物的名称、份量和热量估算，然后调用 recognize_food 工具。" : trimmedText
            var nextImageData = imageData
            var round = 0
            var executedToolFingerprints = Set<String>()

            var pendingWriteOutcomes: [ExecutedToolOutcome] = []
            var lastAssistantMessage = ""

            while round < 3 {
                round += 1
                let isFirstRound = round == 1

                let response: AssistantChatResponse
                if isFirstRound {
                    response = try await service.sendStream(
                        history: Array(activeChatMessages.dropLast()),
                        latestUserText: nextPrompt,
                        imageData: nextImageData,
                        provider: provider,
                        context: assistantContextSnapshot,
                        assistantSystemPromptTemplate: defaultAssistantSystemPromptTemplate,
                        onPartialText: { [weak self] partial in
                            Task { @MainActor in
                                self?.assistantStreamingText = partial
                            }
                        }
                    )
                } else {
                    response = try await service.send(
                        history: Array(activeChatMessages.dropLast()),
                        latestUserText: nextPrompt,
                        imageData: nil,
                        provider: provider,
                        context: assistantContextSnapshot,
                        assistantSystemPromptTemplate: defaultAssistantSystemPromptTemplate
                    )
                }

                if !response.assistantMessage.isEmpty {
                    lastAssistantMessage = response.assistantMessage
                }
                assistantStreamingText = ""

                guard !response.toolCalls.isEmpty else { break }

                let freshToolCalls = response.toolCalls.filter { toolCall in
                    guard isMutatingAssistantTool(toolCall.name) else { return true }
                    let fingerprint = "\(toolCall.name)::\(toolCall.arguments.jsonString())"
                    guard !executedToolFingerprints.contains(fingerprint) else { return false }
                    executedToolFingerprints.insert(fingerprint)
                    return true
                }

                if freshToolCalls.isEmpty { break }

                let toolOutcomes = executeAssistantToolCalls(freshToolCalls)

                for outcome in toolOutcomes where isMutatingAssistantTool(outcome.result.toolName) {
                    pendingWriteOutcomes.append(outcome)
                }

                nextPrompt = """
                工具调用已执行完成，结果：
                \(toolOutcomes.map(\.summary).joined(separator: "\n"))

                请基于结果给出最终答复，一次性回复完整内容。不要重复之前说过的话。
                """
                nextImageData = nil
            }

            // Show one assistant message
            if !lastAssistantMessage.isEmpty {
                appendChatMessage(
                    StoredChatMessage(
                        role: .assistant,
                        content: lastAssistantMessage
                    )
                )
            }

            // Show write operation results as cards
            for outcome in pendingWriteOutcomes {
                appendChatMessage(
                    StoredChatMessage(
                        role: .system,
                        content: outcome.summary,
                        toolResult: outcome.result
                    )
                )
            }
        } catch {
            assistantErrorMessage = error.localizedDescription
            appendChatMessage(
                StoredChatMessage(
                    role: .assistant,
                    content: "这次没有处理成功：\(error.localizedDescription)"
                )
            )
        }
    }

    func exportStateURL() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(persisted)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FastingLens-Export.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func clearAllData() {
        persisted = .initial
        latestRecognition = nil
        captureErrorMessage = nil
        if FileManager.default.fileExists(atPath: imageDirectoryURL.path) {
            try? FileManager.default.removeItem(at: imageDirectoryURL)
        }
        defaults.removeObject(forKey: stateKey)
        save()
        reminderScheduler.reschedule(plan: persisted.plan, snapshot: dashboardSnapshot)
    }

    private func load() {
        guard let data = defaults.data(forKey: stateKey) else { return }
        if let decoded = try? JSONDecoder().decode(PersistedAppState.self, from: data) {
            persisted = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(persisted) {
            defaults.set(data, forKey: stateKey)
        }
        pushSnapshot()
    }

    private func ensureActiveChatSession() {
        if persisted.chatSessions.isEmpty {
            startNewChatSession()
            return
        }

        if let activeChatSessionID = persisted.activeChatSessionID,
           persisted.chatSessions.contains(where: { $0.id == activeChatSessionID }) {
            return
        }

        persisted.activeChatSessionID = persisted.chatSessions.first?.id
        save()
    }

    private func appendChatMessage(_ message: StoredChatMessage) {
        ensureActiveChatSession()
        guard let activeChatSessionID = persisted.activeChatSessionID,
              let index = persisted.chatSessions.firstIndex(where: { $0.id == activeChatSessionID }) else {
            return
        }
        persisted.chatSessions[index].messages.append(message)
        if persisted.chatSessions[index].title == nil, message.role == .user {
            persisted.chatSessions[index].title = String(message.content.prefix(12))
        }
        save()
    }

    private var assistantContextSnapshot: AssistantContextSnapshot {
        let snapshot = dashboardSnapshot
        return AssistantContextSnapshot(
            displayName: persisted.settings.displayName,
            assistantName: persisted.settings.assistantName,
            startWeight: persisted.settings.startWeight,
            targetWeight: persisted.settings.targetWeight,
            currentWeight: currentWeight,
            dailyCalorieGoal: persisted.settings.dailyCalorieGoal,
            dailyWaterGoal: persisted.settings.dailyWaterGoal,
            todayCalories: todayCalories,
            todayWaterML: todayWaterML,
            fastingHours: persisted.plan.fastingHours,
            eatingHours: persisted.plan.eatingHours,
            fastingPhaseLabel: snapshot.phase == .fasting ? "断食中" : "进食窗口",
            phaseEndsAt: snapshot.phaseEndsAt,
            todaySteps: healthKit.todaySteps,
            todayActiveCalories: healthKit.todayActiveCalories,
            estimatedTDEE: healthKit.isAuthorized ? healthKit.estimatedTDEE : persisted.settings.dailyCalorieGoal,
            calorieDeficit: (healthKit.isAuthorized ? healthKit.estimatedTDEE : persisted.settings.dailyCalorieGoal) - todayCalories
        )
    }

    private struct ExecutedToolOutcome {
        var summary: String
        var result: StoredToolResult
    }

    private func executeAssistantToolCalls(_ toolCalls: [AssistantToolCall]) -> [ExecutedToolOutcome] {
        var outcomes: [ExecutedToolOutcome] = []

        for toolCall in toolCalls {
            let arguments = toolCall.arguments.objectValue ?? [:]

            switch toolCall.name {

            // ── 记录类 ──

            case "record_water":
                let ml = max(arguments["ml"]?.intValue ?? 250, 1)
                let note = arguments["note"]?.stringValue ?? ""
                recordWater(ml: ml, note: note)
                outcomes.append(.init(
                    summary: "已记录饮水 \(ml) ml。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "ml": ml, "today_total_ml": todayWaterML, "note": note
                    ]))
                ))

            case "record_weight":
                if let weight = arguments["weight"]?.doubleValue {
                    recordWeight(weight)
                    outcomes.append(.init(
                        summary: "已记录体重 \(weight.formatted(.number.precision(.fractionLength(1)))) kg。",
                        result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                            "weight": weight, "current_weight": currentWeight
                        ]))
                    ))
                }

            case "mark_cheat_meal":
                let note = arguments["note"]?.stringValue ?? "放纵餐"
                appendLog(status: "助手", providerName: persisted.settings.assistantName, details: note)
                outcomes.append(.init(
                    summary: "已标记放纵餐。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["note": note, "status": "marked"]))
                ))

            case "record_meal", "recognize_food":
                if let recognition = buildRecognition(from: arguments) {
                    latestRecognition = recognition
                    let foodList = recognition.foodItems.map { "\($0.name)(\($0.portion), \($0.estimatedCalories)kcal)" }.joined(separator: "、")
                    outcomes.append(.init(
                        summary: "识别到：\(foodList)，共约 \(recognition.estimatedTotalCalories) kcal",
                        result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                            "meal_type": recognition.mealType,
                            "estimated_total_calories": recognition.estimatedTotalCalories,
                            "items": recognition.foodItems.count,
                            "food_list": foodList
                        ]))
                    ))
                }

            // ── 修改类 ──

            case "adjust_plan":
                let fh = arguments["fasting_hours"]?.intValue ?? persisted.plan.fastingHours
                let eh = arguments["eating_hours"]?.intValue ?? persisted.plan.eatingHours
                let cg = arguments["daily_calorie_goal"]?.intValue ?? persisted.settings.dailyCalorieGoal
                let wg = arguments["daily_water_goal"]?.intValue ?? persisted.settings.dailyWaterGoal
                updatePlan(fastingHours: fh, eatingHours: eh, cycleStartedAt: persisted.plan.cycleStartedAt, remindersEnabled: persisted.plan.remindersEnabled)
                updateUserSettings(displayName: persisted.settings.displayName, assistantName: persisted.settings.assistantName, startWeight: persisted.settings.startWeight, targetWeight: persisted.settings.targetWeight, dailyCalorieGoal: cg, dailyWaterGoal: wg, defaultMealType: persisted.settings.defaultMealType, saveOriginalPhotos: persisted.settings.saveOriginalPhotos)
                outcomes.append(.init(
                    summary: "计划已更新：\(fh):\(eh) 断食，热量目标 \(cg) kcal，饮水目标 \(wg) ml。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "fasting_hours": fh, "eating_hours": eh, "daily_calorie_goal": cg, "daily_water_goal": wg
                    ]))
                ))

            case "update_settings":
                let dn = arguments["display_name"]?.stringValue ?? persisted.settings.displayName
                let an = arguments["assistant_name"]?.stringValue ?? persisted.settings.assistantName
                let sw = arguments["start_weight"]?.doubleValue ?? persisted.settings.startWeight
                let tw = arguments["target_weight"]?.doubleValue ?? persisted.settings.targetWeight
                let cg = arguments["daily_calorie_goal"]?.intValue ?? persisted.settings.dailyCalorieGoal
                let wg = arguments["daily_water_goal"]?.intValue ?? persisted.settings.dailyWaterGoal
                let mt = arguments["default_meal_type"]?.stringValue ?? persisted.settings.defaultMealType
                updateUserSettings(displayName: dn, assistantName: an, startWeight: sw, targetWeight: tw, dailyCalorieGoal: cg, dailyWaterGoal: wg, defaultMealType: mt, saveOriginalPhotos: persisted.settings.saveOriginalPhotos)
                outcomes.append(.init(
                    summary: "用户设置已更新。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "display_name": dn, "target_weight": tw, "daily_calorie_goal": cg, "daily_water_goal": wg
                    ]))
                ))

            case "delete_meal":
                if let idStr = arguments["meal_id"]?.stringValue, let uuid = UUID(uuidString: idStr),
                   let idx = persisted.meals.firstIndex(where: { $0.id == uuid }) {
                    let meal = persisted.meals[idx]
                    persisted.meals.remove(at: idx)
                    save()
                    outcomes.append(.init(
                        summary: "已删除餐食记录（\(meal.totalCalories) kcal）。",
                        result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["deleted_id": idStr, "calories": meal.totalCalories]))
                    ))
                } else {
                    outcomes.append(.init(summary: "未找到该餐食记录。", result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["status": "not_found"]))))
                }

            case "delete_water":
                if let idStr = arguments["water_id"]?.stringValue, let uuid = UUID(uuidString: idStr),
                   let idx = persisted.waters.firstIndex(where: { $0.id == uuid }) {
                    let water = persisted.waters[idx]
                    persisted.waters.remove(at: idx)
                    save()
                    outcomes.append(.init(
                        summary: "已删除饮水记录（\(water.milliliters) ml）。",
                        result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["deleted_id": idStr, "ml": water.milliliters]))
                    ))
                } else {
                    outcomes.append(.init(summary: "未找到该饮水记录。", result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["status": "not_found"]))))
                }

            case "delete_weight":
                if let idStr = arguments["weight_id"]?.stringValue, let uuid = UUID(uuidString: idStr),
                   let idx = persisted.weights.firstIndex(where: { $0.id == uuid }) {
                    let weight = persisted.weights[idx]
                    persisted.weights.remove(at: idx)
                    save()
                    outcomes.append(.init(
                        summary: "已删除体重记录（\(weight.weight.formatted(.number.precision(.fractionLength(1)))) kg）。",
                        result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["deleted_id": idStr, "weight": weight.weight]))
                    ))
                } else {
                    outcomes.append(.init(summary: "未找到该体重记录。", result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["status": "not_found"]))))
                }

            // ── 查询类 ──

            case "get_today_summary":
                let remaining = max(persisted.settings.dailyCalorieGoal - todayCalories + healthKit.todayActiveCalories, 0)
                outcomes.append(.init(
                    summary: "今日摄入 \(todayCalories) kcal，还可吃 \(remaining) kcal，饮水 \(todayWaterML) ml，体重 \(currentWeight.formatted(.number.precision(.fractionLength(1)))) kg。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "today_calories": todayCalories, "remaining_calories": remaining,
                        "today_water_ml": todayWaterML, "current_weight": currentWeight,
                        "active_calories": healthKit.todayActiveCalories
                    ]))
                ))

            case "get_health_summary":
                let tdee = healthKit.isAuthorized ? healthKit.estimatedTDEE : persisted.settings.dailyCalorieGoal
                let deficit = tdee - todayCalories
                outcomes.append(.init(
                    summary: "步数 \(healthKit.todaySteps)，活动消耗 \(healthKit.todayActiveCalories) kcal，TDEE \(tdee) kcal，缺口 \(deficit) kcal。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "today_steps": healthKit.todaySteps, "active_calories": healthKit.todayActiveCalories,
                        "basal_calories": healthKit.todayBasalCalories, "estimated_tdee": tdee,
                        "calorie_deficit": deficit, "healthkit_authorized": healthKit.isAuthorized
                    ]))
                ))

            case "get_weight_trend":
                let days = max(arguments["days"]?.intValue ?? 7, 1)
                let cal = Calendar.current
                let cutoff = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: .now)) ?? .now
                let records = persisted.weights.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }
                let trend = records.map { "\($0.date.formatted(date: .abbreviated, time: .omitted)) \($0.weight.formatted(.number.precision(.fractionLength(1))))kg" }.joined(separator: "；")
                outcomes.append(.init(
                    summary: records.isEmpty ? "最近 \(days) 天没有体重数据。" : trend,
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["days": days, "count": records.count]))
                ))

            case "get_weekly_report":
                let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)) ?? .now
                let wm = persisted.meals.filter { $0.loggedAt >= weekStart }
                let wc = wm.reduce(0) { $0 + $1.totalCalories }
                let ww = persisted.waters.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.milliliters }
                outcomes.append(.init(
                    summary: "7 天：\(wm.count) 餐 \(wc) kcal，饮水 \(ww) ml。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "weekly_meals": wm.count, "weekly_calories": wc, "weekly_water_ml": ww
                    ]))
                ))

            case "get_meals":
                let days = max(arguments["days"]?.intValue ?? 7, 1)
                let cal = Calendar.current
                let cutoff = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: .now)) ?? .now
                let meals = persisted.meals.filter { $0.loggedAt >= cutoff }.sorted { $0.loggedAt > $1.loggedAt }
                let list = meals.prefix(20).map { m in
                    let items = m.items.map { "\($0.name)(\($0.estimatedCalories)kcal)" }.joined(separator: "、")
                    return "[\(m.id.uuidString)] \(m.loggedAt.formatted(date: .abbreviated, time: .shortened)) \(m.mealType) \(m.totalCalories)kcal: \(items)"
                }.joined(separator: "\n")
                outcomes.append(.init(
                    summary: meals.isEmpty ? "最近 \(days) 天没有餐食记录。" : "最近 \(days) 天共 \(meals.count) 条餐食记录。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["count": meals.count, "list": list]))
                ))

            case "get_waters":
                let days = max(arguments["days"]?.intValue ?? 1, 1)
                let cal = Calendar.current
                let cutoff = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: .now)) ?? .now
                let waters = persisted.waters.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }
                let list = waters.prefix(20).map { w in
                    "[\(w.id.uuidString)] \(w.date.formatted(date: .abbreviated, time: .shortened)) \(w.milliliters)ml \(w.note)"
                }.joined(separator: "\n")
                outcomes.append(.init(
                    summary: waters.isEmpty ? "最近 \(days) 天没有饮水记录。" : "最近 \(days) 天共 \(waters.count) 条饮水记录。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["count": waters.count, "list": list]))
                ))

            case "get_fasting_status":
                let snapshot = dashboardSnapshot
                let isFasting = snapshot.phase == .fasting
                let remaining = max(snapshot.phaseEndsAt.timeIntervalSince(.now), 0)
                let hours = Int(remaining) / 3600
                let mins = (Int(remaining) % 3600) / 60
                outcomes.append(.init(
                    summary: "\(isFasting ? "断食中" : "进食窗口")，还剩 \(hours)h\(mins)m。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "phase": isFasting ? "fasting" : "eating",
                        "remaining_minutes": Int(remaining) / 60,
                        "ends_at": snapshot.phaseEndsAt.formatted(date: .omitted, time: .shortened),
                        "plan": "\(persisted.plan.fastingHours):\(persisted.plan.eatingHours)"
                    ]))
                ))

            case "get_settings":
                let s = persisted.settings
                outcomes.append(.init(
                    summary: "用户设置：\(s.displayName)，目标 \(s.targetWeight)kg，热量 \(s.dailyCalorieGoal)kcal，饮水 \(s.dailyWaterGoal)ml。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "display_name": s.displayName, "assistant_name": s.assistantName,
                        "start_weight": s.startWeight, "target_weight": s.targetWeight,
                        "daily_calorie_goal": s.dailyCalorieGoal, "daily_water_goal": s.dailyWaterGoal,
                        "default_meal_type": s.defaultMealType, "save_original_photos": s.saveOriginalPhotos
                    ]))
                ))

            case "get_plan":
                let p = persisted.plan
                outcomes.append(.init(
                    summary: "断食计划：\(p.fastingHours):\(p.eatingHours)，\(p.remindersEnabled ? "提醒开启" : "提醒关闭")。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "fasting_hours": p.fastingHours, "eating_hours": p.eatingHours,
                        "cycle_started_at": p.cycleStartedAt.formatted(date: .abbreviated, time: .omitted),
                        "reminders_enabled": p.remindersEnabled
                    ]))
                ))

            case "get_progress":
                let progress = Int(weightProgress * 100)
                let checkIns = completedCheckInDates.count
                outcomes.append(.init(
                    summary: "减重进度 \(progress)%，已坚持 \(joinedDays) 天，打卡 \(checkIns) 天。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                        "weight_progress_percent": progress, "joined_days": joinedDays,
                        "check_in_days": checkIns, "current_weight": currentWeight,
                        "start_weight": persisted.settings.startWeight, "target_weight": persisted.settings.targetWeight
                    ]))
                ))

            case "get_all_weights":
                let allWeights = persisted.weights.sorted { $0.date > $1.date }
                let list = allWeights.prefix(50).map { w in
                    "[\(w.id.uuidString)] \(w.date.formatted(date: .abbreviated, time: .shortened)) \(w.weight.formatted(.number.precision(.fractionLength(1))))kg"
                }.joined(separator: "\n")
                outcomes.append(.init(
                    summary: "共 \(allWeights.count) 条体重记录。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["count": allWeights.count, "list": list]))
                ))

            case "get_logs":
                let logList = persisted.logs.prefix(10).map { l in
                    "\(l.createdAt.formatted(date: .abbreviated, time: .shortened)) [\(l.status)] \(l.providerName): \(l.details)"
                }.joined(separator: "\n")
                outcomes.append(.init(
                    summary: "最近 \(min(persisted.logs.count, 10)) 条日志。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["count": persisted.logs.count, "list": logList]))
                ))

            case "commit_recognition":
                if let recognition = latestRecognition {
                    commitRecognition(recognition, imageData: nil)
                    latestRecognition = nil
                    outcomes.append(.init(
                        summary: "已将识别结果写入账本（\(recognition.estimatedTotalCalories) kcal）。",
                        result: .init(toolName: toolCall.name, resultJSONString: makeJSONString([
                            "status": "committed", "calories": recognition.estimatedTotalCalories,
                            "meal_type": recognition.mealType, "items": recognition.foodItems.count
                        ]))
                    ))
                } else {
                    outcomes.append(.init(
                        summary: "当前没有待确认的识别结果。",
                        result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["status": "no_pending"]))
                    ))
                }

            default:
                outcomes.append(.init(
                    summary: "暂不支持工具 \(toolCall.name)。",
                    result: .init(toolName: toolCall.name, resultJSONString: makeJSONString(["status": "unsupported"]))
                ))
            }
        }

        return outcomes
    }

    private func makeJSONString(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func isMutatingAssistantTool(_ name: String) -> Bool {
        switch name {
        case "record_water", "record_weight", "mark_cheat_meal", "adjust_plan",
             "record_meal", "recognize_food", "update_settings",
             "delete_meal", "delete_water", "delete_weight",
             "commit_recognition":
            return true
        default:
            return false
        }
    }

    private func buildRecognition(from arguments: [String: AssistantJSONValue]) -> MealRecognitionResult? {
        let mealType = arguments["meal_type"]?.stringValue ?? persisted.settings.defaultMealType
        let estimatedTotalCalories = arguments["estimated_total_calories"]?.intValue ?? 0
        let confidence = arguments["confidence"]?.doubleValue ?? 0.72
        let notes = arguments["notes"]?.stringValue ?? ""
        let foodItems = (arguments["food_items"]?.arrayValue ?? []).compactMap { item -> MealRecognitionResult.FoodItem? in
            guard let object = item.objectValue,
                  let name = object["name"]?.stringValue else {
                return nil
            }
            return MealRecognitionResult.FoodItem(
                name: name,
                portion: object["portion"]?.stringValue ?? "1 份",
                estimatedCalories: object["estimated_calories"]?.intValue ?? 0
            )
        }
        guard !foodItems.isEmpty || estimatedTotalCalories > 0 else { return nil }
        return MealRecognitionResult(
            mealType: mealType,
            foodItems: foodItems,
            estimatedTotalCalories: estimatedTotalCalories,
            confidence: confidence,
            notes: notes
        )
    }

    private func pushSnapshot() {
        let snapshot = dashboardSnapshot
        SharedSnapshotStore.save(snapshot: snapshot)
        watchSync.push(snapshot: snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func applyWatchCommand(_ command: WatchCommand) {
        switch command.action {
        case .startFasting:
            persisted.plan.cycleStartedAt = .now
            appendLog(status: "手表", providerName: "手表", details: "手表重新开始了断食")
        case .openEatingWindow:
            persisted.plan.cycleStartedAt = .now.addingTimeInterval(-TimeInterval(persisted.plan.fastingHours * 3600))
            appendLog(status: "手表", providerName: "手表", details: "手表打开了进食窗口")
        case .logQuickMeal:
            let calories = max(command.calories ?? 0, 0)
            let meal = StoredMealRecord(
                loggedAt: command.createdAt,
                mealType: "手表快捷记录",
                totalCalories: calories,
                notes: calories == 0 ? "来自手表的快捷记录，待在手机补充热量" : "来自手表的快捷记录",
                items: [StoredMealItem(name: "快捷记录", portion: "1 次", estimatedCalories: calories)]
            )
            addMeal(meal)
            appendLog(
                status: "手表",
                providerName: "手表",
                details: calories == 0 ? "手表记录了一餐，等待补充热量" : "手表记录了 \(calories) 千卡"
            )
            return
        }
        save()
        pushSnapshot()
        reminderScheduler.reschedule(plan: persisted.plan, snapshot: dashboardSnapshot)
    }

    private var imageDirectoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documents.appendingPathComponent(imageDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        return directory
    }

    private func storeImage(data: Data) throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let url = imageDirectoryURL.appendingPathComponent(fileName)
        try data.write(to: url)
        return fileName
    }
}
