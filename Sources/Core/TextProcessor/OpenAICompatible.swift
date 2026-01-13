import Foundation

/// OpenAI 兼容格式的文本处理器
/// 支持任何兼容 OpenAI API 格式的服务（OpenAI、Claude、DeepSeek、Ollama 等）
public class OpenAICompatibleProcessor: TextProcessing {
    private let config: TextProcessingConfig

    public init(config: TextProcessingConfig) {
        self.config = config
    }

    public func process(rawText: String, customPrompt: String?) async throws -> ProcessedResult {
        guard !config.apiKey.isEmpty else {
            throw TWError.textProcessingFailed("API Key 未配置")
        }

        let prompt = Prompts.generateProcessingPrompt(
            rawText: rawText,
            customPrompt: customPrompt
        )

        // 记录文本处理输入
        DebugLogger.shared.logTextProcessingInput(rawText: rawText, prompt: prompt)

        let response = try await callChatCompletion(prompt: prompt)
        return ProcessedResult(text: response, prompt: prompt)
    }

    public func rewrite(originalText: String, instruction: String, customPrompt: String?) async throws -> ProcessedResult {
        guard !config.apiKey.isEmpty else {
            throw TWError.rewriteFailed("API Key 未配置")
        }

        let prompt = Prompts.generateRewritePrompt(
            originalText: originalText,
            instruction: instruction,
            customPrompt: customPrompt
        )

        // 记录文本改写输入
        DebugLogger.shared.logRewriteInput(originalText: originalText, instruction: instruction, prompt: prompt)

        let response = try await callChatCompletion(prompt: prompt)
        return ProcessedResult(text: response, prompt: prompt)
    }

    private func callChatCompletion(prompt: String) async throws -> String {
        // 构建 URL
        let baseUrl = config.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseUrl)/chat/completions") else {
            throw TWError.textProcessingFailed("无效的 API URL")
        }

        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody = ChatCompletionRequest(
            model: config.model,
            messages: [
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.3,
            maxTokens: 4096
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        // 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TWError.networkError("无效的响应")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw TWError.textProcessingFailed("API 错误 (\(httpResponse.statusCode)): \(errorMessage)")
        }

        // 解析响应
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw TWError.invalidResponse("响应中没有内容")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - OpenAI API 数据结构

private struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Codable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Codable {
    let message: ChatMessage
}
