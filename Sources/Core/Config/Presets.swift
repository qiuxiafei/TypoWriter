import Foundation

// MARK: - Speech Recognition Presets

public struct SpeechRecognitionPresetDefinition {
    public let id: SpeechRecognitionPreset
    public let endpoint: URL
    public let model: String
    public let enableItn: Bool

    public init(id: SpeechRecognitionPreset, endpoint: URL, model: String, enableItn: Bool) {
        self.id = id
        self.endpoint = endpoint
        self.model = model
        self.enableItn = enableItn
    }
}

public enum SpeechRecognitionPresets {
    public static let dashscopeQwenASR = SpeechRecognitionPresetDefinition(
        id: .dashscopeQwenASR,
        endpoint: URL(string: "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation")!,
        model: "qwen3-asr-flash",
        enableItn: true
    )

    public static func resolve(_ preset: SpeechRecognitionPreset) -> SpeechRecognitionPresetDefinition {
        switch preset {
        case .dashscopeQwenASR:
            return dashscopeQwenASR
        }
    }
}

// MARK: - Text Processing Presets

public struct TextProcessingPresetDefinition {
    public let id: TextProcessingPreset
    public let endpoint: URL
    public let model: String
    public let temperature: Double
    public let maxTokens: Int

    public init(id: TextProcessingPreset, endpoint: URL, model: String, temperature: Double, maxTokens: Int) {
        self.id = id
        self.endpoint = endpoint
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

public enum TextProcessingPresets {
    public static let dashscopeQwenPlus = TextProcessingPresetDefinition(
        id: .dashscopeQwenPlus,
        endpoint: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!,
        model: "qwen-plus",
        temperature: 0.3,
        maxTokens: 4096
    )

    public static func resolve(_ preset: TextProcessingPreset) -> TextProcessingPresetDefinition {
        switch preset {
        case .dashscopeQwenPlus:
            return dashscopeQwenPlus
        }
    }
}

// MARK: - Resolved Configs

public struct ResolvedSpeechRecognitionConfig {
    public let preset: SpeechRecognitionPreset
    public let endpoint: URL
    public let apiKey: String
    public let model: String
    public let enableItn: Bool

    public init(preset: SpeechRecognitionPreset, endpoint: URL, apiKey: String, model: String, enableItn: Bool) {
        self.preset = preset
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.enableItn = enableItn
    }
}

public struct ResolvedTextProcessingConfig {
    public let preset: TextProcessingPreset
    public let endpoint: URL
    public let apiKey: String
    public let model: String
    public let temperature: Double
    public let maxTokens: Int

    public init(
        preset: TextProcessingPreset,
        endpoint: URL,
        apiKey: String,
        model: String,
        temperature: Double,
        maxTokens: Int
    ) {
        self.preset = preset
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

// MARK: - Resolve Helpers

public extension SpeechRecognitionConfig {
    func resolve() -> ResolvedSpeechRecognitionConfig {
        let definition = SpeechRecognitionPresets.resolve(preset)
        return ResolvedSpeechRecognitionConfig(
            preset: preset,
            endpoint: definition.endpoint,
            apiKey: credentials.apiKey,
            model: definition.model,
            enableItn: definition.enableItn
        )
    }
}

public extension TextProcessingConfig {
    func resolve() -> ResolvedTextProcessingConfig {
        let definition = TextProcessingPresets.resolve(preset)
        return ResolvedTextProcessingConfig(
            preset: preset,
            endpoint: definition.endpoint,
            apiKey: credentials.apiKey,
            model: definition.model,
            temperature: definition.temperature,
            maxTokens: definition.maxTokens
        )
    }
}
