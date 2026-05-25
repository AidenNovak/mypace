//
// MyPace · Control Experiment
// =====================================
// 跟 verify_spike.swift 完全相同的窗口，但 *不* 设置 sharingType = .none。
// 用来证明：截图里能看到它 → 反证 sharingType 是关键。
//

import Cocoa

class ControlApp: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let label = NSTextField(labelWithString: """
        ⚠️ Control Window (no sharingType)

        This window does NOT have:
          window.sharingType = .none

        🔴 It WILL appear in screen recordings.
        """)
        label.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBordered = false
        label.isEditable = false
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 200))
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        // 用鲜艳的红色背景 —— 极容易识别
        container.layer?.backgroundColor = NSColor.systemRed.cgColor
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        window = NSWindow(
            contentRect: NSRect(x: 800, y: 400, width: 460, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView = container
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // ❌ 故意 *不* 设置 sharingType
        // window.sharingType = .none  ← 注释掉

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("Control window shown · NO sharingType set")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = ControlApp()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
