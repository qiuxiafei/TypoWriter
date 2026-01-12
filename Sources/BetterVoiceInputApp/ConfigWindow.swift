import AppKit
import Core
import SwiftUI

final class ConfigWindowController {
    private var window: NSWindow?
    private var viewModel: ConfigViewModel?

    func show(with config: Config, onSave: @escaping (Config) -> Void) {
        if let window = window, let viewModel = viewModel {
            viewModel.update(with: config)
            viewModel.onSave = onSave
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let viewModel = ConfigViewModel(config: config, onSave: onSave)
        let rootView = ConfigWindowView(viewModel: viewModel) { [weak self] in
            self?.close()
        }

        let hostingView = NSHostingView(rootView: rootView)
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "应用配置"
        newWindow.center()
        newWindow.contentView = hostingView
        newWindow.isReleasedWhenClosed = false

        window = newWindow
        self.viewModel = viewModel

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}

final class ConfigViewModel: ObservableObject {
    enum FieldKey: String, CaseIterable {
        case provider
        case aliyunApiKey
        case aliyunModel
        case textBaseUrl
        case textApiKey
        case textModel
        case processingPrompt
        case rewritePrompt
    }

    @Published var provider: SpeechProvider
    @Published var aliyunApiKey: String
    @Published var aliyunModel: String
    @Published var textBaseUrl: String
    @Published var textApiKey: String
    @Published var textModel: String
    @Published var useDefaultProcessingPrompt: Bool
    @Published var processingPrompt: String
    @Published var useDefaultRewritePrompt: Bool
    @Published var rewritePrompt: String
    @Published var errors: [FieldKey: String] = [:]
    @Published var saveError: String?

    var onSave: ((Config) -> Void)?

    init(config: Config, onSave: ((Config) -> Void)? = nil) {
        provider = config.speechRecognition.provider
        let aliyunConfig = config.speechRecognition.aliyun ?? AliyunConfig()
        aliyunApiKey = aliyunConfig.apiKey
        aliyunModel = aliyunConfig.model
        textBaseUrl = config.textProcessing.baseUrl
        textApiKey = config.textProcessing.apiKey
        textModel = config.textProcessing.model
        processingPrompt = config.processing.prompt ?? ""
        useDefaultProcessingPrompt = config.processing.prompt?.isEmpty ?? true
        rewritePrompt = config.processing.rewritePrompt ?? ""
        useDefaultRewritePrompt = config.processing.rewritePrompt?.isEmpty ?? true
        self.onSave = onSave
        updateValidation()
    }

    var isValid: Bool {
        validate(showErrors: false)
    }

    func update(with config: Config) {
        provider = config.speechRecognition.provider
        let aliyunConfig = config.speechRecognition.aliyun ?? AliyunConfig()
        aliyunApiKey = aliyunConfig.apiKey
        aliyunModel = aliyunConfig.model
        textBaseUrl = config.textProcessing.baseUrl
        textApiKey = config.textProcessing.apiKey
        textModel = config.textProcessing.model
        processingPrompt = config.processing.prompt ?? ""
        useDefaultProcessingPrompt = config.processing.prompt?.isEmpty ?? true
        rewritePrompt = config.processing.rewritePrompt ?? ""
        useDefaultRewritePrompt = config.processing.rewritePrompt?.isEmpty ?? true
        saveError = nil
        updateValidation()
    }

    func updateValidation() {
        _ = validate(showErrors: true)
    }

    func save() -> Bool {
        saveError = nil
        guard validate(showErrors: true) else {
            return false
        }

        let config = currentConfig()

        do {
            try ConfigLoader.shared.save(config)
            onSave?(config)
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    func currentConfig() -> Config {
        let aliyunConfig = AliyunConfig(apiKey: aliyunApiKey, model: aliyunModel)
        let speechConfig = SpeechRecognitionConfig(provider: provider, aliyun: aliyunConfig)
        let textConfig = TextProcessingConfig(baseUrl: textBaseUrl, apiKey: textApiKey, model: textModel)
        let processingConfig = ProcessingConfig(
            prompt: useDefaultProcessingPrompt ? nil : processingPrompt,
            rewritePrompt: useDefaultRewritePrompt ? nil : rewritePrompt
        )

        return Config(
            speechRecognition: speechConfig,
            textProcessing: textConfig,
            processing: processingConfig
        )
    }

    private func validate(showErrors: Bool) -> Bool {
        var newErrors: [FieldKey: String] = [:]

        if provider == .aliyun {
            if aliyunApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                newErrors[.aliyunApiKey] = "请输入语音识别 API Key"
            }
            if aliyunModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                newErrors[.aliyunModel] = "请输入语音识别模型"
            }
        }

        if textBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newErrors[.textBaseUrl] = "请输入文本处理 Base URL"
        } else if !isValidURL(textBaseUrl) {
            newErrors[.textBaseUrl] = "Base URL 不是有效的 URL"
        }

        if textApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newErrors[.textApiKey] = "请输入文本处理 API Key"
        }

        if textModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newErrors[.textModel] = "请输入文本处理模型"
        }

