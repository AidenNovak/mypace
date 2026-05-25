//
// MyPace · Core Technical Spike
// =================================
// 目的：在没有完整 Xcode 工程的前提下，验证 MyPace 最关键的一句代码：
//
//     window.sharingType = .none
//
// 这一行决定了 vlogger 录视频时浮动提词器是否会出现在画面里。
// 整个产品商业价值的"技术护城河"就这一句话。
//

import Cocoa

class SpikeApp: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var resultText = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        let label = NSTextField(labelWithString: """
        🔒 MyPace · Technical Spike

        This floating window has:
          window.sharingType = .none
          window.level = .statusBar
          window.collectionBehavior includes
          .canJoinAllSpaces + .fullScreenAuxiliary

        ✅ It is visible on your screen NOW.
        🚫 It should NOT appear in any screen recording.

        Press ⌘Q to quit.
        """)
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBordered = false
        label.isEditable = false
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 260))
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.94).cgColor
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        window = NSWindow(
            contentRect: NSRect(x: 300, y: 400, width: 480, height: 260),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // ---- 视觉 ----
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView = container

        // ---- 行为：始终置顶 + 全屏 App 上也可见 ----
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // ---- ✨ 核心：从屏幕录制中排除 ----
        if #available(macOS 13.0, *) {
            window.sharingType = .none
            resultText += "✅ window.sharingType set to .none\n"
        } else {
            resultText += "⚠️ macOS < 13.0, sharingType API unavailable\n"
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 状态报告
        print("─────────────────────────────────────────────")
        print("MyPace · Technical Spike Started")
        print("─────────────────────────────────────────────")
        print(resultText)
        print("Window properties:")
        print("  isOpaque: \(window.isOpaque)")
        print("  level: \(window.level.rawValue) (statusBar)")
        print("  collectionBehavior: \(window.collectionBehavior)")
        if #available(macOS 13.0, *) {
            print("  sharingType: \(window.sharingType.rawValue) (.none = 0)")
        }
        print("─────────────────────────────────────────────")
        print("👉 现在用 screencapture 截图：")
        print("   screencapture -x /tmp/mypace_verify.png")
        print("👉 然后用 open /tmp/mypace_verify.png 看图")
        print("👉 如果截图里 *没有* 这个窗口 → 技术验证通过")
        print("─────────────────────────────────────────────")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = SpikeApp()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
