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

public struct ProviderConfig: Codable, Identifiable, Sendable {
    public struct RequestTemplate: Codable, Sendable {
        public var model: String
        public var temperature: Double
        public var systemPrompt: String
        public var userTemplate: String
        public var imageFieldMode: ImageFieldMode
        public var bodyTemplate: String?

        public init(
            model: String,
            temperature: Double,
            systemPrompt: String,
            userTemplate: String,
            imageFieldMode: ImageFieldMode,
            bodyTemplate: String? = nil
        ) {
            self.model = model
            self.temperature = temperature
            self.systemPrompt = systemPrompt
            self.userTemplate = userTemplate
            self.imageFieldMode = imageFieldMode
            self.bodyTemplate = bodyTemplate
        }
    }

    public struct ResponseTemplate: Codable, Sendable {
        public var format: ResponseFormat
        public var rootPath: String
        public var schemaVersion: String

        public init(format: ResponseFormat, rootPath: String, schemaVersion: String) {
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
