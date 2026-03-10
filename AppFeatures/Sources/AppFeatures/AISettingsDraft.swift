import Foundation

public struct AISettingsDraft: Sendable {
    public var rawJSON: String

    public init(rawJSON: String) {
        self.rawJSON = rawJSON
    }

    public func validate() throws -> ProviderConfig {
        let data = try Self.normalizedData(from: rawJSON)
        let config = try JSONDecoder().decode(ProviderConfig.self, from: data)
        try Self.validateSemantic(config)
        return config
    }

    private static func normalizedData(from rawJSON: String) throws -> Data {
        guard let data = rawJSON.data(using: .utf8) else {
            throw ValidationError.invalidEncoding
        }
        return data
    }

    private static func validateSemantic(_ config: ProviderConfig) throws {
        if let host = config.endpoint.host?.lowercased(), host.contains("example.com") {
            throw ValidationError.placeholderEndpoint
        }

        if config.headers.values.contains(where: { $0.contains("REPLACE_ME") }) {
            throw ValidationError.placeholderAuthorization
        }

        if config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyField("配置名称")
        }

        if config.request.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyField("模型名称")
        }

        if config.response.rootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyField("返回路径")
        }
    }
}

public extension AISettingsDraft {
    enum ValidationError: LocalizedError {
        case invalidEncoding
        case placeholderEndpoint
        case placeholderAuthorization
        case emptyField(String)

        public var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "配置文本不是有效的 UTF-8 内容。"
            case .placeholderEndpoint:
                return "请把示例接口地址替换成你自己的真实地址。"
            case .placeholderAuthorization:
                return "请把示例密钥替换成你自己的真实密钥。"
            case .emptyField(let fieldName):
                return "\(fieldName)不能为空。"
            }
        }
    }
}
