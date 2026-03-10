import AppFeatures
import Foundation

let defaultAssistantSystemPromptTemplate = """
你是 {{assistantName}}，用户的私人减肥 AI 教练。你拥有 App 全部数据的读写权限。

回复格式（严格 JSON，禁止 Markdown、代码块、多余换行）：
{"assistant_message":"你的中文回复","tool_calls":[{"name":"工具名","arguments":{...}}]}
没有工具调用时：{"assistant_message":"你的中文回复","tool_calls":[]}

assistant_message 格式：纯文本 + emoji + 「」强调 + 数字序号。禁止使用 **加粗**、# 标题、- 列表等 Markdown 语法。

图片规则：
· 用户发送图片时你可以直接看到图片内容，绝对不要说「没有收到图片」或「无法查看」
· 看到食物图片必须立即分析，识别每一种食物的名称、估算份量（克/毫升/个）和对应热量，然后调用 recognize_food
· 识别要尽可能详细：不要笼统说「一份饭」，要拆分为「米饭约200g(232kcal)、红烧肉3块约120g(396kcal)、炒青菜约150g(45kcal)」

食物识别原则：
· 每种食物单独列出，写清名称、份量估算（带单位g/ml/个/片/杯）、该份量对应的热量
· 份量根据图片中食物的视觉大小、容器尺寸、与餐具的比例来估算
· 热量按「中国食物成分表」常见值计算：米饭 116kcal/100g、鸡胸肉 133kcal/100g、猪五花 395kcal/100g、鸡蛋 144kcal/100g、牛奶 54kcal/100ml、苹果 53kcal/100g 等
· 看不清或不确定时给出保守估算，confidence 设为 0.5-0.7
· food_items 数组里每个元素必须有 name、portion（如「约200g」）、estimated_calories（整数 kcal）

减肥计划制定规则（用户要求制定计划时必须遵守）：
1. 先调用 get_settings 获取用户身体数据（起始体重、目标体重）
2. 再调用 get_health_summary 获取 TDEE、活动消耗、基础代谢
3. 再调用 get_weight_trend(days=30) 查看体重变化趋势
4. 再调用 get_progress 查看当前进度
5. 综合以上所有数据，计算合理的每日热量预算：
   · 安全减重速度：每周 0.5-1kg，即每日缺口 500-1000kcal
   · 每日热量下限：女性不低于 1200kcal，男性不低于 1500kcal
   · 推荐热量 = TDEE - 500（温和减脂）或 TDEE - 750（积极减脂）
6. 给出完整计划后，调用 adjust_plan 写入推荐值

可用工具：

[记录] record_meal(meal_type, food_items[{name,portion,estimated_calories}], estimated_total_calories, confidence, notes) | recognize_food(同record_meal，生成卡片不入账) | commit_recognition(确认入账) | record_weight(weight, note) | record_water(ml, note) | mark_cheat_meal(note)

[修改] adjust_plan(fasting_hours, eating_hours, daily_calorie_goal, daily_water_goal, note) | update_settings(display_name, assistant_name, start_weight, target_weight, daily_calorie_goal, daily_water_goal, default_meal_type) | delete_meal(meal_id) | delete_water(water_id) | delete_weight(weight_id)

[查询] get_today_summary | get_health_summary | get_weight_trend(days) | get_weekly_report | get_meals(days) | get_waters(days) | get_all_weights | get_fasting_status | get_settings | get_plan | get_progress | get_logs

决策规则：
· 下方「当前状态」已含今日实时快照，简单引用无需调工具
· 需要历史数据、趋势、多日汇总时才调用查询工具
· 写入/删除操作必须调用工具执行，不要只口头说「已记录」
· 用户问每天该吃多少、帮我制定计划，必须先查询健康数据再给建议
· 还可以吃 = 预算 - 已摄入 + 运动消耗 = {{remainingCalories}} kcal
· 所有回复中文，简洁温暖，像朋友一样鼓励用户

当前状态：
· 称呼：{{displayName}}
· 体重：{{currentWeight}} kg（起始 {{startWeight}} → 目标 {{targetWeight}}）
· 热量：已摄入 {{todayCalories}} / 预算 {{dailyCalorieGoal}} / 还可吃 {{remainingCalories}} kcal
· 运动消耗：{{todayActiveCalories}} kcal
· 饮水：{{todayWaterML}} / {{dailyWaterGoal}} ml
· 断食：{{fastingHours}}:{{eatingHours}} · {{fastingPhaseLabel}} · 结束于 {{phaseEndsAt}}
· 步数：{{todaySteps}} · TDEE：{{estimatedTDEE}} · 热量缺口：{{calorieDeficit}} kcal
"""

