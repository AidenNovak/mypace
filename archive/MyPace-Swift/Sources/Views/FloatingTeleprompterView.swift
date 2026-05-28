//
//  FloatingTeleprompterView.swift
//  MyPace
//
//  浮动提词器 —— 对应 tahoe.html 的 #v5 部分。
//  这是 vlogger 真正用来"看着念稿"的界面。
//  通过 WindowManager 装进一个 always-on-top + ScreenCaptureKit 排除的 NSWindow。
//

import SwiftUI

struct FloatingTeleprompterView: View {
    let script: Script

    @State private var currentLineIndex: Int = 0
    @State private var isPaused: Bool = true
    @State private var showControls: Bool = true
    @State private var hideControlsTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            // 半透深色玻璃背景
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: 0x0D0905).opacity(0.92))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 18) {
                // ---- 当前行（大字 + 引导线）----
                VStack(alignment: .leading, spacing: 0) {
                    Text(currentLine)
                        .font(.pmTeleprompter)
                        .foregroundStyle(Color(hex: 0xFFF7E8))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(8)
                    Rectangle()
                        .fill(Color.appOrange)
                        .frame(height: 1)
                        .opacity(0.4)
                        .padding(.top, 8)
                }

                // ---- 下一行（半透）----
                Text(nextLine)
                    .font(.pmTeleNext)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)

                Spacer()

                // ---- 底部状态 ----
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.appRed)
                        .frame(width: 7, height: 7)
                        .shadow(color: .appRed, radius: 4)
                    Text("REC · \(timecodeString) / 05:30")
                        .font(.pmMonoSmall)
                        .foregroundStyle(.white.opacity(0.4))
                    Text("句 \(currentLineIndex + 1) / \(lines.count)")
                        .font(.pmMonoSmall)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(32)

            // ---- 右上角控件（hover 显示）----
            if showControls {
                HStack(spacing: 5) {
                    ControlMiniBtn(symbol: "minus") { /* minimize */ }
                    ControlMiniBtn(symbol: "rectangle") { /* fullscreen */ }
                    ControlMiniBtn(symbol: "xmark") {
                        WindowManager.shared.closeFloatingTeleprompter()
                    }
                }
                .padding(14)
                .transition(.opacity)
            }
        }
        .frame(minWidth: 360, minHeight: 220)
        .onHover { hovering in
            showControlsTemporarily()
        }
        // ---- 键盘快捷键 ----
        // Space = 暂停/继续
        // ↑↓ = 上一句/下一句
        // ⌘W = 关闭
        .background(
            KeyboardListenerView { event in
                handleKey(event)
            }
        )
        .onAppear { showControlsTemporarily() }
    }

    // MARK: - 计算属性

    private var lines: [String] {
        // 简化：按行分割稿件（生产环境应该按句子分割）
        script.content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.starts(with: "---") && !$0.starts(with: "#") }
    }

    private var currentLine: String {
        lines.indices.contains(currentLineIndex) ? lines[currentLineIndex] : "（脚本为空）"
    }

    private var nextLine: String {
        let next = currentLineIndex + 1
        return lines.indices.contains(next) ? lines[next] : ""
    }

    private var timecodeString: String {
        let secs = currentLineIndex * 3  // 占位估算
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    // MARK: - Actions

    private func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 49: // Space
            isPaused.toggle()
        case 126: // ↑
            currentLineIndex = max(0, currentLineIndex - 1)
        case 125: // ↓
            currentLineIndex = min(lines.count - 1, currentLineIndex + 1)
        case 13: // W (with cmd → close)
            if event.modifierFlags.contains(.command) {
                WindowManager.shared.closeFloatingTeleprompter()
            }
        default:
            break
        }
    }

    private func showControlsTemporarily() {
        showControls = true
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
    }
}

// MARK: - 右上角小按钮

struct ControlMiniBtn: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 键盘监听包装器（让浮动窗口能接收键盘事件）

/// SwiftUI 的 .keyboardShortcut 在 borderless 窗口里有时不灵
/// 这个包装器让我们直接拿到 NSEvent，更可靠
struct KeyboardListenerView: NSViewRepresentable {
    let onKey: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyResponderView()
        view.onKey = onKey
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class KeyResponderView: NSView {
        var onKey: ((NSEvent) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }
        override func keyDown(with event: NSEvent) {
            onKey?(event)
        }
    }
}
