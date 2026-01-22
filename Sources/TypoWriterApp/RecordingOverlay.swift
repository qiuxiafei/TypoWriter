import AppKit
import SwiftUI

/// 处理状态
enum ProcessingState {
    case recording       // 正在录音
    case transcribing    // 正在语音转文字
    case processing      // 正在优化文字
    case rewriting       // 正在改写文字

    var text: String {
        switch self {
        case .recording: return "正在聆听..."
        case .transcribing: return "语音转文字..."
        case .processing: return "优化文字..."
        case .rewriting: return "改写文字..."
        }
    }

    var icon: String {
        switch self {
        case .recording: return "waveform"
        case .transcribing: return "text.bubble"
        case .processing: return "sparkles"
        case .rewriting: return "pencil.and.outline"
        }
    }

    var color: Color {
        switch self {
        case .recording: return .red
        case .transcribing: return .blue
        case .processing: return .purple
        case .rewriting: return .orange
        }
    }
}

/// 录音状态悬浮窗口
class RecordingOverlay {
    private var window: NSPanel?
    private var hostingView: NSHostingView<RecordingOverlayView>?
    private var viewModel = RecordingOverlayViewModel()

    init() {
        setupWindow()
    }

    private func setupWindow() {
        let contentView = NSHostingView(rootView: RecordingOverlayView(viewModel: viewModel))
        contentView.frame = NSRect(x: 0, y: 0, width: 160, height: 50)
        hostingView = contentView

        let panel = NSPanel(
            contentRect: contentView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hasShadow = true

        // 定位到屏幕中央偏上
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - contentView.frame.width / 2
            let y = screenFrame.maxY - 150
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window = panel
    }

    func show(state: ProcessingState = .recording) {
        viewModel.state = state
        viewModel.isActive = true
        if window == nil {
            setupWindow()
        }
        window?.orderFront(nil)
    }

    func updateState(_ state: ProcessingState) {
        viewModel.state = state
    }

    func hide() {
        viewModel.isActive = false
        window?.close()
        window = nil
        hostingView = nil
    }
}

class RecordingOverlayViewModel: ObservableObject {
    @Published var state: ProcessingState = .recording
    @Published var isActive: Bool = false
}

struct RecordingOverlayView: View {
    @ObservedObject var viewModel: RecordingOverlayViewModel
    @State private var isPulsing = false
    @State private var rotation: Double = 0

    var body: some View {
        Group {
            if viewModel.isActive {
                contentView
            } else {
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
        .onAppear {
            if viewModel.isActive {
                startAnimations()
            }
        }
        .onChange(of: viewModel.state) { _ in
            guard viewModel.isActive else {
                stopAnimations()
                return
            }
            // 状态切换时重置动画
            stopAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startAnimations()
            }
        }
        .onChange(of: viewModel.isActive) { isActive in
            if isActive {
                startAnimations()
            } else {
                stopAnimations()
            }
        }
    }

    private var contentView: some View {
        HStack(spacing: 10) {
            // 状态图标
            ZStack {
                // 背景圆圈
                Circle()
                    .fill(viewModel.state.color.opacity(0.2))
                    .frame(width: 28, height: 28)

                // 图标
                Image(systemName: viewModel.state.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.state.color)
                    .rotationEffect(.degrees(viewModel.state == .processing || viewModel.state == .rewriting ? rotation : 0))
            }
            .scaleEffect(isPulsing ? 1.1 : 1.0)

            Text(viewModel.state.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
        )
    }

    private func startAnimations() {
        // 脉冲动画
        withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            isPulsing = true
        }

        // 处理/改写状态下的旋转动画
        if viewModel.state == .processing || viewModel.state == .rewriting {
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        } else {
            rotation = 0
        }
    }

    private func stopAnimations() {
        isPulsing = false
        rotation = 0
    }
}
