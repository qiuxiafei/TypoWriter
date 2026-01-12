import AppKit
import Carbon

/// 全局按键监听管理器
/// 监听右 Option 键的按下和松开事件
class HotkeyManager {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isEnabled = true
    private var isKeyDown = false

    // 右 Option 键的 keycode
    private let rightOptionKeyCode: CGKeyCode = 61

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnabledChanged(_:)),
            name: .hotkeyEnabledChanged,
            object: nil
        )
    }

    deinit {
        stopListening()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleEnabledChanged(_ notification: Notification) {
        if let enabled = notification.userInfo?["enabled"] as? Bool {
            isEnabled = enabled
        }
    }

    func startListening() {
        // 检查辅助功能权限
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            print("需要辅助功能权限")
            return
        }

        // 创建事件 tap
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("无法创建事件 tap")
            return
        }

        eventTap = tap

        // 添加到 run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stopListening() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabled else {
            return Unmanaged.passRetained(event)
        }

        if type == .flagsChanged {
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            // 检查是否是右 Option 键
            if keyCode == rightOptionKeyCode {
                let isRightOptionPressed = flags.contains(.maskAlternate) && !flags.contains(.maskCommand)

                if isRightOptionPressed && !isKeyDown {
                    // 按下
                    isKeyDown = true
                    DispatchQueue.main.async { [weak self] in
                        self?.onKeyDown?()
                    }
                } else if !isRightOptionPressed && isKeyDown {
                    // 松开
                    isKeyDown = false
                    DispatchQueue.main.async { [weak self] in
                        self?.onKeyUp?()
                    }
                }
            }
        }

        return Unmanaged.passRetained(event)
    }
}
