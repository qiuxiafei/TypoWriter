import AVFoundation
import Foundation

// MARK: - 音频录制协议

public protocol AudioRecording {
    func startRecording() async throws
    func stopRecording() async throws -> Data
    var isRecording: Bool { get }
}

// MARK: - 音频录制器

public class AudioRecorder: NSObject, AudioRecording {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?
    private var recordingData: Data?

    private var _isRecording = false
    public var isRecording: Bool { _isRecording }

    private let audioBufferQueue = DispatchQueue(label: "com.tw.audiobuffer")
    private var audioBuffers: [AVAudioPCMBuffer] = []

    public override init() {
        super.init()
    }

    public func startRecording() async throws {
        guard !_isRecording else { return }

        // 请求麦克风权限
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw TWError.audioRecordingFailed("麦克风权限被拒绝")
        }

        // 创建临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "tw_recording_\(UUID().uuidString).wav"
        tempFileURL = tempDir.appendingPathComponent(fileName)

        // 设置音频引擎
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw TWError.audioRecordingFailed("无法创建音频引擎")
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // 验证音频格式
        guard recordingFormat.sampleRate > 0 else {
            throw TWError.audioRecordingFailed("无效的音频格式")
        }

        // 创建音频文件
        guard let fileURL = tempFileURL else {
            throw TWError.audioRecordingFailed("无法创建临时文件")
        }

        // 使用 16kHz 16-bit PCM 格式（兼容大多数 ASR 服务）
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: outputSettings
            )
        } catch {
            throw TWError.audioRecordingFailed("无法创建音频文件: \(error.localizedDescription)")
        }

        // 安装音频 tap
        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        // 启动音频引擎
        do {
            try audioEngine.start()
            _isRecording = true
        } catch {
            throw TWError.audioRecordingFailed("无法启动音频引擎: \(error.localizedDescription)")
        }
    }

    public func stopRecording() async throws -> Data {
        guard _isRecording else {
            throw TWError.audioRecordingFailed("未在录音中")
        }

        // 停止音频引擎
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        _isRecording = false

        // 关闭音频文件
        audioFile = nil

        // 读取录音数据
        guard let fileURL = tempFileURL else {
            throw TWError.audioRecordingFailed("录音文件不存在")
        }

        do {
            let data = try Data(contentsOf: fileURL)

            // 清理临时文件
            try? FileManager.default.removeItem(at: fileURL)
            tempFileURL = nil

            return data
        } catch {
            throw TWError.audioRecordingFailed("无法读取录音文件: \(error.localizedDescription)")
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let audioFile = audioFile else { return }

        // 转换为目标格式
        guard let convertedBuffer = convertBuffer(buffer, to: audioFile.processingFormat) else {
            return
        }

        do {
            try audioFile.write(from: convertedBuffer)
        } catch {
            print("写入音频数据失败: \(error)")
        }
    }

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCapacity) else {
            return nil
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("音频转换失败: \(error)")
            return nil
        }

        return outputBuffer
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