struct StoredToolCall: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var argumentsJSONString: String

    init(id: UUID = UUID(), name: String, argumentsJSONString: String) {
        self.id = id
        self.name = name
        self.argumentsJSONString = argumentsJSONString
    }
}

struct StoredToolResult: Codable, Sendable {
    var toolName: String
    var resultJSONString: String

    init(toolName: String, resultJSONString: String) {
        self.toolName = toolName
        self.resultJSONString = resultJSONString
    }
}

enum StoredChatRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

struct StoredChatMessage: Codable, Identifiable, Sendable {
    var id: UUID
    var role: StoredChatRole
    var content: String
    var imageFileName: String?
    var toolCalls: [StoredToolCall]
    var toolResult: StoredToolResult?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: StoredChatRole,
        content: String,
        imageFileName: String? = nil,
        toolCalls: [StoredToolCall] = [],
        toolResult: StoredToolResult? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.imageFileName = imageFileName
        self.toolCalls = toolCalls
        self.toolResult = toolResult
        self.createdAt = createdAt
    }
}

struct StoredChatSession: Codable, Identifiable, Sendable {
    var id: UUID
    var startedAt: Date
    var title: String?
    var messages: [StoredChatMessage]

    init(id: UUID = UUID(), startedAt: Date = .now, title: String? = nil, messages: [StoredChatMessage] = []) {
        self.id = id
        self.startedAt = startedAt
        self.title = title
        self.messages = messages
    }
}

enum AssistantJSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: AssistantJSONValue])
    case array([AssistantJSONValue])
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: AssistantJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([AssistantJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value):
            return value
        case .string(let value):
            return Double(value)
        default:
            return nil
        }
    }

    var intValue: Int? {
        if let doubleValue {
            return Int(doubleValue)
        }
        return nil
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .string(let value):
            return Bool(value)
        default:
            return nil
        }
    }

    var objectValue: [String: AssistantJSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var arrayValue: [AssistantJSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(self)) ?? Data("null".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

struct AssistantToolCall: Decodable, Sendable {
    var name: String
    var arguments: AssistantJSONValue
}

struct AssistantChatResponse: Decodable, Sendable {
    var assistantMessage: String
    var toolCalls: [AssistantToolCall]

    init(assistantMessage: String = "", toolCalls: [AssistantToolCall] = []) {
        self.assistantMessage = assistantMessage
        self.toolCalls = toolCalls
    }

    enum CodingKeys: String, CodingKey {
        case assistantMessage
        case toolCalls
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assistantMessage = try container.decodeIfPresent(String.self, forKey: .assistantMessage) ?? ""
        toolCalls = try container.decodeIfPresent([AssistantToolCall].self, forKey: .toolCalls) ?? []
    }
}

struct AssistantContextSnapshot: Sendable {
    var displayName: String
    var assistantName: String
    var startWeight: Double
    var targetWeight: Double
    var currentWeight: Double
    var dailyCalorieGoal: Int
    var dailyWaterGoal: Int
    var todayCalories: Int
    var todayWaterML: Int
    var fastingHours: Int
    var eatingHours: Int
    var fastingPhaseLabel: String
    var phaseEndsAt: Date
    var todaySteps: Int
    var todayActiveCalories: Int
    var estimatedTDEE: Int
    var calorieDeficit: Int
}

enum AssistantChatServiceError: LocalizedError {
    case unsupportedMethod
    case invalidResponse
    case invalidContent
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedMethod:
            return "当前模型配置不支持助手对话请求。"
        case .invalidResponse:
            return "助手服务返回了无法解析的响应。"
        case .invalidContent:
            return "助手服务没有返回有效的 JSON。"
        case .httpError(let statusCode, let message):
            return "助手请求失败（HTTP \(statusCode)）：\(message)"
        }
    }
}

struct AssistantChatService {

    // MARK: - Streaming send (preferred)

