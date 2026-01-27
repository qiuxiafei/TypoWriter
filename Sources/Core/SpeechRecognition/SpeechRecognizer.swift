import Foundation

// MARK: - 语音识别协议

public protocol SpeechRecognizing {
    func transcribe(audio: Data) async throws -> TranscriptionResult
}

// MARK: - 语音识别器工厂

public class SpeechRecognizerFactory {
    public static func create(config: SpeechRecognitionConfig) -> SpeechRecognizing {
        let resolvedConfig = config.resolve()
        return AliyunASR(config: resolvedConfig)
    }
}
