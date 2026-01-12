import AppKit
import ApplicationServices
import Carbon
import Core

/// 文本选择助手
/// 用于获取当前选中的文本和替换选中文本
class TextSelectionHelper {
    static let shared = TextSelectionHelper()

    private init() {}

    /// 获取当前选中的文本
    /// 优先使用 Accessibility API，失败则使用剪贴板方案
    func getSelectedText() -> String? {
        // 方案一：Accessibility API
        if let text = getSelectedTextViaAccessibility() {
            return text
        }

        // 方案二：剪贴板方案（兜底）
        return getSelectedTextViaClipboard()
    }

    // MARK: - 方案一：Accessibility API（含递归遍历）

    private func getSelectedTextViaAccessibility() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            DebugLogger.shared.logSelectionCheck(
                appName: "未知",
                focusResult: nil,
                textResult: nil,
                selectedText: nil,
                note: "[Accessibility] 无法获取前台应用"
            )
            return nil
        }

        let appName = frontApp.localizedName ?? frontApp.bundleIdentifier ?? "未知应用"
        let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)

        // 获取焦点元素
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            appRef,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            DebugLogger.shared.logSelectionCheck(
                appName: appName,
                focusResult: focusResult.rawValue,
                textResult: nil,
                selectedText: nil,
                note: "[Accessibility] 无法获取焦点元素"
            )
            return nil
        }

        let axElement = element as! AXUIElement
        let role = getRoleOfElement(axElement)

        // 先尝试直接从焦点元素获取
        let (directText, directError) = getSelectedTextFromElement(axElement)
        if let text = directText {
            DebugLogger.shared.logSelectionCheck(
                appName: appName,
                focusResult: focusResult.rawValue,
                textResult: directError,
                selectedText: text,
                note: "[Accessibility] 直接获取成功，元素角色: \(role)"
            )
            return text
        }

        // 记录直接获取失败的原因
        DebugLogger.shared.logSelectionCheck(
            appName: appName,
            focusResult: focusResult.rawValue,
            textResult: directError,
            selectedText: nil,
            note: "[Accessibility] 直接获取失败，元素角色: \(role)，尝试递归遍历..."
        )

        // 递归遍历子元素查找
        if let text = findSelectedTextInChildren(of: axElement, depth: 0, maxDepth: 10) {
            DebugLogger.shared.logSelectionCheck(
                appName: appName,
                focusResult: focusResult.rawValue,
                textResult: 0,
                selectedText: text,
                note: "[Accessibility] 递归遍历获取成功"
            )
            return text
        }

        DebugLogger.shared.logSelectionCheck(
            appName: appName,
            focusResult: focusResult.rawValue,
            textResult: nil,
            selectedText: nil,
            note: "[Accessibility] 递归遍历也未找到选中文本"
        )
        return nil
    }

    /// 从指定元素获取选中文本
    /// - Returns: (选中文本, 错误码) - 文本为 nil 表示失败，错误码用于日志
    private func getSelectedTextFromElement(_ element: AXUIElement) -> (text: String?, errorCode: Int32) {
        var selectedText: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        if result == .success {
            if let text = selectedText as? String, !text.isEmpty {
                return (text, result.rawValue)
            } else {
                // 成功但文本为空
                return (nil, result.rawValue)
            }
        }

        return (nil, result.rawValue)
    }

    /// 递归遍历子元素查找选中文本
    private func findSelectedTextInChildren(of element: AXUIElement, depth: Int, maxDepth: Int) -> String? {
        guard depth < maxDepth else { return nil }

        // 获取子元素
        var children: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &children
        )

        guard result == .success, let childArray = children as? [AXUIElement] else {
            return nil
        }

        for child in childArray {
            // 先尝试直接获取
            let (text, _) = getSelectedTextFromElement(child)
            if let text = text {
                return text
            }

            // 递归查找子元素
            if let text = findSelectedTextInChildren(of: child, depth: depth + 1, maxDepth: maxDepth) {
                return text
            }
        }

        return nil
    }

    /// 获取元素角色
    private func getRoleOfElement(_ element: AXUIElement) -> String {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        return role as? String ?? "未知"
    }

    // MARK: - 方案二：剪贴板方案（Cmd+C）

    private func getSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general

        // 保存原剪贴板内容
        let previousChangeCount = pasteboard.changeCount
        let previousContent = pasteboard.string(forType: .string)

        // 模拟 Cmd+C
        guard simulateCopy() else {
            DebugLogger.shared.logSelectionCheck(
                appName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知",
                focusResult: nil,
                textResult: nil,
                selectedText: nil,
                note: "[剪贴板] 模拟 Cmd+C 失败"
            )
            return nil
        }

        // 等待剪贴板更新（某些应用需要更长时间）
        usleep(100000) // 100ms

        // 检查剪贴板是否有变化
        let newChangeCount = pasteboard.changeCount
        let newContent = pasteboard.string(forType: .string)

        // 恢复原剪贴板内容
        if let previous = previousContent {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }

        // 判断是否获取到新内容
        if newChangeCount != previousChangeCount,
           let text = newContent,
           !text.isEmpty,
           text != previousContent {
            DebugLogger.shared.logSelectionCheck(
                appName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知",
                focusResult: nil,
                textResult: 0,
                selectedText: text,
                note: "[剪贴板] 获取成功"
            )
            return text
        }

        DebugLogger.shared.logSelectionCheck(
            appName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知",
            focusResult: nil,
            textResult: nil,
            selectedText: nil,
            note: "[剪贴板] 未检测到选中文本（剪贴板无变化）"
        )
        return nil
    }

    /// 模拟 Cmd+C
    private func simulateCopy() -> Bool {
        // 使用独立的事件源，避免受当前按键状态影响
        guard let source = CGEventSource(stateID: .privateState) else {
            return false
        }

        // 创建按键事件，明确只设置 Command 修饰键（排除其他修饰键如 Option）
        guard let cDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true) else {
            return false
        }
        // 只设置 Command，确保不包含 Option 等其他修饰键
        cDown.flags = CGEventFlags.maskCommand

        guard let cUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else {
            return false
        }
        cUp.flags = CGEventFlags.maskCommand

        // 发送事件
        let location = CGEventTapLocation.cghidEventTap
        cDown.post(tap: location)
        cUp.post(tap: location)

        return true
    }

    // MARK: - 公共方法

    /// 从剪贴板获取文本
    func getClipboardText() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    /// 替换选中的文本
    /// 使用剪贴板 + Cmd+V 的方式替换
    func replaceSelectedText(with newText: String) -> Bool {
        return TextInputSimulator.shared.typeText(newText)
    }
}
