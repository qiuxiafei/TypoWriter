import Foundation
import ServiceManagement

/// 开机启动管理器
/// 使用 SMAppService API (macOS 13+) 管理登录项
class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    /// 是否开机启动
    @Published private(set) var isEnabled: Bool = false

    private init() {
        syncStatus()
    }

    /// 从系统同步状态（用户可能在系统设置中修改）
    func syncStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// 切换开机启动状态
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    /// 启用开机启动
    func enable() {
        do {
            try SMAppService.mainApp.register()
            isEnabled = true
        } catch {
            print("启用开机启动失败: \(error.localizedDescription)")
            syncStatus()
        }
    }

    /// 禁用开机启动
    func disable() {
        do {
            try SMAppService.mainApp.unregister()
            isEnabled = false
        } catch {
            print("禁用开机启动失败: \(error.localizedDescription)")
            syncStatus()
        }
    }

    /// 获取当前状态描述
    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return "未注册"
        case .enabled:
            return "已启用"
        case .requiresApproval:
            return "需要用户批准"
        case .notFound:
            return "未找到服务"
        @unknown default:
            return "未知状态"
        }
    }
}
