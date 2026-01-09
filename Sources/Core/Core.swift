// Core 模块
// 统一导出所有核心功能

import Foundation

/// Better Voice Input 核心处理流程
public class BVICore {
    private let config: Config
    private let audioRecorder: AudioRecording
    private let speechRecognizer: SpeechRecognizing
    private let textProcessor: TextProcessing

    public init(config: Config) {
        self.config = config
        self.audioRecorder = AudioRecorder()
        self.speechRecognizer = SpeechRecognizerFactory.create(config: config.speechRecognition)
        self.textProcessor = TextProcessorFactory.create(config: config.textProcessing)
    }

    /// 开始录音
    public func startRecording() async throws {
        try await audioRecorder.startRecording()
    }

    /// 停止录音并处理
    public func stopAndProcess() async throws -> FullProcessingResult {
        // 1. 停止录音，获取音频数据
        let audioData = try await audioRecorder.stopRecording()

        // 2. 语音识别
        let transcription = try await speechRecognizer.transcribe(audio: audioData)

        // 3. 文本处理
        let options = ProcessingOptions(preserveStyle: config.processing.preserveStyle)
        let result = try await textProcessor.process(rawText: transcription.text, options: options)

        return FullProcessingResult(
            transcription: transcription.text,
            llmPrompt: result.prompt ?? "",
            processedText: result.text
        )
    }

    /// 是否正在录音
    public var isRecording: Bool {
        audioRecorder.isRecording
    }
}
