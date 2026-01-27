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
        case speechApiKey
        case textApiKey
        case processingPrompt
        case rewritePrompt
    }

    @Published var speechPreset: SpeechRecognitionPreset
    @Published var speechApiKey: String

    @Published var textPreset: TextProcessingPreset
    @Published var textApiKey: String

    @Published var useDefaultProcessingPrompt: Bool
    @Published var processingPrompt: String
    @Published var useDefaultRewritePrompt: Bool
    @Published var rewritePrompt: String
    @Published var errors: [FieldKey: String] = [:]
    @Published var saveError: String?

    var onSave: ((Config) -> Void)?

    init(config: Config, onSave: ((Config) -> Void)? = nil) {
        speechPreset = config.speechRecognition.preset
        speechApiKey = config.speechRecognition.credentials.apiKey

        textPreset = config.textProcessing.preset
        textApiKey = config.textProcessing.credentials.apiKey

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
        speechPreset = config.speechRecognition.preset
        speechApiKey = config.speechRecognition.credentials.apiKey

        textPreset = config.textProcessing.preset
        textApiKey = config.textProcessing.credentials.apiKey

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
        let speechConfig = SpeechRecognitionConfig(
            preset: speechPreset,
            credentials: APICredentials(apiKey: speechApiKey)
        )

        let textConfig = TextProcessingConfig(
            preset: textPreset,
            credentials: APICredentials(apiKey: textApiKey)
        )

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

        if speechApiKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            newErrors[.speechApiKey] = "请输入语音识别 API Key"
        }

        if textApiKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            newErrors[.textApiKey] = "请输入文本处理 API Key"
        }

        if !useDefaultProcessingPrompt && processingPrompt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            newErrors[.processingPrompt] = "请输入自定义文本处理 prompt"
        }

        if !useDefaultRewritePrompt && rewritePrompt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            newErrors[.rewritePrompt] = "请输入自定义改写 prompt"
        }

        if showErrors {
            errors = newErrors
        }

        return newErrors.isEmpty
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
        .onChange(of: viewModel.speechPreset) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.speechApiKey) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.textPreset) { _ in
            viewModel.updateValidation()
        }
        .onChange(of: viewModel.textApiKey) { _ in
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
        let resolved = SpeechRecognitionPresets.resolve(viewModel.speechPreset)

        return VStack(alignment: .leading, spacing: 12) {
            Text("语音识别")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("配置方案")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("配置方案", selection: $viewModel.speechPreset) {
                    Text(viewModel.speechPreset.displayName)
                        .tag(viewModel.speechPreset)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.speechApiKey)
                errorText(for: .speechApiKey)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Endpoint")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(resolved.endpoint.absoluteString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("模型")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(resolved.model)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var textProcessingSection: some View {
        let resolved = TextProcessingPresets.resolve(viewModel.textPreset)

        return VStack(alignment: .leading, spacing: 12) {
            Text("文本处理")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("配置方案")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("配置方案", selection: $viewModel.textPreset) {
                    Text(viewModel.textPreset.displayName)
                        .tag(viewModel.textPreset)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.textApiKey)
                errorText(for: .textApiKey)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Endpoint")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(resolved.endpoint.absoluteString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("模型")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(resolved.model)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
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