        if !useDefaultProcessingPrompt && processingPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newErrors[.processingPrompt] = "请输入自定义文本处理 prompt"
        }

        if !useDefaultRewritePrompt && rewritePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newErrors[.rewritePrompt] = "请输入自定义改写 prompt"
        }

        if showErrors {
            errors = newErrors
        }

        return newErrors.isEmpty
    }

    private func isValidURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return url.scheme?.isEmpty == false && url.host?.isEmpty == false
    }
}

struct ConfigWindowView: View {
    @ObservedObject var viewModel: ConfigViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 20) {
                    speechSection
                    textProcessingSection
                    promptSection
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 540, minHeight: 600)
        .onChange(of: viewModel.provider) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.aliyunApiKey) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.aliyunModel) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.textBaseUrl) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.textApiKey) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.textModel) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.useDefaultProcessingPrompt) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.processingPrompt) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.useDefaultRewritePrompt) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.rewritePrompt) { _ in
            viewModel.updateValidation()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("应用配置")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("修改配置后点击确认即可生效")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }

    private var speechSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("语音识别")
                .font(.headline)

            Picker("服务商", selection: $viewModel.provider) {
                Text("阿里云").tag(SpeechProvider.aliyun)
                Text("OpenAI").tag(SpeechProvider.openai)
                Text("Apple").tag(SpeechProvider.apple)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.aliyunApiKey)
                    .disabled(viewModel.provider != .aliyun)
                    .opacity(viewModel.provider != .aliyun ? 0.6 : 1.0)
                errorText(for: .aliyunApiKey)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("模型")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.aliyunModel)
                    .disabled(viewModel.provider != .aliyun)
                    .opacity(viewModel.provider != .aliyun ? 0.6 : 1.0)
                errorText(for: .aliyunModel)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var textProcessingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文本处理")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Base URL")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.textBaseUrl)
                errorText(for: .textBaseUrl)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.textApiKey)
                errorText(for: .textApiKey)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("模型")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.textModel)
                errorText(for: .textModel)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Prompt 配置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("使用默认文本处理 prompt", isOn: $viewModel.useDefaultProcessingPrompt)
                promptEditor(
                    text: $viewModel.processingPrompt,
                    placeholder: "自定义文本处理 prompt",
                    disabled: viewModel.useDefaultProcessingPrompt
                )
                errorText(for: .processingPrompt)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("使用默认改写 prompt", isOn: $viewModel.useDefaultRewritePrompt)
                promptEditor(
                    text: $viewModel.rewritePrompt,
                    placeholder: "自定义改写 prompt",
                    disabled: viewModel.useDefaultRewritePrompt
                )
                errorText(for: .rewritePrompt)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let saveError = viewModel.saveError {
                Text(saveError)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("取消") {
                    onClose()
                }
                Button("确认") {
                    if viewModel.save() {
                        onClose()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isValid)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func errorText(for key: ConfigViewModel.FieldKey) -> some View {
        if let error = viewModel.errors[key] {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    private func promptEditor(text: Binding<String>, placeholder: String, disabled: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color.gray.opacity(0.6))
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }
            TextEditor(text: text)
                .frame(minHeight: 120)
                .disabled(disabled)
                .opacity(disabled ? 0.6 : 1.0)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}
