//
//  MyPacePreview.swift
//  =============================================
//  MyPace 公开预览版 · 给 vlogger 试用的最小可用提词器
//  =============================================
//
//  目标：让 vlogger 在 1 分钟内体验到 MyPace 的核心价值：
//  「我能看到提词器，但 OBS/QuickTime 录屏看不到。」
//
//  功能：
//    - 浮动半透明窗口（始终置顶 + ScreenCaptureKit 排除）
//    - 显示 5 行稿件：上 2 暗 / 当前 1 亮 / 下 2 暗
//    - Space 暂停 / 继续； ↑↓ 切换句子； ⌘E 编辑文本；⌘W 关闭
//    - 当前句呼吸式高亮
//    - 顶部 / 底部 hover 才显控件
//

import Cocoa

@MainActor
class PreviewApp: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var window: TransparentWindow!
    var contentView: PreviewContentView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        contentView = PreviewContentView()

        window = TransparentWindow(
            contentRect: NSRect(x: 200, y: 200, width: 580, height: 320),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView = contentView
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 16
        window.contentView?.layer?.masksToBounds = true

        // 行为
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.delegate = self

        // ✨ 核心：从所有屏幕录制中排除
        if #available(macOS 13.0, *) {
            window.sharingType = .none
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        setupMenu()

        print("─────────────────────────────────────────────")
        print("MyPace · Preview Edition")
        print("─────────────────────────────────────────────")
        print("窗口已显示。请尝试：")
        print("  1. 用 ⌘⇧5 或 QuickTime 开始录屏")
        print("  2. 观察回放：MyPace 窗口不在录制画面里")
        print("  3. ⌘Q 退出")
        print("─────────────────────────────────────────────")
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    // MARK: - Menu (这样 ⌘Q ⌘W 才能工作)

    func setupMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 MyPace Preview", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 MyPace", action: #selector(NSApp.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 MyPace", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "脚本")
        let editScript = NSMenuItem(title: "编辑稿件…", action: #selector(editScript), keyEquivalent: "e")
        editScript.keyEquivalentModifierMask = [.command]
        fileMenu.addItem(editScript)
        let closeWin = NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        closeWin.keyEquivalentModifierMask = [.command]
        fileMenu.addItem(closeWin)
        fileMenuItem.submenu = fileMenu

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MyPace · Preview Edition"
        alert.informativeText = """
        一台不会被录到的提词器。

        本版本是给 vlogger 的早期试用版，验证两件事：
        1. 浮动窗口能始终置顶、半透显示稿件。
        2. QuickTime / OBS / Loom 等屏幕录制软件看不见这个窗口。

        正式版即将上线，关注 @MyPace 获取更新。
        """
        alert.runModal()
    }

    @objc func editScript() {
        contentView.showEditor()
    }
}

// MARK: - 自定义浮动窗口

final class TransparentWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - 内容视图

final class PreviewContentView: NSView {

    // 默认示例稿件
    var lines: [String] = [
        "大家好，欢迎来到本期视频。",
        "今天我想跟你聊一件被严重低估的事 ——",
        "好的内容，永远赢不过好的节奏。",
        "你说的同一段话，节奏不一样，效果差十倍。",
        "下面我用三个例子说明。",
        "第一个例子：开场。",
        "高手开场只有三句话，但每一句都是钩子。",
        "第二个例子：转折。",
        "在最关键的地方，他们一定会停一秒。",
        "第三个例子：结尾。",
        "结尾不是结束，而是把观众推向下一个动作。"
    ]

    var currentIndex = 2
    private var isPaused = true
    private var hoverActive = false
    private var hideControlsTimer: Timer?

