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
        return "\(homeDir)/.config/tw/debug.log"
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

    /// 记录文本改写输入
    public func logRewriteInput(originalText: String, instruction: String, prompt: String) {
        guard isEnabled else { return }
        log("""
            ═══════════════════════════════════════════════════════════════
            [文本改写输入]
            ───────────────────────────────────────────────────────────────
            原始文本:
            \(originalText)
            ───────────────────────────────────────────────────────────────
            改写指令:
            \(instruction)
            ───────────────────────────────────────────────────────────────
            完整 Prompt:
            \(prompt)
            """)
    }

    /// 记录文本改写输出
    public func logRewriteOutput(_ text: String) {
        guard isEnabled else { return }
        log("""
            ───────────────────────────────────────────────────────────────
            [文本改写输出]
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

    /// 记录文本选择检查（用于调试 Accessibility API）
    public func logSelectionCheck(
        appName: String,
        focusResult: Int32?,
        textResult: Int32?,
        selectedText: String?,
        note: String?
    ) {
        guard isEnabled else { return }

        let focusResultStr = focusResult.map { axErrorDescription($0) } ?? "N/A"
        let textResultStr = textResult.map { axErrorDescription($0) } ?? "N/A"
        let textPreview = selectedText.map { text in
            text.count > 50 ? String(text.prefix(50)) + "..." : text
        } ?? "nil"

        log("""
            ───────────────────────────────────────────────────────────────
            [文本选择检查]
            应用: \(appName)
            焦点元素获取: \(focusResultStr)
            选中文本获取: \(textResultStr)
            选中文本: \(textPreview)
            备注: \(note ?? "无")
            """)
    }

    /// AXError 错误码描述
    private func axErrorDescription(_ error: Int32) -> String {
        switch error {
        case 0: return "success (0)"
        case -25200: return "failure (-25200)"
        case -25201: return "illegalArgument (-25201)"
        case -25202: return "invalidUIElement (-25202)"
        case -25203: return "invalidUIElementObserver (-25203)"
        case -25204: return "cannotComplete (-25204)"
        case -25205: return "attributeUnsupported (-25205)"
        case -25206: return "actionUnsupported (-25206)"
        case -25207: return "notificationUnsupported (-25207)"
        case -25208: return "notImplemented (-25208)"
        case -25209: return "notificationAlreadyRegistered (-25209)"
        case -25210: return "notificationNotRegistered (-25210)"
        case -25211: return "apiDisabled (-25211)"
        case -25212: return "noValue (-25212)"
        case -25213: return "parameterizedAttributeUnsupported (-25213)"
        case -25214: return "notEnoughPrecision (-25214)"
        default: return "unknown (\(error))"
        }
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
