import AppKit
import Core

@main
struct TypoWriterApp {
    private static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var recordingOverlay: RecordingOverlay?
    private var twCore: TWCore?
    private var recordingStartTime: Date?
    private var configWindowController: ConfigWindowController?

    /// 待改写的文本（如果为 nil，则为普通语音输入模式）
    private var pendingRewriteText: String?

    private let minimumRecordingDuration: TimeInterval = 0.5

    func applicationDidFinishLaunching(_ notification: Notification) {
        configWindowController = ConfigWindowController()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openConfigWindow),
            name: .openConfigWindow,
            object: nil
        )
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)

        // 关闭 SwiftUI 自动创建的设置窗口（纯菜单栏应用不需要）
        DispatchQueue.main.async {
            for window in NSApp.windows {
                // 只关闭 Settings 窗口（标题包含 "Settings"）
                if window.title.contains("Settings") {
                    window.close()
                }
            }
        }

        // 检查并准备配置
        let result = ConfigSetupManager.shared.checkAndPrepareConfig()

        switch result {
        case .ready(let config):
            // 配置就绪，初始化应用
            initializeApp(with: config)

        case .created:
            // 已创建默认配置，提示用户配置
            showFirstTimeSetupAlert()
            // 仍然初始化菜单栏，让用户可以访问设置
            menuBarController = MenuBarController()

        case .needsApiKey:
            // 需要配置 API Key
            showApiKeyRequiredAlert()
            menuBarController = MenuBarController()

        case .error(let error):
            // 发生错误
            showErrorAlert(
                title: "配置错误",
                message: error.localizedDescription,
                showOpenConfig: true
            )
            menuBarController = MenuBarController()
        }
    }

    private func initializeApp(with config: Config) {
        applyConfig(config, showToast: false)

        // 初始化 MenuBar
        menuBarController = MenuBarController()

        // 初始化录音状态 Widget
        recordingOverlay = RecordingOverlay()

        // 初始化按键监听
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onKeyDown = { [weak self] in
            self?.startRecording()
        }
        hotkeyManager?.onKeyUp = { [weak self] in
            self?.stopRecording()
        }
        hotkeyManager?.startListening()
    }

    private func applyConfig(_ config: Config, showToast: Bool = true) {
        twCore = TWCore(config: config)
        if showToast {
            ErrorPresenter.shared.showToast("配置已更新", severity: .info)
        }
    }

    @objc private func openConfigWindow() {
        showConfigWindow()
    }

    private func showConfigWindow() {
        guard let configWindowController = configWindowController else {
            return
        }

        let result = ConfigSetupManager.shared.checkAndPrepareConfig()

        switch result {
        case .ready(let config):
            configWindowController.show(with: config) { [weak self] updatedConfig in
                self?.applyConfig(updatedConfig)
            }
        case .created, .needsApiKey:
            do {
                let config = try ConfigLoader.shared.load()
                configWindowController.show(with: config) { [weak self] updatedConfig in
                    self?.applyConfig(updatedConfig)
                }
            } catch let error as TWError {
                ErrorPresenter.shared.showTWError(error, context: "配置")
            } catch {
                ErrorPresenter.shared.showError(error, context: "配置")
            }
        case .error(let error):
            if let twError = error as? TWError {
                ErrorPresenter.shared.showTWError(twError, context: "配置")
            } else {
                ErrorPresenter.shared.showError(error, context: "配置")
            }
        }
    }

    // MARK: - 首次设置提示

    private func showFirstTimeSetupAlert() {
        // 将应用激活到前台，否则 Alert 会在后台弹出用户看不到
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "欢迎使用 TypoWriter"
        alert.informativeText = """
        已为您创建默认配置文件。

        请编辑配置文件，填入您的 API Key 后重新启动应用。

        配置文件位置：
        ~/.config/tw/config.yaml
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开配置文件")
        alert.addButton(withTitle: "稍后配置")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ConfigSetupManager.shared.openConfigFile()
        }
    }

    // MARK: - API Key 未配置提示

    private func showApiKeyRequiredAlert() {
        // 将应用激活到前台
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "需要配置 API Key"
        alert.informativeText = """
        检测到配置文件中的 API Key 尚未设置。

        请编辑配置文件，填入有效的 API Key：
        1. speech_recognition.aliyun.api_key - 语音识别 API Key
        2. text_processing.api_key - 文本处理 API Key

        配置完成后请重新启动应用。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开配置文件")
        alert.addButton(withTitle: "稍后配置")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ConfigSetupManager.shared.openConfigFile()
        }
    }

    // MARK: - 错误提示

    private func showErrorAlert(title: String, message: String, showOpenConfig: Bool = false) {
        // 将应用激活到前台
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical

        if showOpenConfig {
            alert.addButton(withTitle: "打开配置文件")
            alert.addButton(withTitle: "关闭")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showConfigWindow()
        }


        } else {
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }

    // MARK: - 录音控制

    private func startRecording() {
        guard let core = twCore, !core.isRecording else { return }

        // 检测是否有选中文本
        let selectedText = TextSelectionHelper.shared.getSelectedText()

        if let text = selectedText, !text.isEmpty {
            // 有选中文本，进入改写模式
            pendingRewriteText = text
        } else {
            // 未检测到选中文本，继续普通语音输入模式
            pendingRewriteText = nil
        }

        recordingStartTime = Date()

        Task {
            do {
                try await core.startRecording()
                await MainActor.run {
                    // 播放开始音效
                    SoundPlayer.shared.playStartSound()
                    // 显示录音状态
                    recordingOverlay?.show(state: .recording)
                }
            } catch let error as TWError {
                await MainActor.run {
                    pendingRewriteText = nil
                    SoundPlayer.shared.playErrorSound()
                    ErrorPresenter.shared.showTWError(error, context: "开始录音")
                }
                } catch {
                    await MainActor.run {
                        pendingRewriteText = nil
                        SoundPlayer.shared.playErrorSound()
                        ErrorPresenter.shared.showError(error, context: "开始录音")
                    }
                }

        }
    }

    private func stopRecording() {
        guard let core = twCore, core.isRecording else { return }

        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())

        // 播放停止音效
        SoundPlayer.shared.playStopSound()

        // 根据是否有待改写文本决定处理方式
        if let textToRewrite = pendingRewriteText {
            stopAndRewrite(core: core, originalText: textToRewrite, duration: duration)
        } else {
            stopAndProcess(core: core, duration: duration)
        }
    }

    /// 普通语音输入处理
    private func stopAndProcess(core: TWCore, duration: TimeInterval) {
        Task {
            // 检查是否误触
            if duration < minimumRecordingDuration {
                await MainActor.run {
                    recordingOverlay?.hide()
                    ErrorPresenter.shared.showToast("录音太短，已取消", severity: .info)
                }
                // 取消录音但不处理
                _ = try? await core.stopAndProcess()
                return
            }

            // 处理录音（带状态更新）
            do {
                let overlay = await MainActor.run { self.recordingOverlay }
                let result = try await core.stopAndProcess { phase in
                    Task { @MainActor in
                        switch phase {
                        case .stoppingRecording:
                            // 保持录音状态显示
                            break
                        case .transcribing:
                            overlay?.updateState(.transcribing)
                        case .processing:
                            overlay?.updateState(.processing)
                        case .rewriting:
                            // 不会出现在普通模式
                            break
                        }
                    }
                }

                await MainActor.run {
                    // 隐藏状态窗口
                    recordingOverlay?.hide()
                    // 播放完成音效
                    SoundPlayer.shared.playCompleteSound()
                    // 尝试输入到当前活跃窗口
                    if !TextInputSimulator.shared.typeText(result.processedText) {
                        // 如果无法输入，显示结果窗口
                        ResultWindow.shared.show(text: result.processedText)
                    }
                }
            } catch let error as TWError {
                await MainActor.run {
                    recordingOverlay?.hide()
                    SoundPlayer.shared.playErrorSound()
                    ErrorPresenter.shared.showTWError(error, context: "语音处理")
                }
            } catch {
                await MainActor.run {
                    recordingOverlay?.hide()
                    SoundPlayer.shared.playErrorSound()
                    ErrorPresenter.shared.showError(error, context: "语音处理")
                }
            }
        }
    }

    /// 文本改写处理
    private func stopAndRewrite(core: TWCore, originalText: String, duration: TimeInterval) {
        Task {
            // 检查是否误触
            if duration < minimumRecordingDuration {
                await MainActor.run {
                    recordingOverlay?.hide()
                    ErrorPresenter.shared.showToast("录音太短，已取消", severity: .info)
                }
                // 取消录音但不处理
                _ = try? await core.stopAndProcess()
                return
            }

            // 执行改写处理
            do {
                let overlay = await MainActor.run { self.recordingOverlay }
                let result = try await core.stopAndRewrite(originalText: originalText) { phase in
                    Task { @MainActor in
                        switch phase {
                        case .stoppingRecording:
                            // 保持录音状态显示
                            break
                        case .transcribing:
                            overlay?.updateState(.transcribing)
                        case .rewriting:
                            overlay?.updateState(.rewriting)
                        case .processing:
                            // 不会出现在改写模式
                            break
                        }
                    }
                }

                await MainActor.run {
                    // 隐藏状态窗口
                    recordingOverlay?.hide()
                    // 播放完成音效
                    SoundPlayer.shared.playCompleteSound()
                    // 替换选中文本（会自动使用剪贴板 + Cmd+V）
                    if !TextSelectionHelper.shared.replaceSelectedText(with: result.rewrittenText) {
                        // 如果无法替换，显示结果窗口
                        ResultWindow.shared.show(text: result.rewrittenText)
                    }
                }
            } catch let error as TWError {
                await MainActor.run {
                    recordingOverlay?.hide()
                    SoundPlayer.shared.playErrorSound()
                    ErrorPresenter.shared.showTWError(error, context: "文本改写")
                }
            } catch {
                await MainActor.run {
                    recordingOverlay?.hide()
                    SoundPlayer.shared.playErrorSound()
                    ErrorPresenter.shared.showError(error, context: "文本改写")
                }
            }
        }
    }
}
