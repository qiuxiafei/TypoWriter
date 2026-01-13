import Foundation
import XCTest
@testable import Core

final class CoreTests: XCTestCase {
    func testPromptsGenerationWithCustomPrompt() {
        let prompt = Prompts.generateProcessingPrompt(
            rawText: "嗯，我想说的是，明天不对是后天下午三点开个会",
            customPrompt: "这是一个自定义提示"
        )

        XCTAssertTrue(prompt.contains("这是一个自定义提示"))
        XCTAssertTrue(prompt.contains("明天不对是后天"))
        XCTAssertTrue(prompt.contains("输入："))
        XCTAssertTrue(prompt.contains("输出："))
    }

    func testRewritePromptGeneration() {
        let prompt = Prompts.generateRewritePrompt(
            originalText: "原始文本",
            instruction: "改成更正式的语气"
        )

        XCTAssertTrue(prompt.contains("待改写文本"))
        XCTAssertTrue(prompt.contains("原始文本"))
        XCTAssertTrue(prompt.contains("用户指令"))
        XCTAssertTrue(prompt.contains("改成更正式的语气"))
    }

    func testConfigEnvironmentExpansion() throws {
        setenv("TEST_API_KEY", "test_value_123", 1)
        defer { unsetenv("TEST_API_KEY") }

        let content = """
speech_recognition:
  provider: aliyun
  aliyun:
    api_key: ${TEST_API_KEY}
    model: qwen3-asr-flash
text_processing:
  base_url: https://example.com/v1
  api_key: ${TEST_API_KEY}
  model: gpt-4o
processing:
  prompt: "测试"
"""

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tw_test_config.yaml")
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let config = try ConfigLoader.shared.load(from: tempURL.path)

        XCTAssertEqual(config.speechRecognition.aliyun?.apiKey, "test_value_123")
        XCTAssertEqual(config.textProcessing.apiKey, "test_value_123")
    }

    func testCreateExampleConfig() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tw_example_config.yaml")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try ConfigLoader.shared.createExampleConfig(at: tempURL.path)

        let content = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(content.contains("speech_recognition"))
        XCTAssertTrue(content.contains("text_processing"))
        XCTAssertTrue(content.contains("api_key: ${DASHSCOPE_API_KEY}"))
    }

    func testFactoryCreation() {
        let speechConfig = SpeechRecognitionConfig(
            provider: .aliyun,
            aliyun: AliyunConfig(apiKey: "", model: "qwen3-asr-flash")
        )
        let speechRecognizer = SpeechRecognizerFactory.create(config: speechConfig)
        XCTAssertTrue(speechRecognizer is AliyunASR)

        let textConfig = TextProcessingConfig(
            baseUrl: "https://example.com/v1",
            apiKey: "test",
            model: "gpt-4o"
        )
        let textProcessor = TextProcessorFactory.create(config: textConfig)
        XCTAssertTrue(textProcessor is OpenAICompatibleProcessor)
    }

    func testTWErrorDescriptions() {
        let error1 = TWError.configNotFound("/path/to/config")
        XCTAssertTrue(error1.errorDescription?.contains("配置文件未找到") ?? false)

        let error2 = TWError.speechRecognitionFailed("测试错误")
        XCTAssertTrue(error2.errorDescription?.contains("语音识别失败") ?? false)
    }
}
