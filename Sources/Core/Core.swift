// Core 模块
// 统一导出所有核心功能

import Foundation

/// 处理阶段
public enum BVIProcessingPhase {
    case stoppingRecording   // 停止录音
    case transcribing        // 语音转文字
    case processing          // 文本优化
    case rewriting           // 文本改写
}

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

    /// 停止录音并处理（带进度回调）
    /// - Parameter onPhaseChange: 阶段变化回调
    /// - Returns: 完整处理结果
    public func stopAndProcess(
        onPhaseChange: ((BVIProcessingPhase) -> Void)? = nil
    ) async throws -> FullProcessingResult {
        // 1. 停止录音，获取音频数据
        onPhaseChange?(.stoppingRecording)
        let audioData = try await audioRecorder.stopRecording()

        // 2. 语音识别
        onPhaseChange?(.transcribing)
        let transcription = try await speechRecognizer.transcribe(audio: audioData)

        // 记录语音识别结果
        DebugLogger.shared.logTranscription(transcription.text)

        // 3. 文本处理
        onPhaseChange?(.processing)
        let result = try await textProcessor.process(rawText: transcription.text, customPrompt: config.processing.prompt)

        // 记录文本处理输出
        DebugLogger.shared.logTextProcessingOutput(result.text)

        return FullProcessingResult(
            transcription: transcription.text,
            llmPrompt: result.prompt ?? "",
            processedText: result.text
        )
    }

    /// 停止录音并执行文本改写
    /// - Parameters:
    ///   - originalText: 待改写的原始文本
    ///   - onPhaseChange: 阶段变化回调
    /// - Returns: 完整改写结果
    public func stopAndRewrite(
        originalText: String,
        onPhaseChange: ((BVIProcessingPhase) -> Void)? = nil
    ) async throws -> FullRewriteResult {
        // 1. 停止录音，获取音频数据
        onPhaseChange?(.stoppingRecording)
        let audioData = try await audioRecorder.stopRecording()

        // 2. 语音识别（将用户指令转为文本）
        onPhaseChange?(.transcribing)
        let transcription = try await speechRecognizer.transcribe(audio: audioData)

        // 记录语音识别结果
        DebugLogger.shared.logTranscription(transcription.text)

        // 3. 执行文本改写
        onPhaseChange?(.rewriting)
        let result = try await textProcessor.rewrite(
            originalText: originalText,
            instruction: transcription.text
        )

        // 记录改写输出
        DebugLogger.shared.logRewriteOutput(result.text)

        return FullRewriteResult(
            originalText: originalText,
            instruction: transcription.text,
            llmPrompt: result.prompt ?? "",
            rewrittenText: result.text
        )
    }

    /// 是否正在录音
    public var isRecording: Bool {
        audioRecorder.isRecording
    }
}
