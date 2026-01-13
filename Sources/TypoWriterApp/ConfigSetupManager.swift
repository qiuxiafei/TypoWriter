import Foundation
import AppKit
import Core

/// 配置初始化管理器
/// 负责检查和创建配置文件
class ConfigSetupManager {
    static let shared = ConfigSetupManager()

    private let fileManager = FileManager.default

    /// 配置目录路径
    var configDirectory: String {
        let homeDir = fileManager.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.config/bvi"
    }

    /// 配置文件路径
    var configPath: String {
        return ConfigLoader.shared.defaultConfigPath
    }

    private init() {}

    /// 配置检查结果
    enum ConfigCheckResult {
        case ready(Config)      // 配置就绪
        case created            // 已创建默认配置
        case needsApiKey        // 需要配置 API Key
        case error(Error)       // 发生错误
    }

    /// 检查并准备配置
    func checkAndPrepareConfig() -> ConfigCheckResult {
        // 1. 检查并创建配置目录
        if !fileManager.fileExists(atPath: configDirectory) {
            do {
                try fileManager.createDirectory(
                    atPath: configDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                return .error(BVIError.configParseError("无法创建配置目录: \(error.localizedDescription)"))
            }
        }

        // 2. 检查配置文件是否存在
        if !fileManager.fileExists(atPath: configPath) {
            // 创建默认配置文件
            do {
                try ConfigLoader.shared.createExampleConfig(at: configPath)
                return .created
            } catch {
                return .error(BVIError.configParseError("无法创建配置文件: \(error.localizedDescription)"))
            }
        }

        // 3. 尝试加载配置
        do {
            let config = try ConfigLoader.shared.load()

            // 4. 检查 API Key 是否已配置
            if isApiKeyPlaceholder(config.speechRecognition.aliyun?.apiKey) ||
               isApiKeyPlaceholder(config.textProcessing.apiKey) {
                return .needsApiKey
            }

            return .ready(config)
        } catch {
            return .error(error)
        }
    }

    /// 检查是否是占位符 API Key
    private func isApiKeyPlaceholder(_ apiKey: String?) -> Bool {
        guard let key = apiKey else { return true }
        if key.isEmpty { return true }

        let placeholders = [
            "<填入你的",
            "YOUR_API_KEY",
            "sk-xxx",
            "${DASHSCOPE_API_KEY}",
            "${OPENAI_API_KEY}",
            "your-api-key"
        ]
        return placeholders.contains(where: { key.contains($0) || key == $0 })
    }

    /// 打开配置文件所在目录（在 Finder 中显示并选中配置文件）
    func openConfigFile() {
        let url = URL(fileURLWithPath: configPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

}