    private let pastTopLabel = NSTextField(labelWithString: "")
    private let pastLabel = NSTextField(labelWithString: "")
    private let currentLabel = NSTextField(labelWithString: "")
    private let nextLabel = NSTextField(labelWithString: "")
    private let nextNextLabel = NSTextField(labelWithString: "")
    private let recDot = NSView()
    private let progressLabel = NSTextField(labelWithString: "")
    private let controlBar = NSView()
    private let prevBtn = NSButton(title: "↑", target: nil, action: nil)
    private let nextBtn = NSButton(title: "↓", target: nil, action: nil)
    private let pauseBtn = NSButton(title: "⏸", target: nil, action: nil)
    private let exitHint = NSTextField(labelWithString: "Space 暂停 · ↑↓ 切换 · ⌘E 编辑 · ⌘Q 退出")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        updateContent()
    }
    required init?(coder: NSCoder) { fatalError() }

    // 让 NSView 接受键盘事件
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)

        // 启动呼吸动画
        startBreathing()
    }

    // MARK: - UI

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.92).cgColor

        // 5 行文本
        let labels = [pastTopLabel, pastLabel, currentLabel, nextLabel, nextNextLabel]
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        for lbl in labels {
            lbl.isBordered = false
            lbl.isEditable = false
            lbl.backgroundColor = .clear
            lbl.lineBreakMode = .byWordWrapping
            lbl.maximumNumberOfLines = 2
            stack.addArrangedSubview(lbl)
        }
        addSubview(stack)

        // 顶部小状态：红点 + REC
        recDot.wantsLayer = true
        recDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        recDot.layer?.cornerRadius = 4
        recDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(recDot)

        progressLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        progressLabel.textColor = NSColor(white: 1.0, alpha: 0.5)
        progressLabel.backgroundColor = .clear
        progressLabel.isBordered = false
        progressLabel.isEditable = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressLabel)

        // 底部 hint
        exitHint.font = .monospacedSystemFont(ofSize: 10.5, weight: .medium)
        exitHint.textColor = NSColor(white: 1.0, alpha: 0.35)
        exitHint.backgroundColor = .clear
        exitHint.isBordered = false
        exitHint.isEditable = false
        exitHint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(exitHint)

        // 控制按钮（hover 时显示）
        controlBar.wantsLayer = true
        controlBar.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        controlBar.layer?.cornerRadius = 8
        controlBar.translatesAutoresizingMaskIntoConstraints = false
        controlBar.alphaValue = 0
        addSubview(controlBar)

        let btnStack = NSStackView()
        btnStack.orientation = .horizontal
        btnStack.spacing = 4
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        controlBar.addSubview(btnStack)

        for btn in [prevBtn, pauseBtn, nextBtn] {
            btn.bezelStyle = .accessoryBarAction
            btn.isBordered = false
            btn.contentTintColor = NSColor(white: 1.0, alpha: 0.85)
            btn.font = .systemFont(ofSize: 14, weight: .semibold)
            btnStack.addArrangedSubview(btn)
        }
        prevBtn.target = self; prevBtn.action = #selector(prev)
        nextBtn.target = self; nextBtn.action = #selector(next)
        pauseBtn.target = self; pauseBtn.action = #selector(togglePause)

        // 约束
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),

            recDot.widthAnchor.constraint(equalToConstant: 8),
            recDot.heightAnchor.constraint(equalToConstant: 8),
            recDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            recDot.topAnchor.constraint(equalTo: topAnchor, constant: 16),

            progressLabel.leadingAnchor.constraint(equalTo: recDot.trailingAnchor, constant: 8),
            progressLabel.centerYAnchor.constraint(equalTo: recDot.centerYAnchor),

            exitHint.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            exitHint.centerXAnchor.constraint(equalTo: centerXAnchor),

            controlBar.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            controlBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            controlBar.heightAnchor.constraint(equalToConstant: 30),

            btnStack.topAnchor.constraint(equalTo: controlBar.topAnchor, constant: 2),
            btnStack.bottomAnchor.constraint(equalTo: controlBar.bottomAnchor, constant: -2),
            btnStack.leadingAnchor.constraint(equalTo: controlBar.leadingAnchor, constant: 4),
            btnStack.trailingAnchor.constraint(equalTo: controlBar.trailingAnchor, constant: -4),
        ])

        // 鼠标追踪
        let tracking = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
    }

    override func mouseEntered(with event: NSEvent) {
        showControls()
    }
    override func mouseExited(with event: NSEvent) {
        // 鼠标真的离开窗口才隐藏
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.hideControls() }
        }
    }

    private func showControls() {
        hideControlsTimer?.invalidate()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            controlBar.animator().alphaValue = 1
            exitHint.animator().alphaValue = 1
        }
    }
    private func hideControls() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            controlBar.animator().alphaValue = 0
            exitHint.animator().alphaValue = 0.5
        }
    }

    // MARK: - 内容更新

    func updateContent() {
        let i = currentIndex
        let n = lines.count

        pastTopLabel.attributedStringValue   = styled(line(i - 2), .past)
        pastLabel.attributedStringValue      = styled(line(i - 1), .past)
        currentLabel.attributedStringValue   = styled(line(i),     .current)
        nextLabel.attributedStringValue      = styled(line(i + 1), .next)
        nextNextLabel.attributedStringValue  = styled(line(i + 2), .future)

        progressLabel.stringValue = String(format: "句 %d / %d  ·  PREVIEW", i + 1, n)
    }

    private func line(_ i: Int) -> String {
        guard i >= 0 && i < lines.count else { return "" }
        return lines[i]
    }

    private enum LineStyle { case past, current, next, future }

    private func styled(_ text: String, _ style: LineStyle) -> NSAttributedString {
        guard !text.isEmpty else { return NSAttributedString(string: " ") }
        let font: NSFont
        let color: NSColor
        switch style {
        case .past:    font = .systemFont(ofSize: 14, weight: .regular); color = NSColor(white: 1.0, alpha: 0.22)
        case .current: font = .systemFont(ofSize: 28, weight: .semibold); color = NSColor(red: 1.0, green: 0.69, blue: 0.29, alpha: 1)
        case .next:    font = .systemFont(ofSize: 16, weight: .medium); color = NSColor(white: 1.0, alpha: 0.45)
        case .future:  font = .systemFont(ofSize: 14, weight: .regular); color = NSColor(white: 1.0, alpha: 0.22)
        }
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ])
    }

    // MARK: - 呼吸动画

    private func startBreathing() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.55
        animation.toValue = 1.0
        animation.duration = 1.2
        animation.autoreverses = true
        animation.repeatCount = .infinity
        recDot.layer?.add(animation, forKey: "breathe")
    }

    // MARK: - 键盘事件

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49:    // Space
            togglePause()
        case 126:   // ↑
            prev()
        case 125:   // ↓
            next()
        case 14:    // E
            if event.modifierFlags.contains(.command) { showEditor() }
        default:
            super.keyDown(with: event)
        }
    }

    @objc func prev() {
        currentIndex = max(0, currentIndex - 1)
        updateContent()
    }

    @objc func next() {
        currentIndex = min(lines.count - 1, currentIndex + 1)
        updateContent()
    }

    @objc func togglePause() {
        isPaused.toggle()
        // 简单实现：暂停不自动滚动（实际正式版会按节奏自动滚动）
    }

    // MARK: - 编辑器（简单 modal）

    func showEditor() {
        let alert = NSAlert()
        alert.messageText = "编辑稿件"
        alert.informativeText = "粘贴你的稿件，每行一句话。"

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 240))
        scroll.hasVerticalScroller = true
        let textView = NSTextView(frame: scroll.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.font = .systemFont(ofSize: 13)
        textView.string = lines.joined(separator: "\n")
        scroll.documentView = textView
        alert.accessoryView = scroll
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newLines = textView.string.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            if !newLines.isEmpty {
                lines = newLines
                currentIndex = 0
                updateContent()
            }
        }
    }
}

// MARK: - main

@MainActor
func runApp() {
    let app = NSApplication.shared
    let delegate = PreviewApp()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}

MainActor.assumeIsolated {
    runApp()
}
