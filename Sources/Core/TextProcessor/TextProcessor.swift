import Foundation

// MARK: - 文本处理协议

public protocol TextProcessing {
    func process(rawText: String, customPrompt: String?) async throws -> ProcessedResult
}

// MARK: - 文本处理器工厂

public class TextProcessorFactory {
    public static func create(config: TextProcessingConfig) -> TextProcessing {
        return OpenAICompatibleProcessor(config: config)
    }
}
