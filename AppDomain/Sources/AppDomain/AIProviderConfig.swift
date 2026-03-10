import Foundation

public enum HTTPMethod: String, Codable, Sendable {
    case get = "GET"
    case post = "POST"
}

public enum ImageFieldMode: String, Codable, Sendable {
    case base64
    case remoteURL
    case multipart
}

public enum ResponseFormat: String, Codable, Sendable {
    case json
    case text
}

public struct AIProviderConfig: Codable, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isEnabled
        case endpoint
        case method
        case headers
        case request
        case response
        case behavior
    }

    public struct RequestTemplate: Codable, Sendable {
        public var model: String
        public var temperature: Double
        public var systemPrompt: String
        public var userTemplate: String
        public var imageFieldMode: ImageFieldMode

        public init(
            model: String,
            temperature: Double,
            systemPrompt: String,
            userTemplate: String,
            imageFieldMode: ImageFieldMode
        ) {
            self.model = model
            self.temperature = temperature
            self.systemPrompt = systemPrompt
            self.userTemplate = userTemplate
            self.imageFieldMode = imageFieldMode
        }
    }

    public struct ResponseTemplate: Codable, Sendable {
        public var format: ResponseFormat
        public var rootPath: String
        public var schemaVersion: String

        public init(
            format: ResponseFormat,
            rootPath: String,
            schemaVersion: String
        ) {
            self.format = format
            self.rootPath = rootPath
            self.schemaVersion = schemaVersion
        }
    }

    public struct Behavior: Codable, Sendable {
        public var timeoutSeconds: Int
        public var requiresManualConfirmation: Bool
        public var minConfidenceToAutofill: Double
        public var saveRequestLog: Bool
        public var saveResponseLog: Bool

        public init(
            timeoutSeconds: Int,
            requiresManualConfirmation: Bool,
            minConfidenceToAutofill: Double,
            saveRequestLog: Bool,
            saveResponseLog: Bool
        ) {
            self.timeoutSeconds = timeoutSeconds
            self.requiresManualConfirmation = requiresManualConfirmation
            self.minConfidenceToAutofill = minConfidenceToAutofill
            self.saveRequestLog = saveRequestLog
            self.saveResponseLog = saveResponseLog
        }
    }

    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var endpoint: URL
    public var method: HTTPMethod
    public var headers: [String: String]
    public var request: RequestTemplate
    public var response: ResponseTemplate
    public var behavior: Behavior

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool,
        endpoint: URL,
        method: HTTPMethod,
        headers: [String: String],
        request: RequestTemplate,
        response: ResponseTemplate,
        behavior: Behavior
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.endpoint = endpoint
        self.method = method
        self.headers = headers
        self.request = request
        self.response = response
        self.behavior = behavior
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        endpoint = try container.decode(URL.self, forKey: .endpoint)
        method = try container.decode(HTTPMethod.self, forKey: .method)
        headers = try container.decode([String: String].self, forKey: .headers)
        request = try container.decode(RequestTemplate.self, forKey: .request)
        response = try container.decode(ResponseTemplate.self, forKey: .response)
        behavior = try container.decode(Behavior.self, forKey: .behavior)
    }
}

public struct MealAIResponse: Codable, Sendable {
    public struct FoodItem: Codable, Identifiable, Sendable {
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

    public var mealType: String
    public var foodItems: [FoodItem]
    public var estimatedTotalCalories: Int
    public var confidence: Double
    public var notes: String?

    public init(
        mealType: String,
        foodItems: [FoodItem],
        estimatedTotalCalories: Int,
        confidence: Double,
        notes: String? = nil
    ) {
        self.mealType = mealType
        self.foodItems = foodItems
        self.estimatedTotalCalories = estimatedTotalCalories
        self.confidence = confidence
        self.notes = notes
    }
}
