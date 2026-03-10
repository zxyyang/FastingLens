import AppFeatures
import Foundation

enum MealRecognitionServiceError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case invalidContent
    case unsupportedMethod
    case unsupportedImageMode

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "识别服务返回了无法解析的响应。"
        case .httpError(let statusCode, let message):
            return "识别服务请求失败（HTTP \(statusCode)）：\(message)"
        case .invalidContent:
            return "识别服务返回的数据里没有可用的餐食 JSON。"
        case .unsupportedMethod:
            return "当前版本只支持使用 POST 的识别配置。"
        case .unsupportedImageMode:
            return "当前版本只支持使用 Base64 传图。"
        }
    }
}

struct OpenAIChatRequest: Encodable {
    struct Message: Encodable {
        struct ContentPart: Encodable {
            struct ImageURLPayload: Encodable {
                let url: String
            }

            let type: String
            let text: String?
            let image_url: ImageURLPayload?
        }

        let role: String
        let content: MessageContent

        enum MessageContent: Encodable {
            case text(String)
            case rich([ContentPart])

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .text(let value):
                    try container.encode(value)
                case .rich(let parts):
                    try container.encode(parts)
                }
            }
        }
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let temperature: Double
    let messages: [Message]
    let response_format: ResponseFormat
}

struct MealRecognitionService {

    private var isAnthropicEndpoint: Bool {
        false // determined per-call
    }

    private func resolveIsAnthropic(_ provider: ProviderConfig) -> Bool {
        provider.headers.keys.contains(where: { $0.caseInsensitiveCompare("anthropic-version") == .orderedSame }) ||
        provider.endpoint.path.lowercased().contains("/messages")
    }

    func recognize(imageData: Data, provider: ProviderConfig) async throws -> MealRecognitionResult {
        guard provider.method == .post else {
            throw MealRecognitionServiceError.unsupportedMethod
        }
        guard provider.request.imageFieldMode == .base64 else {
            throw MealRecognitionServiceError.unsupportedImageMode
        }

        var request = URLRequest(url: provider.endpoint)
        request.httpMethod = provider.method.rawValue
        provider.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if !provider.headers.keys.contains(where: { $0.caseInsensitiveCompare("User-Agent") == .orderedSame }) {
            request.setValue(defaultUserAgent, forHTTPHeaderField: "User-Agent")
        }
        request.timeoutInterval = TimeInterval(provider.behavior.timeoutSeconds)

        let base64 = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"
        if let bodyTemplate = provider.request.bodyTemplate, !bodyTemplate.isEmpty {
            request.httpBody = try renderBodyTemplate(
                bodyTemplate,
                model: provider.request.model,
                temperature: provider.request.temperature,
                systemPrompt: provider.request.systemPrompt,
                userPrompt: provider.request.userTemplate,
                imageBase64: base64,
                imageDataURL: dataURL
            )
        } else if resolveIsAnthropic(provider) {
            // Anthropic Messages API format
            let body: [String: Any] = [
                "model": provider.request.model,
                "max_tokens": 2048,
                "system": provider.request.systemPrompt,
                "messages": [[
                    "role": "user",
                    "content": [
                        ["type": "text", "text": provider.request.userTemplate],
                        ["type": "image", "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64
                        ]]
                    ]
                ]]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else {
            // OpenAI compatible format
            let body = OpenAIChatRequest(
                model: provider.request.model,
                temperature: provider.request.temperature,
                messages: [
                    .init(role: "system", content: .text(provider.request.systemPrompt)),
                    .init(
                        role: "user",
                        content: .rich([
                            .init(type: "text", text: provider.request.userTemplate, image_url: nil),
                            .init(type: "image_url", text: nil, image_url: .init(url: dataURL))
                        ])
                    )
                ],
                response_format: .init(type: "json_object")
            )
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MealRecognitionServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MealRecognitionServiceError.httpError(
                statusCode: http.statusCode,
                message: extractErrorMessage(from: data)
            )
        }

        let rawObject = try JSONSerialization.jsonObject(with: data)
        guard let content = extractStringContent(from: rawObject, rootPath: provider.response.rootPath) else {
            throw MealRecognitionServiceError.invalidContent
        }

        let cleaned = stripMarkdownCodeBlock(content)
        guard let contentData = cleaned.data(using: .utf8) else {
            throw MealRecognitionServiceError.invalidContent
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MealRecognitionResult.self, from: contentData)
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

    private func renderBodyTemplate(
        _ template: String,
        model: String,
        temperature: Double,
        systemPrompt: String,
        userPrompt: String,
        imageBase64: String,
        imageDataURL: String
    ) throws -> Data {
        var rendered = template
        let replacements: [String: String] = [
            "{{model}}": jsonFragment(model),
            "{{temperature}}": String(temperature),
            "{{systemPrompt}}": jsonFragment(systemPrompt),
            "{{userPrompt}}": jsonFragment(userPrompt),
            "{{imageBase64}}": jsonFragment(imageBase64),
            "{{imageDataURL}}": jsonFragment(imageDataURL)
        ]
        for (placeholder, value) in replacements {
            rendered = rendered.replacingOccurrences(of: placeholder, with: value)
        }
        guard let data = rendered.data(using: .utf8) else {
            throw MealRecognitionServiceError.invalidContent
        }
        return data
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

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
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

    private func jsonFragment(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return String(data: data ?? Data("\"\"".utf8), encoding: .utf8) ?? "\"\""
    }
}
