import Foundation

// MARK: - 语音识别结果

public struct TranscriptionResult {
    public let text: String
    public let segments: [TranscriptionSegment]?
    public let language: String?

    public init(text: String, segments: [TranscriptionSegment]? = nil, language: String? = nil) {
        self.text = text
        self.segments = segments
        self.language = language
    }
}

public struct TranscriptionSegment {
    public let text: String
    public let startTime: Double
    public let endTime: Double

    public init(text: String, startTime: Double, endTime: Double) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - 文本处理结果

public struct ProcessedResult {
    public let text: String
    public let prompt: String?  // LLM 的完整输入 prompt

    public init(text: String, prompt: String? = nil) {
        self.text = text
        self.prompt = prompt
    }
}

// MARK: - 完整处理结果（包含中间步骤）

public struct FullProcessingResult {
    public let transcription: String      // 语音识别原文
    public let llmPrompt: String          // LLM 输入 prompt
    public let processedText: String      // LLM 输出结果

    public init(transcription: String, llmPrompt: String, processedText: String) {
        self.transcription = transcription
        self.llmPrompt = llmPrompt
        self.processedText = processedText
    }
}

// MARK: - 处理选项

public struct ProcessingOptions {
    public var preserveStyle: Bool

    public init(preserveStyle: Bool = true) {
        self.preserveStyle = preserveStyle
    }
}

// MARK: - 错误类型

public enum BVIError: Error, LocalizedError {
    case configNotFound(String)
    case configParseError(String)
    case audioRecordingFailed(String)
    case speechRecognitionFailed(String)
    case textProcessingFailed(String)
    case networkError(String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .configNotFound(let path):
            return "配置文件未找到: \(path)"
        case .configParseError(let message):
            return "配置解析错误: \(message)"
        case .audioRecordingFailed(let message):
            return "录音失败: \(message)"
        case .speechRecognitionFailed(let message):
            return "语音识别失败: \(message)"
        case .textProcessingFailed(let message):
            return "文本处理失败: \(message)"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .invalidResponse(let message):
            return "无效响应: \(message)"
        }
    }
}
