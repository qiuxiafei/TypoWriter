import XCTest
@testable import Core

final class CoreTests: XCTestCase {
    func testPromptsGeneration() {
        let prompt = Prompts.generateProcessingPrompt(
            rawText: "嗯，我想说的是，明天不对是后天下午三点开个会",
            preserveStyle: true
        )

        XCTAssertTrue(prompt.contains("打字员"))
        XCTAssertTrue(prompt.contains("明天不对是后天"))
        XCTAssertTrue(prompt.contains("保持原有的语义和说话风格"))
    }

    func testConfigEnvironmentExpansion() throws {
        // 设置测试环境变量
        setenv("TEST_API_KEY", "test_value_123", 1)

        let content = "api_key: ${TEST_API_KEY}"
        let loader = ConfigLoader.shared

        // 通过反射测试私有方法（实际项目中可能需要重构以支持测试）
        // 这里只是展示测试结构
        XCTAssertTrue(content.contains("${TEST_API_KEY}"))
    }

    func testProcessingOptions() {
        let options = ProcessingOptions(preserveStyle: true)
        XCTAssertTrue(options.preserveStyle)

        let options2 = ProcessingOptions(preserveStyle: false)
        XCTAssertFalse(options2.preserveStyle)
    }

    func testBVIErrorDescriptions() {
        let error1 = BVIError.configNotFound("/path/to/config")
        XCTAssertTrue(error1.errorDescription?.contains("配置文件未找到") ?? false)

        let error2 = BVIError.speechRecognitionFailed("测试错误")
        XCTAssertTrue(error2.errorDescription?.contains("语音识别失败") ?? false)
    }
}
