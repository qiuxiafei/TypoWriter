import Foundation

// MARK: - 文本处理协议

public protocol TextProcessing {
    /// 处理语音识别文本（优化口语表达）
    func process(rawText: String, customPrompt: String?) async throws -> ProcessedResult

    /// 改写文本（根据用户指令）
    func rewrite(originalText: String, instruction: String, customPrompt: String?) async throws -> ProcessedResult
}

// MARK: - 文本处理器工厂

public class TextProcessorFactory {
    public static func create(config: TextProcessingConfig) -> TextProcessing {
        let resolvedConfig = config.resolve()
        return OpenAICompatibleProcessor(config: resolvedConfig)
    }
}
