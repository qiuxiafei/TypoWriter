import AppKit
import Carbon

/// 文本输入模拟器
/// 将文本输入到当前活跃窗口
class TextInputSimulator {
    static let shared = TextInputSimulator()

    private init() {}

    /// 尝试将文本输入到当前活跃窗口
    /// - Returns: 是否成功
    func typeText(_ text: String) -> Bool {
        // 方案：使用剪贴板 + 模拟 Cmd+V
        // 保存原来的剪贴板内容
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)

        // 设置新内容
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 模拟 Cmd+V
        let success = simulatePaste()

        // 延迟恢复剪贴板（给系统时间完成粘贴）
        if let previous = previousContent {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }

        return success
    }

    private func simulatePaste() -> Bool {
        // 创建 Cmd 按下事件
        guard let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: true) else {
            return false
        }
        cmdDown.flags = .maskCommand

        // 创建 V 按下事件
        guard let vDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) else {
            return false
        }
        vDown.flags = .maskCommand

        // 创建 V 松开事件
        guard let vUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            return false
        }
        vUp.flags = .maskCommand

        // 创建 Cmd 松开事件
        guard let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: false) else {
            return false
        }

        // 发送事件
        let location = CGEventTapLocation.cghidEventTap
        cmdDown.post(tap: location)
        vDown.post(tap: location)
        vUp.post(tap: location)
        cmdUp.post(tap: location)

        return true
    }
}
