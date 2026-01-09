import Foundation

/// 阿里云百炼 ASR 实现（通义千问语音识别）
/// 参考文档：https://help.aliyun.com/zh/model-studio/qwen-speech-recognition
public class AliyunASR: SpeechRecognizing {
    private let config: AliyunConfig
    private let apiURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"

    public init(config: AliyunConfig) {
        self.config = config
    }

    public func transcribe(audio: Data) async throws -> TranscriptionResult {
        guard !config.apiKey.isEmpty else {
            throw BVIError.speechRecognitionFailed("API Key 未配置，请设置 DASHSCOPE_API_KEY 环境变量")
        }

        // 将音频数据转换为 Base64
        let base64Audio = audio.base64EncodedString()
        let audioDataURL = "data:audio/wav;base64,\(base64Audio)"

        // 构建请求
        guard let url = URL(string: apiURL) else {
            throw BVIError.speechRecognitionFailed("无效的 API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody = QwenASRRequest(
            model: config.model,
            input: QwenASRInput(
                messages: [
                    QwenMessage(
                        role: "system",
                        content: [QwenContent(text: "", audio: nil)]
                    ),
                    QwenMessage(
                        role: "user",
                        content: [QwenContent(text: nil, audio: audioDataURL)]
                    )
                ]
            ),
            parameters: QwenASRParameters(
                asrOptions: ASROptions(enableItn: true)
            )
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)

        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        // 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BVIError.networkError("无效的响应")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw BVIError.speechRecognitionFailed("API 错误 (\(httpResponse.statusCode)): \(errorMessage)")
        }

        // 解析响应
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let qwenResponse = try decoder.decode(QwenASRResponse.self, from: data)

        guard let text = qwenResponse.output.choices.first?.message.content.first?.text else {
            throw BVIError.invalidResponse("响应中没有识别结果")
        }

        return TranscriptionResult(
            text: text,
            segments: nil,
            language: "zh"
        )
    }
}

// MARK: - 请求数据结构

private struct QwenASRRequest: Codable {
    let model: String
    let input: QwenASRInput
    let parameters: QwenASRParameters
}

private struct QwenASRInput: Codable {
    let messages: [QwenMessage]
}

private struct QwenMessage: Codable {
    let role: String
    let content: [QwenContent]
}

private struct QwenContent: Codable {
    let text: String?
    let audio: String?
}

private struct QwenASRParameters: Codable {
    let asrOptions: ASROptions
}

private struct ASROptions: Codable {
    let enableItn: Bool
}

// MARK: - 响应数据结构

private struct QwenASRResponse: Codable {
    let output: QwenASROutput
    let requestId: String?
}

private struct QwenASROutput: Codable {
    let choices: [QwenChoice]
}

private struct QwenChoice: Codable {
    let message: QwenResponseMessage
}

private struct QwenResponseMessage: Codable {
    let content: [QwenResponseContent]
}

private struct QwenResponseContent: Codable {
    let text: String?
}
