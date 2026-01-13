import AppKit
import SwiftUI
import Core

/// 错误展示管理器
/// 提供统一的错误展示接口，支持多种展示方式
class ErrorPresenter {
    static let shared = ErrorPresenter()

    private init() {}

    /// 错误严重程度
    enum Severity {
        case info       // 信息提示
        case warning    // 警告
        case error      // 错误
        case critical   // 严重错误
    }

    /// 展示错误 Toast（自动消失）
    func showToast(_ message: String, severity: Severity = .info, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            ErrorToastWindow.shared.show(
                message: message,
                severity: severity,
                duration: duration
            )
        }
    }

    /// 展示错误 Alert（需要用户确认）
    func showAlert(
        title: String,
        message: String,
        severity: Severity = .error,
        primaryButton: String = "确定",
        secondaryButton: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message

            switch severity {
            case .info:
                alert.alertStyle = .informational
            case .warning:
                alert.alertStyle = .warning
            case .error, .critical:
                alert.alertStyle = .critical
            }

            alert.addButton(withTitle: primaryButton)
            if let secondary = secondaryButton {
                alert.addButton(withTitle: secondary)
            }

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                primaryAction?()
            } else if response == .alertSecondButtonReturn {
                secondaryAction?()
            }
        }
    }

    /// 展示 TWError
    func showTWError(_ error: TWError, context: String? = nil) {
        DebugLogger.shared.logError(error, context: context ?? "TWError")
        let (_, message, severity) = analyzeTWError(error, context: context)
        let duration: TimeInterval = severity == .critical ? 6.0 : 4.0
        showToast(message, severity: severity, duration: duration)
    }

    /// 展示通用错误
    func showError(_ error: Error, context: String) {
        DebugLogger.shared.logError(error, context: context)
        let message = "[\(context)] \(error.localizedDescription)"
        showToast(message, severity: .error, duration: 4.0)
    }

    /// 分析 TWError 并返回适当的展示信息
    private func analyzeTWError(_ error: TWError, context: String?) -> (title: String, message: String, severity: Severity) {
        let contextPrefix = context.map { "[\($0)] " } ?? ""

        switch error {
        case .configNotFound(let path):
            return (
                "配置文件未找到",
                "\(contextPrefix)配置文件不存在：\(path)\n\n请创建配置文件后重试。",
                .critical
            )

        case .configParseError(let message):
            return (
                "配置解析错误",
                "\(contextPrefix)配置文件格式有误：\(message)\n\n请检查配置文件的 YAML 语法。",
                .error
            )

        case .audioRecordingFailed(let message):
            if message.contains("权限") {
                return (
                    "麦克风权限不足",
                    "\(contextPrefix)\(message)\n\n请在「系统设置 > 隐私与安全性 > 麦克风」中允许本应用访问麦克风。",
                    .critical
                )
            }
            return (
                "录音失败",
                "\(contextPrefix)\(message)",
                .error
            )

        case .speechRecognitionFailed(let message):
            if message.contains("API") || message.contains("key") || message.contains("Key") || message.contains("401") {
                return (
                    "语音识别 API 错误",
                    "\(contextPrefix)\(message)\n\n请检查语音识别 API Key 是否正确配置。",
                    .error
                )
            }
            return (
                "语音识别失败",
                "\(contextPrefix)\(message)",
                .warning
            )

        case .textProcessingFailed(let message):
            if message.contains("API") || message.contains("key") || message.contains("Key") || message.contains("401") {
                return (
                    "文本处理 API 错误",
                    "\(contextPrefix)\(message)\n\n请检查文本处理 API Key 是否正确配置。",
                    .error
                )
            }
            return (
                "文本处理失败",
                "\(contextPrefix)\(message)",
                .warning
            )

        case .rewriteFailed(let message):
            if message.contains("API") || message.contains("key") || message.contains("Key") || message.contains("401") {
                return (
                    "文本改写 API 错误",
                    "\(contextPrefix)\(message)\n\n请检查文本处理 API Key 是否正确配置。",
                    .error
                )
            }
            return (
                "文本改写失败",
                "\(contextPrefix)\(message)",
                .warning
            )

        case .noTextSelected:
            return (
                "没有选中文本",
                "\(contextPrefix)请先选中要改写的文本，再使用语音改写功能。",
                .info
            )

        case .networkError(let message):
            return (
                "网络错误",
                "\(contextPrefix)\(message)\n\n请检查网络连接后重试。",
                .warning
            )

        case .invalidResponse(let message):
            return (
                "服务响应异常",
                "\(contextPrefix)\(message)\n\n请稍后重试，如问题持续请检查 API 配置。",
                .warning
            )
        }
    }
}

// MARK: - 增强版 Toast 窗口

class ErrorToastWindow {
    static let shared = ErrorToastWindow()

    private var window: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    func show(message: String, severity: ErrorPresenter.Severity, duration: TimeInterval) {
        // 取消之前的隐藏任务
        hideWorkItem?.cancel()

        // 关闭现有窗口
        window?.close()

        let contentView = NSHostingView(
            rootView: ErrorToastView(message: message, severity: severity)
        )

        // 根据消息长度动态调整宽度
        let width = min(max(CGFloat(message.count * 14 + 80), 200), 450)
        contentView.frame = NSRect(x: 0, y: 0, width: width, height: 50)

        let panel = NSPanel(
            contentRect: contentView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true

        // 定位到屏幕中央偏上
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - contentView.frame.width / 2
            let y = screenFrame.maxY - 120
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        window = panel

        // 设置自动隐藏
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    func hide() {
        window?.animator().alphaValue = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
    }
}

struct ErrorToastView: View {
    let message: String
    let severity: ErrorPresenter.Severity

    private var backgroundColor: Color {
        switch severity {
        case .info:
            return Color.black.opacity(0.8)
        case .warning:
            return Color.orange.opacity(0.9)
        case .error:
            return Color.red.opacity(0.85)
        case .critical:
            return Color.red
        }
    }

    private var icon: String {
        switch severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
    }
}
