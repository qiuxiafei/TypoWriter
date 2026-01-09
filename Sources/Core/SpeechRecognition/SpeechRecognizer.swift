import Foundation

// MARK: - 语音识别协议

public protocol SpeechRecognizing {
    func transcribe(audio: Data) async throws -> TranscriptionResult
}

// MARK: - 语音识别器工厂

public class SpeechRecognizerFactory {
    public static func create(config: SpeechRecognitionConfig) -> SpeechRecognizing {
        switch config.provider {
        case .aliyun:
            return AliyunASR(config: config.aliyun ?? AliyunConfig())
        case .openai:
            fatalError("OpenAI Whisper 暂未实现")
        case .apple:
            fatalError("Apple Speech 暂未实现")
        }
    }
}
