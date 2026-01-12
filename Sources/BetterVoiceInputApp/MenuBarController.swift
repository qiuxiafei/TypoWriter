import AppKit
import Core

class MenuBarController {
    private var statusItem: NSStatusItem?
    private var isEnabled = true
    private let launchAtLoginManager = LaunchAtLoginManager.shared

    init() {
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "teletype.answer", accessibilityDescription: "Better Voice Input")
            button.image?.isTemplate = true
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // 启用/禁用
        let enableItem = NSMenuItem(title: "启用", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        enableItem.target = self
        enableItem.state = isEnabled ? .on : .off
        menu.addItem(enableItem)

        menu.addItem(NSMenuItem.separator())

        // 开机启动
        let launchAtLoginItem = NSMenuItem(title: "开机启动", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        // 调试模式
        let debugItem = NSMenuItem(title: "调试模式", action: #selector(toggleDebugMode(_:)), keyEquivalent: "")
        debugItem.target = self
        debugItem.state = DebugLogger.shared.isEnabled ? .on : .off
        menu.addItem(debugItem)

        // 打开日志文件
        let logItem = NSMenuItem(title: "打开日志文件", action: #selector(openLogFile(_:)), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)

        menu.addItem(NSMenuItem.separator())

        // 打开配置文件
        let configItem = NSMenuItem(title: "打开配置文件", action: #selector(openConfig(_:)), keyEquivalent: ",")
        configItem.target = self
        menu.addItem(configItem)

        // 重新加载配置
        let reloadItem = NSMenuItem(title: "重新加载配置", action: #selector(reloadConfig(_:)), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(NSMenuItem.separator())

        // 退出
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off

        // 更新图标状态
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: isEnabled ? "teletype.answer" : "mic.slash.fill",
                accessibilityDescription: "Better Voice Input"
            )
        }

        // 通知 HotkeyManager
        NotificationCenter.default.post(
            name: .hotkeyEnabledChanged,
            object: nil,
            userInfo: ["enabled": isEnabled]
        )
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        launchAtLoginManager.toggle()
        sender.state = launchAtLoginManager.isEnabled ? .on : .off
    }

    @objc private func toggleDebugMode(_ sender: NSMenuItem) {
        DebugLogger.shared.isEnabled.toggle()
        sender.state = DebugLogger.shared.isEnabled ? .on : .off
    }

    @objc private func openLogFile(_ sender: NSMenuItem) {
        DebugLogger.shared.ensureLogFileExists()
        let url = URL(fileURLWithPath: DebugLogger.shared.logFilePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func openConfig(_ sender: NSMenuItem) {
        ConfigSetupManager.shared.openConfigFile()
    }

    @objc private func reloadConfig(_ sender: NSMenuItem) {
        // 提示用户需要重启应用
        let alert = NSAlert()
        alert.messageText = "重新加载配置"
        alert.informativeText = "配置更改需要重新启动应用才能生效。\n\n是否现在重启？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "重启")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 重启应用
            let url = URL(fileURLWithPath: Bundle.main.bundlePath)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true

            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let hotkeyEnabledChanged = Notification.Name("hotkeyEnabledChanged")
}
