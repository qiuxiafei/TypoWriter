import Foundation
import Yams

// MARK: - 配置结构

public struct Config: Codable {
    public var speechRecognition: SpeechRecognitionConfig
    public var textProcessing: TextProcessingConfig
    public var processing: ProcessingConfig

    public init(
        speechRecognition: SpeechRecognitionConfig = .init(),
        textProcessing: TextProcessingConfig = .init(),
        processing: ProcessingConfig = .init()
    ) {
        self.speechRecognition = speechRecognition
        self.textProcessing = textProcessing
        self.processing = processing
    }

    enum CodingKeys: String, CodingKey {
        case speechRecognition = "speech_recognition"
        case textProcessing = "text_processing"
        case processing
    }
}

public struct SpeechRecognitionConfig: Codable {
    public var provider: SpeechProvider
    public var aliyun: AliyunConfig?

    public init(
        provider: SpeechProvider = .aliyun,
        aliyun: AliyunConfig? = nil
    ) {
        self.provider = provider
        self.aliyun = aliyun
    }
}

public enum SpeechProvider: String, Codable {
    case aliyun
    case openai
    case apple
}

public struct AliyunConfig: Codable {
    public var apiKey: String
    public var model: String

    public init(apiKey: String = "", model: String = "qwen3-asr-flash") {
        self.apiKey = apiKey
        self.model = model
    }

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case model
    }
}

public struct TextProcessingConfig: Codable {
    public var baseUrl: String
    public var apiKey: String
    public var model: String

    public init(
        baseUrl: String = "https://api.openai.com/v1",
        apiKey: String = "",
        model: String = "gpt-4o"
    ) {
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.model = model
    }

    enum CodingKeys: String, CodingKey {
        case baseUrl = "base_url"
        case apiKey = "api_key"
        case model
    }
}

public struct ProcessingConfig: Codable {
    public var preserveStyle: Bool

    public init(preserveStyle: Bool = true) {
        self.preserveStyle = preserveStyle
    }

    enum CodingKeys: String, CodingKey {
        case preserveStyle = "preserve_style"
    }
}

// MARK: - 配置加载器

public class ConfigLoader {
    public static let shared = ConfigLoader()

    private init() {}

    /// 默认配置文件路径
    public var defaultConfigPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.config/bvi/config.yaml"
    }

    /// 加载配置文件
    public func load(from path: String? = nil) throws -> Config {
        let configPath = path ?? defaultConfigPath

        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw BVIError.configNotFound(configPath)
        }

        // 读取文件内容
        let content = try String(contentsOfFile: configPath, encoding: .utf8)

        // 替换环境变量
        let expandedContent = expandEnvironmentVariables(in: content)

        // 解析 YAML
        do {
            let decoder = YAMLDecoder()
            var config = try decoder.decode(Config.self, from: expandedContent)

            // 确保 API Key 已配置
            validateConfig(&config)

            return config
        } catch {
            throw BVIError.configParseError(error.localizedDescription)
        }
    }

    /// 展开环境变量 ${VAR_NAME}
    private func expandEnvironmentVariables(in content: String) -> String {
        var result = content
        let pattern = #"\$\{([A-Za-z_][A-Za-z0-9_]*)\}"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return content
        }

        let matches = regex.matches(
            in: content,
            range: NSRange(content.startIndex..., in: content)
        )

        // 从后往前替换，避免位置偏移
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: content),
                  let varNameRange = Range(match.range(at: 1), in: content) else {
                continue
            }

            let varName = String(content[varNameRange])
            let value = ProcessInfo.processInfo.environment[varName] ?? ""
            result.replaceSubrange(fullRange, with: value)
        }

        return result
    }

    /// 验证配置
    private func validateConfig(_ config: inout Config) {
        // 可以在这里添加配置验证逻辑
    }

    /// 创建示例配置文件
    public func createExampleConfig(at path: String) throws {
        let exampleContent = """
        # Better Voice Input 配置文件

        speech_recognition:
          provider: aliyun  # aliyun | openai | apple
          aliyun:
            api_key: ${DASHSCOPE_API_KEY}
            model: qwen3-asr-flash

        text_processing:
          # OpenAI 兼容格式，支持 OpenAI、Claude、Ollama、DeepSeek 等
          base_url: https://api.openai.com/v1
          api_key: ${OPENAI_API_KEY}
          model: gpt-4o

        processing:
          preserve_style: true
        """

        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        try exampleContent.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
