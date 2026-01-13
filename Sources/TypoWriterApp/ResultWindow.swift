import AppKit
import SwiftUI

/// 结果显示窗口
class ResultWindow {
    static let shared = ResultWindow()

    private var window: NSWindow?
    private var currentText: String = ""

    private init() {}

    func show(text: String) {
        currentText = text

        // 如果窗口已存在，更新内容
        if let window = window {
            if let hostingView = window.contentView as? NSHostingView<ResultWindowView> {
                hostingView.rootView = ResultWindowView(text: text, onCopy: copyText, onClose: close)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 创建新窗口
        let contentView = NSHostingView(rootView: ResultWindowView(text: text, onCopy: copyText, onClose: close))

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = contentView
        newWindow.title = "语音识别结果"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentText, forType: .string)
    }

    private func close() {
        window?.close()
    }
}

struct ResultWindowView: View {
    let text: String
    let onCopy: () -> Void
    let onClose: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            // 文本内容
            ScrollView {
                Text(text)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)

            // 按钮
            HStack {
                Spacer()

                Button(action: {
                    onCopy()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                }) {
                    HStack {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "已复制" : "复制")
                    }
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("关闭", action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
    }
}

/// Toast 提示窗口（自动消失）
class ToastWindow {
    static let shared = ToastWindow()

    private var window: NSPanel?

    private init() {}

    func show(message: String, duration: TimeInterval = 2.0) {
        // 关闭现有窗口
        window?.close()

        let contentView = NSHostingView(rootView: ToastView(message: message))
        contentView.frame = NSRect(x: 0, y: 0, width: 200, height: 40)

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
            let y = screenFrame.maxY - 150
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        window = panel

        // 自动关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.75))
            )
    }
}