    func sendStream(
        history: [StoredChatMessage],
        latestUserText: String,
        imageData: Data?,
        provider: ProviderConfig,
        context: AssistantContextSnapshot,
        assistantSystemPromptTemplate: String,
        onPartialText: @Sendable @escaping (String) -> Void
    ) async throws -> AssistantChatResponse {
        guard provider.method == .post else {
            throw AssistantChatServiceError.unsupportedMethod
        }

        let request = try buildRequest(
            history: history,
            latestUserText: latestUserText,
            imageData: imageData,
            provider: provider,
            context: context,
            assistantSystemPromptTemplate: assistantSystemPromptTemplate,
            stream: true
        )

        let providerMode = resolveMode(provider)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AssistantChatServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            throw AssistantChatServiceError.httpError(statusCode: http.statusCode, message: extractErrorMessage(from: errorData))
        }

        var accumulated = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let chunkData = payload.data(using: .utf8),
                  let chunk = try? JSONSerialization.jsonObject(with: chunkData) as? [String: Any] else { continue }

            let delta: String
            switch providerMode {
            case .openAICompatible:
                delta = extractOpenAIDelta(chunk)
            case .anthropic:
                delta = extractAnthropicDelta(chunk)
            }
            if !delta.isEmpty {
                accumulated += delta
                // Try to extract partial assistant_message for live display
                if let partial = extractPartialAssistantMessage(from: accumulated) {
                    onPartialText(partial)
                }
            }
        }

        // Parse the full accumulated content as JSON (with repair fallback)
        let cleaned = repairJSON(accumulated)
        guard let contentData = cleaned.data(using: .utf8) else {
            throw AssistantChatServiceError.invalidContent
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AssistantChatResponse.self, from: contentData)
    }

    // MARK: - Non-streaming send (fallback)

    func send(
        history: [StoredChatMessage],
        latestUserText: String,
        imageData: Data?,
        provider: ProviderConfig,
        context: AssistantContextSnapshot,
        assistantSystemPromptTemplate: String
    ) async throws -> AssistantChatResponse {
        guard provider.method == .post else {
            throw AssistantChatServiceError.unsupportedMethod
        }

        let request = try buildRequest(
            history: history,
            latestUserText: latestUserText,
            imageData: imageData,
            provider: provider,
            context: context,
            assistantSystemPromptTemplate: assistantSystemPromptTemplate,
            stream: false
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AssistantChatServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AssistantChatServiceError.httpError(statusCode: http.statusCode, message: extractErrorMessage(from: data))
        }

        let rawObject = try JSONSerialization.jsonObject(with: data)
        guard let content = extractStringContent(from: rawObject, rootPath: provider.response.rootPath) else {
            throw AssistantChatServiceError.invalidContent
        }

        let cleaned = repairJSON(content)
        guard let contentData = cleaned.data(using: .utf8) else {
            throw AssistantChatServiceError.invalidContent
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AssistantChatResponse.self, from: contentData)
    }

    // MARK: - Shared request builder

    private func buildRequest(
        history: [StoredChatMessage],
        latestUserText: String,
        imageData: Data?,
        provider: ProviderConfig,
        context: AssistantContextSnapshot,
        assistantSystemPromptTemplate: String,
        stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: provider.endpoint)
        request.httpMethod = provider.method.rawValue
        provider.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if !provider.headers.keys.contains(where: { $0.caseInsensitiveCompare("User-Agent") == .orderedSame }) {
            request.setValue(defaultUserAgent, forHTTPHeaderField: "User-Agent")
        }
        request.timeoutInterval = TimeInterval(provider.behavior.timeoutSeconds)

        let providerMode = resolveMode(provider)
        switch providerMode {
        case .anthropic:
            request.httpBody = try buildAnthropicBody(
                history: history, latestUserText: latestUserText, imageData: imageData,
                provider: provider, context: context,
                assistantSystemPromptTemplate: assistantSystemPromptTemplate,
                stream: stream
            )
        case .openAICompatible:
            request.httpBody = try buildOpenAIBody(
                history: history, latestUserText: latestUserText, imageData: imageData,
                provider: provider, context: context,
                assistantSystemPromptTemplate: assistantSystemPromptTemplate,
                stream: stream
            )
        }
        return request
    }

    // MARK: - SSE delta extraction

    private func extractOpenAIDelta(_ chunk: [String: Any]) -> String {
        guard let choices = chunk["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String else { return "" }
        return content
    }

    private func extractAnthropicDelta(_ chunk: [String: Any]) -> String {
        guard let type = chunk["type"] as? String else { return "" }
        if type == "content_block_delta",
           let delta = chunk["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return text
        }
        return ""
    }

    private func extractPartialAssistantMessage(from accumulated: String) -> String? {
        // Try to extract "assistant_message" value from partial JSON
        // Look for "assistant_message":"..." or "assistant_message": "..."
        let cleaned = stripMarkdownCodeBlock(accumulated)
        guard let range = cleaned.range(of: "\"assistant_message\"") else { return nil }
        let afterKey = cleaned[range.upperBound...]
        // Skip whitespace and colon
        guard let colonIndex = afterKey.firstIndex(of: ":") else { return nil }
        let afterColon = afterKey[afterKey.index(after: colonIndex)...].drop(while: { $0.isWhitespace })
        guard afterColon.first == "\"" else { return nil }
        // Extract string value, handling escaped quotes
        var result = ""
        var escaped = false
        for char in afterColon.dropFirst() {
            if escaped {
                switch char {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "\\": result.append("\\")
                case "\"": result.append("\"")
                default: result.append("\\"); result.append(char)
                }
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                return result
            } else {
                result.append(char)
            }
        }
        // String not yet closed — return what we have so far
        return result.isEmpty ? nil : result
    }

    private enum ProviderMode {
        case anthropic
        case openAICompatible
    }

    private func resolveMode(_ provider: ProviderConfig) -> ProviderMode {
        if provider.headers.keys.contains(where: { $0.caseInsensitiveCompare("anthropic-version") == .orderedSame }) ||
            provider.endpoint.path.lowercased().contains("/messages") {
            return .anthropic
        }
        return .openAICompatible
    }

    private func buildAnthropicBody(
        history: [StoredChatMessage],
        latestUserText: String,
        imageData: Data?,
        provider: ProviderConfig,
        context: AssistantContextSnapshot,
        assistantSystemPromptTemplate: String,
        stream: Bool
    ) throws -> Data {
        let systemPrompt = assistantSystemPrompt(template: assistantSystemPromptTemplate, context: context)
        let messages = history.map { message -> [String: Any] in
            [
                "role": message.role == .assistant ? "assistant" : "user",
                "content": message.content
            ]
        } + [[
            "role": "user",
            "content": anthropicUserContent(text: latestUserText, imageData: imageData)
        ]]

        var body: [String: Any] = [
            "model": provider.request.model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": messages
        ]
        if stream { body["stream"] = true }
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func buildOpenAIBody(
        history: [StoredChatMessage],
        latestUserText: String,
        imageData: Data?,
        provider: ProviderConfig,
        context: AssistantContextSnapshot,
        assistantSystemPromptTemplate: String,
        stream: Bool
    ) throws -> Data {
        var messages: [[String: Any]] = [[
            "role": "system",
            "content": assistantSystemPrompt(template: assistantSystemPromptTemplate, context: context)
        ]]

        messages += history.map { message in
            [
                "role": message.role == .assistant ? "assistant" : "user",
                "content": message.content
            ]
        }

        if let imageData {
            let dataURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
            messages.append([
                "role": "user",
                "content": [
                    ["type": "text", "text": latestUserText],
                    ["type": "image_url", "image_url": ["url": dataURL]]
                ]
            ])
        } else {
            messages.append([
                "role": "user",
                "content": latestUserText
            ])
        }

        var body: [String: Any] = [
            "model": provider.request.model,
            "response_format": ["type": "json_object"],
            "messages": messages
        ]
        if stream { body["stream"] = true }
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func anthropicUserContent(text: String, imageData: Data?) -> [[String: Any]] {
        var content: [[String: Any]] = [
            ["type": "text", "text": text]
        ]

        if let imageData {
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": imageData.base64EncodedString()
                ]
            ])
        }

        return content
    }

    private func assistantSystemPrompt(template: String, context: AssistantContextSnapshot) -> String {
        var rendered = template.isEmpty ? defaultAssistantSystemPromptTemplate : template
        let replacements: [String: String] = [
            "{{assistantName}}": context.assistantName,
            "{{displayName}}": context.displayName,
            "{{currentWeight}}": context.currentWeight.formatted(.number.precision(.fractionLength(1))),
            "{{startWeight}}": context.startWeight.formatted(.number.precision(.fractionLength(1))),
            "{{targetWeight}}": context.targetWeight.formatted(.number.precision(.fractionLength(1))),
            "{{todayCalories}}": String(context.todayCalories),
            "{{dailyCalorieGoal}}": String(context.dailyCalorieGoal),
            "{{todayWaterML}}": String(context.todayWaterML),
            "{{dailyWaterGoal}}": String(context.dailyWaterGoal),
            "{{fastingHours}}": String(context.fastingHours),
            "{{eatingHours}}": String(context.eatingHours),
            "{{fastingPhaseLabel}}": context.fastingPhaseLabel,
            "{{phaseEndsAt}}": context.phaseEndsAt.formatted(date: .omitted, time: .shortened),
            "{{todaySteps}}": String(context.todaySteps),
            "{{todayActiveCalories}}": String(context.todayActiveCalories),
            "{{estimatedTDEE}}": String(context.estimatedTDEE),
            "{{calorieDeficit}}": String(context.calorieDeficit),
            "{{remainingCalories}}": String(max(context.dailyCalorieGoal - context.todayCalories + context.todayActiveCalories, 0))
        ]

        for (placeholder, value) in replacements {
            rendered = rendered.replacingOccurrences(of: placeholder, with: value)
        }
        return rendered
    }

    private func stripMarkdownCodeBlock(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if s.hasSuffix("```") {
                s = String(s.dropLast(3))
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

    /// Try to extract valid JSON from messy model output
    private func repairJSON(_ raw: String) -> String {
        let s = stripMarkdownCodeBlock(raw)

        // If it already parses, return as-is
        if let data = s.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return s
        }

        // Try to find the outermost {...} block
        if let openBrace = s.firstIndex(of: "{"),
           let closeBrace = s.lastIndex(of: "}") {
            let extracted = String(s[openBrace...closeBrace])
            if let data = extracted.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return extracted
            }
        }

        // If JSON is truncated (no closing brace), try to salvage assistant_message
        if let msgStart = s.range(of: "\"assistant_message\"") {
            let afterKey = s[msgStart.upperBound...]
            if let colonIdx = afterKey.firstIndex(of: ":") {
                let afterColon = afterKey[afterKey.index(after: colonIdx)...].drop(while: { $0.isWhitespace })
                if afterColon.first == "\"" {
                    var msg = ""
                    var escaped = false
                    for char in afterColon.dropFirst() {
                        if escaped { msg.append(char); escaped = false }
                        else if char == "\\" { escaped = true }
                        else if char == "\"" { break }
                        else { msg.append(char) }
                    }
                    if !msg.isEmpty {
                        let escapedMsg = msg
                            .replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "\"", with: "\\\"")
                            .replacingOccurrences(of: "\n", with: "\\n")
                        return "{\"assistant_message\":\"\(escapedMsg)\",\"tool_calls\":[]}"
                    }
                }
            }
        }

        // Last resort: wrap the whole text as a plain message
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .prefix(800)
        return "{\"assistant_message\":\"\(escaped)\",\"tool_calls\":[]}"
    }

    private func extractStringContent(from object: Any, rootPath: String) -> String? {
        let parts = rootPath.split(separator: ".").map(String.init)
        var current: Any = object

        for part in parts {
            if let index = Int(part), let array = current as? [Any], array.indices.contains(index) {
                current = array[index]
            } else if let dictionary = current as? [String: Any], let next = dictionary[part] {
                current = next
            } else {
                return nil
            }
        }

        if let value = current as? String {
            return value
        }
        if JSONSerialization.isValidJSONObject(current),
           let data = try? JSONSerialization.data(withJSONObject: current),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }

    private func extractErrorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any] {
                if let message = error["message"] as? String, !message.isEmpty {
                    return message
                }
                if let type = error["type"] as? String, !type.isEmpty {
                    return type
                }
            }
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
        }

        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return String(text.prefix(240))
        }

        return "服务器没有返回可读的错误信息。"
    }

    private var defaultUserAgent: String {
        let bundle = Bundle.main
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "FastingLens"
        let shortVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        let buildVersion = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return "\(name)/\(shortVersion) (\(buildVersion); \(systemVersion))"
    }
}
