import ArgumentParser
import Core
import Foundation

@main
struct TW: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tw",
        abstract: "Typo Writer - 智能语音输入工具",
        discussion: """
        将语音转换为整理后的文字，支持：
        - 智能整理：去除口语化表达
        - 意图识别：识别并合并修改意图
        - 结构化处理：自动分段和要点提取
        """,
        version: "0.1.0"
    )

    @Option(name: .shortAndLong, help: "配置文件路径")
    var config: String?

    @Flag(name: .long, help: "输出到剪贴板")
    var clipboard: Bool = false

    mutating func run() async throws {
        // 加载配置
        let configLoader = ConfigLoader.shared
        let appConfig: Config

        do {
            appConfig = try configLoader.load(from: config)
        } catch TWError.configNotFound(let path) {
            print("❌ 配置文件未找到: \(path)")
            print("")
            print("请创建配置文件，示例：")
            print("")
            printExampleConfig()
            throw ExitCode.failure
        } catch {
            print("❌ 配置加载失败: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // 创建核心处理器
        let core = TWCore(config: appConfig)

        // 直接开始录音
        do {
            try await core.startRecording()
            print("🔴 录音中... 按 Enter 停止")
        } catch {
            print("❌ 录音启动失败: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // 等待用户按 Enter 停止
        _ = readLine()

        print("⏳ 处理中...")

        // 停止录音并处理
        do {
            let result = try await core.stopAndProcess()

            // 打印语音识别结果
            print("")
            print("📝 语音识别结果：")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(result.transcription)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // 打印 LLM 输入
            print("")
            print("🤖 LLM 输入 Prompt：")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(result.llmPrompt)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // 打印最终结果
            print("")
            print("✨ 处理结果：")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(result.processedText)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // 复制到剪贴板
            if clipboard {
                copyToClipboard(result.processedText)
                print("")
                print("✅ 已复制到剪贴板")
            }
        } catch {
            print("❌ 处理失败: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    private func printExampleConfig() {
        print("""
        # ~/.config/tw/config.yaml

        speech_recognition:
          preset: dashscope_qwen_asr
          credentials:
            api_key: ${DASHSCOPE_API_KEY}

        text_processing:
          preset: dashscope_qwen_plus
          credentials:
            api_key: ${DASHSCOPE_API_KEY}

        # processing:
        #   prompt: |
        #     ...
        #   rewrite_prompt: |
        #     ...
        """)
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")

        let pipe = Pipe()
        process.standardInput = pipe

        do {
            try process.run()
            pipe.fileHandleForWriting.write(text.data(using: .utf8)!)
            pipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()
        } catch {
            print("复制到剪贴板失败: \(error)")
        }
        #endif
    }
}
