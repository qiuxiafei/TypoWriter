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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speechRecognition = try container.decode(SpeechRecognitionConfig.self, forKey: .speechRecognition)
        textProcessing = try container.decode(TextProcessingConfig.self, forKey: .textProcessing)
        processing = try container.decodeIfPresent(ProcessingConfig.self, forKey: .processing) ?? .init()
    }

    enum CodingKeys: String, CodingKey {
        case speechRecognition = "speech_recognition"
        case textProcessing = "text_processing"
        case processing
    }
}


public struct APICredentials: Codable {
    public var apiKey: String

    public init(apiKey: String = "") {
        self.apiKey = apiKey
    }

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
    }
}

public enum SpeechRecognitionPreset: String, Codable {
    case dashscopeQwenASR = "dashscope_qwen_asr"

    public var displayName: String {
        switch self {
        case .dashscopeQwenASR:
            return "DashScope - Qwen ASR"
        }
    }
}

public struct SpeechRecognitionConfig: Codable {
    public var preset: SpeechRecognitionPreset
    public var credentials: APICredentials

    public init(
        preset: SpeechRecognitionPreset = .dashscopeQwenASR,
        credentials: APICredentials = .init()
    ) {
        self.preset = preset
        self.credentials = credentials
    }
}

public enum TextProcessingPreset: String, Codable {
    case dashscopeQwenPlus = "dashscope_qwen_plus"

    public var displayName: String {
        switch self {
        case .dashscopeQwenPlus:
            return "DashScope - Qwen Plus"
        }
    }
}

public struct TextProcessingConfig: Codable {
    public var preset: TextProcessingPreset
    public var credentials: APICredentials

    public init(
        preset: TextProcessingPreset = .dashscopeQwenPlus,
        credentials: APICredentials = .init()
    ) {
        self.preset = preset
        self.credentials = credentials
    }
}

public struct ProcessingConfig: Codable {
    public var prompt: String?
    public var rewritePrompt: String?

    public init(prompt: String? = nil, rewritePrompt: String? = nil) {
        self.prompt = prompt
        self.rewritePrompt = rewritePrompt
    }

    enum CodingKeys: String, CodingKey {
        case prompt
        case rewritePrompt = "rewrite_prompt"
    }
}

// MARK: - 配置加载器

public class ConfigLoader {
    public static let shared = ConfigLoader()

    private init() {}

    /// 默认配置文件路径
    public var defaultConfigPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.config/tw/config.yaml"
    }

    /// 加载配置文件
    public func load(from path: String? = nil) throws -> Config {
        let configPath = path ?? defaultConfigPath

        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw TWError.configNotFound(configPath)
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
            throw TWError.configParseError(error.localizedDescription)
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

    /// 保存配置文件
    public func save(_ config: Config, to path: String? = nil) throws {
        let configPath = path ?? defaultConfigPath
        let directory = (configPath as NSString).deletingLastPathComponent

        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        do {
            let encoder = YAMLEncoder()
            let yaml = try encoder.encode(config)
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)
        } catch {
            throw TWError.configParseError("无法保存配置文件: \(error.localizedDescription)")
        }
    }

    /// 创建示例配置文件
    public func createExampleConfig(at path: String) throws {
        let exampleContent = """
        # TypoWriter 配置文件

        speech_recognition:
          preset: dashscope_qwen_asr
          credentials:
            api_key: ${DASHSCOPE_API_KEY}

        text_processing:
          preset: dashscope_qwen_plus
          credentials:
            api_key: ${DASHSCOPE_API_KEY}

        # 可选：自定义文本处理 prompt
        # processing:
        #   prompt: |
        #     你是一个专业的打字员，任务是将口述内容整理成书面文字。
        #     规则：
        #     1. 去除口语化表达
        #     2. 识别并合并修改意图
        #     3. 保持原有的语义和说话风格
        #   rewrite_prompt: |
        #     你是一个智能文本改写助手。
        #     规则：根据用户指令改写，保持原文风格。
        """

        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        try exampleContent.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
