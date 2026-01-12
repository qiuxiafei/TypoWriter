import AppKit
import AudioToolbox

/// 音效播放器
class SoundPlayer {
    static let shared = SoundPlayer()

    private init() {}

    /// 播放录音开始音效
    func playStartSound() {
        // 使用系统音效 - Tink (轻柔的开始提示音)
        if let sound = NSSound(named: "Tink") {
            sound.play()
        } else {
            // 备用：使用系统声音
            AudioServicesPlaySystemSound(1103) // 系统按键音
        }
    }

    /// 播放录音停止音效
    func playStopSound() {
        // 使用系统音效 - Pop (结束提示音)
        if let sound = NSSound(named: "Pop") {
            sound.play()
        } else {
            AudioServicesPlaySystemSound(1104)
        }
    }

    /// 播放完成音效
    func playCompleteSound() {
        // 使用系统音效 - Glass (完成提示音)
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            AudioServicesPlaySystemSound(1054)
        }
    }

    /// 播放错误音效
    func playErrorSound() {
        // 使用系统音效 - Basso (错误提示音)
        if let sound = NSSound(named: "Basso") {
            sound.play()
        } else {
            AudioServicesPlaySystemSound(1053)
        }
    }
}
