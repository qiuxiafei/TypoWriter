import Foundation

/// 调试日志管理器
public class DebugLogger {
    public static let shared = DebugLogger()

    /// 调试模式是否启用
    public var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                log("调试模式已启用")
            }
        }
    }

    /// 日志文件路径
    public var logFilePath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.config/bvi/debug.log"
    }

    private let dateFormatter: DateFormatter
    private let fileManager = FileManager.default

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    // MARK: - 公共日志方法

    /// 记录语音识别结果
    public func logTranscription(_ text: String) {
        guard isEnabled else { return }
        log("""
            ═══════════════════════════════════════════════════════════════
            [语音识别结果]
            \(text)
            """)
    }

    /// 记录文本处理输入
    public func logTextProcessingInput(rawText: String, prompt: String) {
        guard isEnabled else { return }
        log("""
            ═══════════════════════════════════════════════════════════════
            [文本处理输入]
            ───────────────────────────────────────────────────────────────
            原始文本:
            \(rawText)
            ───────────────────────────────────────────────────────────────
            完整 Prompt:
            \(prompt)
            """)
    }

    /// 记录文本处理输出
    public func logTextProcessingOutput(_ text: String) {
        guard isEnabled else { return }
        log("""
            ───────────────────────────────────────────────────────────────
            [文本处理输出]
            \(text)
            ═══════════════════════════════════════════════════════════════
            """)
    }

    /// 记录错误
    public func logError(_ error: Error, context: String) {
        guard isEnabled else { return }
        log("""
            ⚠️ [错误] \(context)
            \(error.localizedDescription)
            """)
    }

    // MARK: - 私有方法

    private func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"

        // 打印到控制台
        print(logMessage)

        // 写入文件
        appendToFile(logMessage)
    }

    private func appendToFile(_ message: String) {
        let path = logFilePath
        let directory = (path as NSString).deletingLastPathComponent

        // 确保目录存在
        if !fileManager.fileExists(atPath: directory) {
            try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }

        // 追加写入
        if fileManager.fileExists(atPath: path) {
            if let fileHandle = FileHandle(forWritingAtPath: path) {
                defer { try? fileHandle.close() }
                fileHandle.seekToEndOfFile()
                if let data = message.data(using: .utf8) {
                    fileHandle.write(data)
                }
            }
        } else {
            try? message.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    /// 清空日志文件
    public func clearLog() {
        try? fileManager.removeItem(atPath: logFilePath)
        if isEnabled {
            log("日志已清空")
        }
    }

    /// 确保日志文件存在（如果不存在则创建）
    public func ensureLogFileExists() {
        if !fileManager.fileExists(atPath: logFilePath) {
            let directory = (logFilePath as NSString).deletingLastPathComponent
            try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try? "".write(toFile: logFilePath, atomically: true, encoding: .utf8)
        }
    }
}
