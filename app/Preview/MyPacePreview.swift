//
//  MyPacePreview.swift  · v0.2
//  ====================================================
//  MyPace 公开预览版 v0.2
//  ====================================================
//  这一版能让 vlogger 体验完整核心功能：
//    1. 浮动透明窗口 + ScreenCaptureKit 排除（v0.1 已有）
//    2. 多稿件管理（JSON 存储）
//    3. 录音（AVAudioEngine → 16kHz mono WAV）
//    4. 火山引擎 ASR（用闪电说的凭证）
//    5. 节奏映射 → 按时间戳自动滚动
//    6. 阶段切换：编辑稿件 / 练习录音 / 节奏播放
//

import Cocoa

// MARK: - 应用阶段

enum AppStage {
    case ready              // 显示稿件，等待开始
    case recording          // 正在练习录音
    case aligning(Double)   // 正在生成节奏映射 (progress)
    case playing            // 按节奏自动滚动
    case error(String)
}

// MARK: - App Delegate

@MainActor
class PreviewApp: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var window: TransparentWindow?
    var contentView: PreviewContentView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("App launched · build \(Bundle.main.bundleIdentifier ?? "?")")
        logInfo("Mic permission: \(RecordingService.microphonePermissionStatus)")
        logInfo("Data dir: \(ScriptStore.dataDirectoryPath)")

        // 首次启动主动请求麦克风权限
        Task {
            let granted = await RecordingService.requestMicrophonePermission()
            logInfo("Mic permission after request: \(granted ? "granted" : "denied")")
        }

        // 首次启动显示欢迎页
        if !UserSettings.shared.hasSeenWelcome {
            WelcomeWindow.present { [weak self] in
                self?.showMainWindow()
            }
        } else {
            showMainWindow()
        }
    }

    private func showMainWindow() {
        let cv = PreviewContentView()
        contentView = cv

        // 用 .titled 而不是 .borderless ——
        // 原因：borderless 没有 resize hot zone，用户根本拖不动。
        // .titled 自带 macOS 原生 4 边 + 4 角 resize 行为，把 titlebar 透明化保持极简外观。
        //
        // 注意：故意 *不* 加 .fullSizeContentView ——
        // 否则右上角工具按钮会被 titlebar 区域截获 click 事件而点不动。
        // 不加这个 flag 后 contentView 自动从 titlebar (28 px) 下方开始，所有按钮自然可点击。
        let win = TransparentWindow(
            contentRect: NSRect(x: 200, y: 200, width: 620, height: 408),    // 380 + 28 titlebar
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.isMovableByWindowBackground = true

        // 完全隐藏 title bar 视觉元素，但保留 titlebar 区域用于 resize + 拖动
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        if #available(macOS 11.0, *) {
            win.titlebarSeparatorStyle = .none
        }
        for btn in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            win.standardWindowButton(btn)?.isHidden = true
        }

        win.contentView = cv
        win.contentView?.wantsLayer = true
        win.contentView?.layer?.cornerRadius = 16
        win.contentView?.layer?.masksToBounds = true
        // 尽可能给用户最大调整自由度
        // 极小：可以缩到迷你提示条级别
        // 极大：可以拉满整个显示器
        win.minSize = NSSize(width: 160, height: 90)
        win.maxSize = NSSize(width: 5000, height: 5000)
        // 移除高度上限，让用户可以自由把窗口拉得很高（提词器常用需求）
        win.maxSize = NSSize(width: 3000, height: 4000)
        win.alphaValue = UserSettings.shared.opacity

        win.level = .statusBar
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.delegate = self

        // ✨ ScreenCaptureKit 排除（v0.1 已 prove）
        // 用户在偏好设置可以临时打开（用于截图发反馈给我们）
        if #available(macOS 13.0, *) {
            win.sharingType = UserSettings.shared.allowScreenCapture ? .readWrite : .none
        }
        logInfo("[window] sharingType=\(UserSettings.shared.allowScreenCapture ? "readWrite (visible to capture)" : "none (hidden from capture)")")

        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        setupMenu()

        print("─────────────────────────────────────────────")
        print("MyPace · Preview Edition v0.2")
        print("─────────────────────────────────────────────")
        print("数据目录: \(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Application Support/MyPacePreview")
        let cred = ASRCredentials.auto()
        let source = ASRCredentials.fromUserDefaults() != nil ? "自定义" :
                     (ASRCredentials.fromShandianshuo() != nil ? "闪电说" : "内置")
        print("ASR 凭证: 已加载 (\(source) · app_id: \(cred.appID))")
        print("─────────────────────────────────────────────")
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    func setupMenu() {
        let appName = L(.appName)
        let mainMenu = NSMenu()

        // App
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(format: L(.menuAbout), appName), action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        let prefsItem = NSMenuItem(title: L(.menuPreferences), action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(prefsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(format: L(.menuQuit), appName), action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // 脚本菜单
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: L(.menuFile))
        let new = NSMenuItem(title: L(.menuNewScript), action: #selector(newScript), keyEquivalent: "n")
        new.keyEquivalentModifierMask = [.command]
        let edit = NSMenuItem(title: L(.menuEditScript), action: #selector(editScript), keyEquivalent: "e")
        edit.keyEquivalentModifierMask = [.command]
        let switchItem = NSMenuItem(title: L(.menuSwitchScript), action: #selector(switchScript), keyEquivalent: "o")
        switchItem.keyEquivalentModifierMask = [.command]
        fileMenu.addItem(new)
        fileMenu.addItem(edit)
        fileMenu.addItem(switchItem)
        fileMenuItem.submenu = fileMenu

        // 字号 / 数据
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: L(.menuView))
        let inc = NSMenuItem(title: L(.menuFontIncrease), action: #selector(increaseFontMenu), keyEquivalent: "=")
        inc.keyEquivalentModifierMask = [.command]
        let dec = NSMenuItem(title: L(.menuFontDecrease), action: #selector(decreaseFontMenu), keyEquivalent: "-")
        dec.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(inc)
        viewMenu.addItem(dec)
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: L(.menuShowDataFolder), action: #selector(openDataFolder), keyEquivalent: "")
        viewMenuItem.submenu = viewMenu

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(viewMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MyPace · Preview"
        alert.informativeText = "© MyPace Team"
        alert.runModal()
    }

    @objc func showPreferences() {
        PreferencesWindow.present { [weak self] in
            self?.contentView?.applySettings()
            self?.window?.alphaValue = UserSettings.shared.opacity
            if #available(macOS 13.0, *) {
                let newType: NSWindow.SharingType = UserSettings.shared.allowScreenCapture ? .readWrite : .none
                self?.window?.sharingType = newType
                logInfo("[settings] sharingType updated → \(UserSettings.shared.allowScreenCapture ? "readWrite" : "none")")
            }
        }
    }
    @objc func showWelcome() {
        WelcomeWindow.present { }
    }

    @objc func newScript()    { contentView?.newScript() }
    @objc func editScript()   { contentView?.editScript() }
    @objc func switchScript() { contentView?.switchScript() }
    @objc func deleteScript() { contentView?.deleteScript() }
    @objc func startPractice() { contentView?.startPractice() }
    @objc func playRhythm()   { contentView?.playRhythm() }

    @objc func increaseFontMenu() {
        UserSettings.shared.currentFontSize = min(78, UserSettings.shared.currentFontSize + 2)
        contentView?.applySettings()
        contentView?.needsLayout = true
    }
    @objc func decreaseFontMenu() {
        UserSettings.shared.currentFontSize = max(14, UserSettings.shared.currentFontSize - 2)
        contentView?.applySettings()
        contentView?.needsLayout = true
    }

    @objc func openDataFolder() {
        NSWorkspace.shared.open(ScriptStore.dataDirectoryURL)
        logInfo("[menu] openDataFolder: \(ScriptStore.dataDirectoryPath)")
    }
    @objc func openRecordingsFolder() {
        NSWorkspace.shared.open(ScriptStore.recordingsDirectoryURL)
        logInfo("[menu] openRecordingsFolder: \(ScriptStore.recordingsDirectoryURL.path)")
    }
    @objc func openLog() {
        let url = URL(fileURLWithPath: MyPaceLogger.logPath)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? "(MyPace 还没产生日志)".data(using: .utf8)?.write(to: url)
        }
        NSWorkspace.shared.open(url)
    }
    @objc func showMicStatus() {
        let alert = NSAlert()
        alert.messageText = "麦克风权限状态：\(RecordingService.microphonePermissionStatus)"
        alert.informativeText = """
        如果显示「已拒绝」，需要去：
        系统设置 → 隐私与安全 → 麦克风 → 勾选「MyPace Preview」。

        如果显示「未询问」，点下面「请求权限」会弹原生申请框。

        数据文件夹：\(ScriptStore.dataDirectoryPath)
        日志：\(MyPaceLogger.logPath)
        """
        alert.addButton(withTitle: "请求权限")
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "关闭")
        let r = alert.runModal()
        if r == .alertFirstButtonReturn {
            Task {
                let granted = await RecordingService.requestMicrophonePermission()
                logInfo("[manual] mic permission request → \(granted)")
            }
        } else if r == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
    }
}

// MARK: - 透明浮动窗口

final class TransparentWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - 内容视图

final class PreviewContentView: NSView {

    // MARK: 状态
    private(set) var stage: AppStage = .ready
    private(set) var currentScript: Script {
        didSet {
            ScriptStore.shared.save(currentScript)
            updateContent()
            controlBar.update(stage: stage, hasRhythm: currentScript.hasRhythm)
        }
    }
    private var currentIndex = 0
    /// 当前句里的第几个字，-1 表示句间停顿（字级跟读动效用）
    private var currentWordIndex: Int = -1

    // MARK: 服务
    private let recorder = RecordingService()
    private let playback = RhythmPlayback()

    // MARK: UI
    private let pastTopLabel = NSTextField(labelWithString: "")
    private let pastLabel = NSTextField(labelWithString: "")
    private let currentLabel = NSTextField(labelWithString: "")
    private let currentRun = WordRunView(frame: NSRect.zero)    // ✨ 字级缩放跟读
    private let nextLabel = NSTextField(labelWithString: "")
    private let nextNextLabel = NSTextField(labelWithString: "")

    private let topBar = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let stageLabel = NSTextField(labelWithString: "")
    private let recDot = NSView()
    private let levelBar = NSView()
    private let levelBarFill = NSView()
    private let progressBar = NSView()
    private let progressBarFill = NSView()
    private let bottomHint = NSTextField(labelWithString: "")
    private let controlBar = ControlBar(frame: .zero)

    // 右上角工具按钮组 (新建 / 编辑 / 切换稿件 / 偏好)
    private let toolNew = ToolbarMiniButton(systemSymbol: "plus", tooltip: L(.menuNewScript))
    private let toolEdit = ToolbarMiniButton(systemSymbol: "square.and.pencil", tooltip: L(.tooltipEditScript))
    private let toolSwitch = ToolbarMiniButton(systemSymbol: "square.stack", tooltip: L(.tooltipSwitchScript))
    private let toolPrefs = ToolbarMiniButton(systemSymbol: "slider.horizontal.3", tooltip: L(.tooltipPreferences))
    private var toolStack: NSStackView!

    private var hideTimer: Timer?
    private var levelFillWidthConstraint: NSLayoutConstraint!
    private var progressFillWidthConstraint: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        currentScript = ScriptStore.shared.scripts.first ?? .demo()
        super.init(frame: frameRect)
        setupUI()
        wireUp()
        updateContent()
        updateBottomHint()
        // 初始化按钮状态
        controlBar.update(stage: .ready, hasRhythm: currentScript.hasRhythm)
        updateStageLabel()
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        startRecDotBreathing()
        // 监听语言切换 —— 切换后立即刷新所有 UI 文字
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: L10n.languageChangedNotification,
            object: nil
        )
    }

    @objc private func handleLanguageChange() {
        // 主窗口内 UI
        updateContent()
        updateBottomHint()
        updateStageLabel()
        controlBar.refreshLocalization(stage: stage, hasRhythm: currentScript.hasRhythm)
        // 工具按钮 tooltip
        toolEdit.toolTip = L(.tooltipEditScript)
        toolSwitch.toolTip = L(.tooltipSwitchScript)
        toolPrefs.toolTip = L(.tooltipPreferences)
        // 重建菜单
        (NSApp.delegate as? PreviewApp)?.setupMenu()
    }

    // MARK: - UI 搭建

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.92).cgColor

        // -- 5 行文本 --
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX     // 居中显示
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        for lbl in [pastTopLabel, pastLabel, currentLabel, nextLabel, nextNextLabel] {
            lbl.isBordered = false
            lbl.isEditable = false
            lbl.backgroundColor = .clear
            lbl.lineBreakMode = .byWordWrapping
            lbl.maximumNumberOfLines = 2
            lbl.alignment = .center
            stack.addArrangedSubview(lbl)
        }
        addSubview(stack)

        // -- WordRunView 叠加在 currentLabel 上方 --
        currentRun.translatesAutoresizingMaskIntoConstraints = false
        currentRun.isHidden = true    // 默认隐藏，只在播放有 words 时显示
        addSubview(currentRun)
        NSLayoutConstraint.activate([
            currentRun.leadingAnchor.constraint(equalTo: currentLabel.leadingAnchor),
            currentRun.trailingAnchor.constraint(equalTo: currentLabel.trailingAnchor),
            currentRun.topAnchor.constraint(equalTo: currentLabel.topAnchor),
            currentRun.bottomAnchor.constraint(equalTo: currentLabel.bottomAnchor),
        ])

        // -- 右上角工具按钮 --
        toolStack = NSStackView(views: [toolNew, toolEdit, toolSwitch, toolPrefs])
        toolStack.orientation = .horizontal
        toolStack.spacing = 4
        toolStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toolStack)
        toolNew.target = self;    toolNew.action = #selector(toolNewTapped)
        toolEdit.target = self;   toolEdit.action = #selector(toolEditTapped)
        toolSwitch.target = self; toolSwitch.action = #selector(toolSwitchTapped)
        toolPrefs.target = self;  toolPrefs.action = #selector(toolPrefsTapped)

        // -- 顶部 bar --
        topBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBar)

        recDot.wantsLayer = true
        recDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        recDot.layer?.cornerRadius = 4
        recDot.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(recDot)

        stageLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        stageLabel.textColor = NSColor(white: 1.0, alpha: 0.85)
        stageLabel.backgroundColor = .clear
        stageLabel.isBordered = false
        stageLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(stageLabel)

        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = NSColor(white: 1.0, alpha: 0.4)
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)

        // -- level bar（录音时显示音量）/ progress bar（播放时显示进度）--
        levelBar.wantsLayer = true
        levelBar.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        levelBar.layer?.cornerRadius = 2
        levelBar.translatesAutoresizingMaskIntoConstraints = false
        levelBar.alphaValue = 0
        topBar.addSubview(levelBar)

        levelBarFill.wantsLayer = true
        levelBarFill.layer?.backgroundColor = NSColor.systemRed.cgColor
        levelBarFill.layer?.cornerRadius = 2
        levelBarFill.translatesAutoresizingMaskIntoConstraints = false
        levelBar.addSubview(levelBarFill)

        progressBar.wantsLayer = true
        progressBar.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        progressBar.layer?.cornerRadius = 2
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.alphaValue = 0
        topBar.addSubview(progressBar)

        progressBarFill.wantsLayer = true
        progressBarFill.layer?.backgroundColor = NSColor(red: 1.0, green: 0.54, blue: 0.12, alpha: 1).cgColor
        progressBarFill.layer?.cornerRadius = 2
        progressBarFill.translatesAutoresizingMaskIntoConstraints = false
        progressBar.addSubview(progressBarFill)

        // -- 控制按钮栏 --
        controlBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controlBar)

        // -- 底部 hint (现在更短了，主要展示当前状态)--
        bottomHint.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        bottomHint.textColor = NSColor(white: 1, alpha: 0.4)
        bottomHint.backgroundColor = .clear
        bottomHint.isBordered = false
        bottomHint.alignment = .center
        bottomHint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomHint)

        levelFillWidthConstraint = levelBarFill.widthAnchor.constraint(equalToConstant: 0)
        progressFillWidthConstraint = progressBarFill.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            // 右上角工具按钮组
            toolStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            toolStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            // top bar（避让工具按钮）
            topBar.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            topBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            topBar.trailingAnchor.constraint(equalTo: toolStack.leadingAnchor, constant: -12),
            topBar.heightAnchor.constraint(equalToConstant: 22),

            recDot.widthAnchor.constraint(equalToConstant: 8),
            recDot.heightAnchor.constraint(equalToConstant: 8),
            recDot.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            recDot.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            stageLabel.leadingAnchor.constraint(equalTo: recDot.trailingAnchor, constant: 8),
            stageLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: stageLabel.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: levelBar.leadingAnchor, constant: -8),

            levelBar.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            levelBar.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            levelBar.widthAnchor.constraint(equalToConstant: 120),
            levelBar.heightAnchor.constraint(equalToConstant: 4),

            levelBarFill.leadingAnchor.constraint(equalTo: levelBar.leadingAnchor),
            levelBarFill.topAnchor.constraint(equalTo: levelBar.topAnchor),
            levelBarFill.bottomAnchor.constraint(equalTo: levelBar.bottomAnchor),
            levelFillWidthConstraint,

            progressBar.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            progressBar.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            progressBar.widthAnchor.constraint(equalToConstant: 120),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            progressBarFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressBarFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressBarFill.bottomAnchor.constraint(equalTo: progressBar.bottomAnchor),
            progressFillWidthConstraint,

            // text stack —— 给主要阅读区域更多垂直空间
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topBar.bottomAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: controlBar.topAnchor, constant: -32),

            // 让 stack 在垂直方向上尽量占满可用空间（优先级稍低于必须的边距）
            {
                let c = stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6)
                c.priority = .defaultHigh
                return c
            }(),

            // control bar —— 固定在底部，保留最小间距
            controlBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            controlBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            controlBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -36),

            // hint —— 放在 controlBar 之下，留 8 px 间距，自适应底边
            bottomHint.topAnchor.constraint(equalTo: controlBar.bottomAnchor, constant: 8),
            bottomHint.centerXAnchor.constraint(equalTo: centerXAnchor),
            bottomHint.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
        ])

        // 连线 ControlBar 回调
        controlBar.onPrimary = { [weak self] in self?.primaryAction() }
        controlBar.onPrev    = { [weak self] in self?.seek(toIndex: max(0, (self?.currentIndex ?? 0) - 1)) }
        controlBar.onNext    = { [weak self] in
            guard let s = self else { return }
            s.seek(toIndex: min(s.currentScript.lines.count - 1, s.currentIndex + 1))
        }
    }

    override func layout() {
        super.layout()

        let h = bounds.height

        // 高度变化时，触发字体自适应
        if abs(h - lastLayoutHeight) > 6 {
            lastLayoutHeight = h
            updateContent()
            currentRun.needsLayout = true
        }

        // 极小窗口时优化观感（给用户最大自由度）
        if h < 160 {
            // 缩小圆角
            layer?.cornerRadius = max(6, h / 20)

            // 极小窗口时隐藏次要元素，保留核心阅读区 + 控制条
            let shouldHideSecondary = h < 130
            topBar.alphaValue = shouldHideSecondary ? 0.0 : 1.0
            levelBar.alphaValue = shouldHideSecondary ? 0.0 : levelBar.alphaValue
            progressBar.alphaValue = shouldHideSecondary ? 0.0 : progressBar.alphaValue
            stageLabel.alphaValue = shouldHideSecondary ? 0.0 : 1.0
            titleLabel.alphaValue = shouldHideSecondary ? 0.0 : 1.0
            recDot.alphaValue = shouldHideSecondary ? 0.0 : 1.0
        } else {
            // 恢复正常状态
            layer?.cornerRadius = 16
            topBar.alphaValue = 1.0
            stageLabel.alphaValue = 1.0
            titleLabel.alphaValue = 1.0
            recDot.alphaValue = 1.0
        }
    }

    private var lastLayoutHeight: CGFloat = 0

    /// 主按钮的智能动作：根据当前 stage 决定做什么
    private func primaryAction() {
        switch stage {
        case .ready:
            if currentScript.hasRhythm {
                playRhythm()    // 有节奏 → 播放
            } else {
                startPractice() // 没节奏 → 录音
            }
        case .recording:
            recorder.stop()     // 录音中 → 结束
        case .playing:
            playback.toggle()
            if !playback.isPlaying {
                setStage(.ready)
                currentIndex = playback.currentIndex
                updateContent()
            }
        case .aligning:
            break    // 对齐中按钮 disabled
        case .error:
            setStage(.ready)
        }
    }

    // MARK: - 状态机连线

    private func wireUp() {
        recorder.onLevel = { [weak self] lv in
            guard let self else { return }
            let width = max(0, min(120, CGFloat(lv) * 120))
            self.levelFillWidthConstraint.constant = width
        }

        recorder.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .recording:
                self.setStage(.recording)
            case .finished(let url, let duration):
                Task { await self.runAlignment(audioURL: url, duration: duration) }
            case .failed(let msg):
                self.setStage(.error(msg))
            case .idle, .requesting:
                break
            }
        }

        playback.onTick = { [weak self] sentenceIdx, wordIdx, time in
            guard let self else { return }
            let sentenceChanged = (self.currentIndex != sentenceIdx)
            let wordChanged = (self.currentWordIndex != wordIdx)
            self.currentIndex = sentenceIdx
            self.currentWordIndex = wordIdx
            // 句子变了 → 全部重渲染；只是字变了 → 只更新当前句
            if sentenceChanged {
                self.updateContent()
            } else if wordChanged {
                self.updateCurrentSentenceOnly()
            }
            let p = self.playback.progress
            self.progressFillWidthConstraint.constant = max(0, min(120, CGFloat(p) * 120))
        }
        playback.onComplete = { [weak self] in
            self?.setStage(.ready)
        }
    }

    // MARK: - 阶段切换

    func setStage(_ new: AppStage) {
        self.stage = new
        updateStageLabel()
        updateBottomHint()
        animateBars()
        controlBar.update(stage: new, hasRhythm: currentScript.hasRhythm)
        // 字级跟读模式：只在 playing 时启用，其他状态全亮等待
        if case .playing = new {
            currentRun.setMode(.tracking, animated: false)
        } else {
            currentRun.setMode(.idle, animated: false)
        }
        updateContent()    // 空稿件的占位文字依赖 stage

        // 错误用 alert 提示
        if case .error(let msg) = new {
            let alert = NSAlert()
            alert.messageText = "出错了"
            alert.informativeText = msg
            alert.alertStyle = .warning
            alert.runModal()
            self.stage = .ready
            updateStageLabel()
            updateBottomHint()
        }
    }

    private func updateStageLabel() {
        switch stage {
        case .ready:
            stageLabel.stringValue = L(.stageReady)
            stageLabel.textColor = NSColor(white: 1, alpha: 0.5)
            recDot.layer?.backgroundColor = NSColor(white: 1, alpha: 0.3).cgColor
        case .recording:
            stageLabel.stringValue = L(.stageRecording)
            stageLabel.textColor = NSColor.systemRed
            recDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        case .aligning(let p):
            stageLabel.stringValue = "\(L(.stageAligning)) \(Int(p*100))%"
            stageLabel.textColor = NSColor.systemOrange
            recDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        case .playing:
            stageLabel.stringValue = L(.stagePlaying)
            stageLabel.textColor = NSColor.systemGreen
            recDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        case .error:
            stageLabel.stringValue = "ERROR"
            stageLabel.textColor = NSColor.systemRed
        }
        titleLabel.stringValue = currentScript.title + (currentScript.hasRhythm ? "  ●" : "")
    }

    private func updateBottomHint() {
        switch stage {
        case .ready:
            if currentScript.hasRhythm {
                bottomHint.stringValue = L(.hintReadyWithRhythm)
            } else if currentScript.lines.isEmpty {
                bottomHint.stringValue = L(.hintReadyEmpty)
            } else {
                bottomHint.stringValue = L(.hintReadyWithScript)
            }
        case .recording:
            bottomHint.stringValue = L(.hintRecording)
        case .aligning:
            bottomHint.stringValue = L(.hintAligning)
        case .playing:
            bottomHint.stringValue = L(.hintPlaying)
        case .error:
            bottomHint.stringValue = ""
        }
    }

    private func animateBars() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            switch stage {
            case .recording:
                levelBar.animator().alphaValue = 1
                progressBar.animator().alphaValue = 0
            case .playing:
                levelBar.animator().alphaValue = 0
                progressBar.animator().alphaValue = 1
            default:
                levelBar.animator().alphaValue = 0
                progressBar.animator().alphaValue = 0
            }
        }
    }

    // MARK: - 内容更新

    /// 字级动效专用：只更新当前句的高亮（不重排其他行）
    private func updateCurrentSentenceOnly() {
        // 当前 WordRunView 已经显示，只需要切换 currentIdx 让动效播放
        if !currentRun.isHidden {
            currentRun.setCurrent(currentWordIndex, animated: true)
        } else {
            // 退化：用 NSAttributedString 渲染
            let n = currentScript.lines.count
            let i = max(0, min(currentIndex, max(0, n - 1)))
            currentLabel.attributedStringValue = styledCurrent(line(i), wordIdx: currentWordIndex)
        }
    }

    /// 判断当前应该用 WordRunView 还是普通 currentLabel 渲染
    private func shouldUseWordRun() -> Bool {
        guard !currentScript.lines.isEmpty,
              let rhythm = currentScript.rhythm,
              currentIndex >= 0,
              currentIndex < rhythm.segments.count,
              let words = rhythm.segments[currentIndex].words,
              !words.isEmpty else {
            return false
        }
        return true
    }

    private func updateContent() {
        // 特殊态：空稿件 + 录音中 → 显示「正在录音 + 说话提示」
        if currentScript.lines.isEmpty {
            currentRun.isHidden = true    // 占位文字不用字级跟读
            switch stage {
            case .recording:
                pastTopLabel.attributedStringValue   = styled("", .past)
                pastLabel.attributedStringValue      = styled(L(.promptRecordingNow), .next)
                currentLabel.attributedStringValue   = styled(L(.promptSpeakToMic), .current)
                nextLabel.attributedStringValue      = styled(L(.promptThenTapStop), .next)
                nextNextLabel.attributedStringValue  = styled(L(.promptAiWillProcess), .past)
                return
            case .aligning:
                pastTopLabel.attributedStringValue   = styled("", .past)
                pastLabel.attributedStringValue      = styled("", .past)
                currentLabel.attributedStringValue   = styled(L(.promptAligning), .current)
                nextLabel.attributedStringValue      = styled("", .next)
                nextNextLabel.attributedStringValue  = styled("", .past)
                return
            case .ready, .playing, .error:
                pastTopLabel.attributedStringValue   = styled("", .past)
                pastLabel.attributedStringValue      = styled("", .past)
                currentLabel.attributedStringValue   = styled(L(.promptTapToStart), .current)
                nextLabel.attributedStringValue      = styled(L(.promptSayItOut), .next)
                nextNextLabel.attributedStringValue  = styled("", .past)
                return
            }
        }

        // 正常态：有稿件，按句子显示
        let n = currentScript.lines.count
        let i = max(0, min(currentIndex, max(0, n - 1)))
        pastTopLabel.attributedStringValue   = styled(line(i - 2), .past)
        pastLabel.attributedStringValue      = styled(line(i - 1), .past)
        nextLabel.attributedStringValue      = styled(line(i + 1), .next)
        nextNextLabel.attributedStringValue  = styled(line(i + 2), .future)

        // 当前句：根据是否有 word timestamps 选渲染方式
        if shouldUseWordRun(), let rhythm = currentScript.rhythm,
           let words = rhythm.segments[currentIndex].words {
            // 用 WordRunView 字级渲染
            currentLabel.attributedStringValue = styledCurrent("", wordIdx: -1)    // 清空 label
            currentLabel.isHidden = false    // 仍占位（高度需要）
            let effSize = effectiveFontSize()
            currentLabel.attributedStringValue = NSAttributedString(string: line(i), attributes: [
                .font: NSFont.systemFont(ofSize: effSize, weight: .semibold),
                .foregroundColor: NSColor.clear    // 透明，占空间但不显示
            ])
            currentRun.isHidden = false
            currentRun.fontSize = effSize
            currentRun.accentColor = UserSettings.shared.accentColor.color
            currentRun.setWords(words.map(\.text), currentIdx: currentWordIndex)
        } else {
            // 退化：普通 NSAttributedString 渲染
            currentRun.isHidden = true
            currentLabel.attributedStringValue = styledCurrent(line(i), wordIdx: currentWordIndex)
        }
    }

    /// 字级渲染：当前句的每个字根据距离当前字的远近，用不同 opacity
    /// 没有 word timestamps 时退化为统一橙色（跟之前一样）
    private func styledCurrent(_ text: String, wordIdx: Int) -> NSAttributedString {
        if text.isEmpty { return NSAttributedString(string: " ") }

        let settings = UserSettings.shared
        let currentSize = effectiveFontSize()
        let accent = settings.accentColor.color

        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        let baseFont = NSFont.systemFont(ofSize: currentSize, weight: .semibold)

        // 没有播放中 或 没有 word index → 整句统一颜色（无字级动效）
        guard wordIdx >= 0,
              currentIndex >= 0,
              let rhythm = currentScript.rhythm,
              currentIndex < rhythm.segments.count,
              let words = rhythm.segments[currentIndex].words,
              !words.isEmpty else {
            return NSAttributedString(string: text, attributes: [
                .font: baseFont,
                .foregroundColor: accent,
                .paragraphStyle: para
            ])
        }

        // ✨ 字级渲染
        // 当前字：100% accent + 微弱发光
        // ±1 字：85% accent
        // ±2 字：65% accent
        // 已念过的字（前面更远）：白色 28% （已消化）
        // 未念到的字（后面更远）：accent 50% （等待）
        let result = NSMutableAttributedString()
        for (i, w) in words.enumerated() {
            let dist = i - wordIdx
            let color: NSColor
            switch dist {
            case 0:
                color = accent      // 当前字
            case -1, 1:
                color = accent.withAlphaComponent(0.82)
            case -2, 2:
                color = accent.withAlphaComponent(0.60)
            case let d where d < -2:
                color = NSColor.white.withAlphaComponent(0.28)    // 已念
            default:
                color = accent.withAlphaComponent(0.42)            // 未念
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: color,
                .paragraphStyle: para
            ]
            result.append(NSAttributedString(string: w.text, attributes: attrs))
        }
        return result
    }

    private func line(_ i: Int) -> String {
        guard i >= 0 && i < currentScript.lines.count else { return "" }
        return currentScript.lines[i]
    }

    /// 根据窗口高度计算当前应该使用的字号（在用户设置基础上轻微缩放）
    private func effectiveFontSize() -> CGFloat {
        let base = UserSettings.shared.currentFontSize
        let h = max(320, bounds.height)

        // 参考高度 720pt 时 = 1.0 倍
        let referenceHeight: CGFloat = 720
        let rawScale = h / referenceHeight

        // 限制缩放范围，避免极端情况
        let scale = min(max(rawScale, 0.72), 1.65)

        return max(14, min(92, base * scale))
    }

    private enum LineStyle { case past, current, next, future }

    private func styled(_ text: String, _ style: LineStyle) -> NSAttributedString {
        if text.isEmpty { return NSAttributedString(string: " ") }
        let settings = UserSettings.shared
        let currentSize = effectiveFontSize()
        let pastSize = max(11, currentSize * 0.52)
        let nextSize = max(13, currentSize * 0.60)
        let accentColor = settings.accentColor.color

        let font: NSFont
        let color: NSColor
        switch style {
        case .past:    font = .systemFont(ofSize: pastSize, weight: .regular); color = NSColor(white: 1.0, alpha: 0.22)
        case .current: font = .systemFont(ofSize: currentSize, weight: .semibold); color = accentColor
        case .next:    font = .systemFont(ofSize: nextSize, weight: .medium); color = NSColor(white: 1.0, alpha: 0.45)
        case .future:  font = .systemFont(ofSize: pastSize, weight: .regular); color = NSColor(white: 1.0, alpha: 0.22)
        }
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        return NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: para
        ])
    }

    /// 偏好设置改变时调用
    func applySettings() {
        updateContent()
        // 重启呼吸动画（如果关了就移除）
        recDot.layer?.removeAnimation(forKey: "breathe")
        if UserSettings.shared.breathingDot {
            startRecDotBreathing()
        }
    }

    private func startRecDotBreathing() {
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 0.55
        a.toValue = 1.0
        a.duration = 1.2
        a.autoreverses = true
        a.repeatCount = .infinity
        recDot.layer?.add(a, forKey: "breathe")
    }

    // MARK: - 键盘事件

    override func keyDown(with event: NSEvent) {
        switch (event.keyCode, stage) {
        case (49, .ready):    // Space @ ready → 播放（如有节奏）
            if currentScript.hasRhythm { playRhythm() }
        case (49, .recording):    // Space @ recording → 结束
            recorder.stop()
        case (49, .playing):    // Space @ playing → 暂停
            playback.toggle()
        case (53, _):    // Esc → 重置
            cancelCurrent()
        case (126, _):    // ↑
            seek(toIndex: max(0, currentIndex - 1))
        case (125, _):    // ↓
            seek(toIndex: min(currentScript.lines.count - 1, currentIndex + 1))
        case (14, _):    // E
            if event.modifierFlags.contains(.command) { editScript() }
        case (24, _):    // = (with cmd → 字号 +)
            if event.modifierFlags.contains(.command) {
                let s = UserSettings.shared
                s.currentFontSize = min(56, s.currentFontSize + 2)
                applySettings()
            }
        case (27, _):    // - (with cmd → 字号 -)
            if event.modifierFlags.contains(.command) {
                let s = UserSettings.shared
                s.currentFontSize = max(18, s.currentFontSize - 2)
                applySettings()
            }
        default:
            super.keyDown(with: event)
        }
    }

    private func seek(toIndex i: Int) {
        currentIndex = i
        if case .playing = stage { playback.seek(toIndex: i) }
        updateContent()
    }

    private func cancelCurrent() {
        switch stage {
        case .recording:
            recorder.stop()
            setStage(.ready)
        case .playing:
            playback.pause()
            playback.reset()
            setStage(.ready)
        default: break
        }
    }

    // MARK: - 动作（菜单调用）

    func newScript() {
        let s = Script(title: "\(L(.untitledScript)) \(Date().formatted(.dateTime.month().day()))")
        ScriptStore.shared.save(s)
        currentScript = s
        currentIndex = 0
        editScript()
    }

    // 右上角工具按钮 actions —— 简单转发给已有方法
    @objc func toolNewTapped()    { newScript() }
    @objc func toolEditTapped()   { editScript() }
    @objc func toolSwitchTapped() { switchScript() }
    @objc func toolPrefsTapped() {
        PreferencesWindow.present { [weak self] in self?.applySettings() }
    }

    func editScript() {
        let alert = NSAlert()
        alert.messageText = "编辑稿件"
        alert.informativeText = "标题 + 内容（每行一句话）"

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 320))

        let titleField = NSTextField(frame: NSRect(x: 0, y: 280, width: 460, height: 28))
        titleField.stringValue = currentScript.title
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        container.addSubview(titleField)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 270))
        scroll.hasVerticalScroller = true
        let textView = NSTextView(frame: scroll.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.font = .systemFont(ofSize: 13)
        textView.string = currentScript.lines.joined(separator: "\n")
        scroll.documentView = textView
        container.addSubview(scroll)

        alert.accessoryView = container
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            var s = currentScript
            s.title = titleField.stringValue.isEmpty ? "未命名" : titleField.stringValue
            s.lines = textView.string.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            // 内容变了，已有节奏作废
            if s.lines != currentScript.lines {
                s.rhythm = nil
            }
            currentScript = s
            currentIndex = 0
            updateStageLabel()
            updateBottomHint()
        }
    }

    func switchScript() {
        let scripts = ScriptStore.shared.scripts
        guard !scripts.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "切换稿件"
        alert.informativeText = "共 \(scripts.count) 个稿件"

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 28))
        for (i, s) in scripts.enumerated() {
            let mark = s.hasRhythm ? " ●" : ""
            popup.addItem(withTitle: "\(s.title)\(mark)")
            if s.id == currentScript.id { popup.selectItem(at: i) }
        }
        alert.accessoryView = popup
        alert.addButton(withTitle: "切换")
        alert.addButton(withTitle: "新建稿件")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let idx = popup.indexOfSelectedItem
            if scripts.indices.contains(idx) {
                currentScript = scripts[idx]
                currentIndex = 0
                setStage(.ready)
            }
        } else if response == .alertSecondButtonReturn {
            // 用户点了“新建稿件”
            newScript()
        }
    }

    func deleteScript() {
        let alert = NSAlert()
        alert.messageText = "确认删除？"
        alert.informativeText = "「\(currentScript.title)」将被永久删除。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            ScriptStore.shared.delete(currentScript)
            currentScript = ScriptStore.shared.scripts.first ?? Script(title: "未命名")
            if ScriptStore.shared.scripts.isEmpty {
                ScriptStore.shared.save(currentScript)
            }
            currentIndex = 0
        }
    }

    func startPractice() {
        guard case .ready = stage else { return }
        // 空稿件 OK —— 这就是「口述模式」：录音 → ASR → 自动生成稿件 + 节奏
        // 非空稿件 → 念稿模式：录音 → 对齐稿件 → 节奏映射

        let mode = currentScript.lines.isEmpty ? "口述" : "念稿"
        logInfo("[practice] start mode=\(mode) scriptLines=\(currentScript.lines.count)")

        // 主动请求麦克风权限
        Task { [weak self] in
            guard let self else { return }
            let granted = await RecordingService.requestMicrophonePermission()
            logInfo("[practice] mic permission = \(granted)")
            if !granted {
                self.setStage(.error("麦克风权限被拒绝。\n\n请到 系统设置 → 隐私与安全 → 麦克风 → 勾选「MyPace Preview」，然后重启 app。"))
                return
            }
            let url = ScriptStore.shared.newRecordingURL()
            self.currentIndex = 0
            self.recorder.start(saveTo: url)
        }
    }

    func playRhythm() {
        guard let rhythm = currentScript.rhythm else {
            setStage(.error("当前稿件还没有节奏映射。先按 ⇧⌘R 录一次音生成节奏。"))
            return
        }
        playback.reset()
        playback.load(rhythm: rhythm)
        playback.start()
        setStage(.playing)
    }

    private func runAlignment(audioURL: URL, duration: TimeInterval) async {
        let cred = ASRCredentials.auto()
        let source = ASRCredentials.fromUserDefaults() != nil ? "自定义" :
                     (ASRCredentials.fromShandianshuo() != nil ? "闪电说" : "内置")
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
        logInfo("[ASR] start cred=\(source) file=\(audioURL.lastPathComponent) size=\(fileSize)B duration=\(String(format: "%.2f", duration))s")

        setStage(.aligning(0))

        do {
            let asr = VolcengineASR(credentials: cred)
            let segments = try await asr.transcribe(audioURL: audioURL) { [weak self] p in
                Task { @MainActor in
                    self?.setStage(.aligning(p))
                }
            }

            logInfo("[ASR] done segments=\(segments.count) firstText=\(segments.first?.text.prefix(30) ?? "(empty)")")

            // 空 ASR 结果保护
            guard !segments.isEmpty else {
                setStage(.error("识别失败：录音里没有检测到语音。\n请检查麦克风是否离嘴近一点，或者重试。"))
                return
            }

            var s = currentScript
            let wasEmpty = s.lines.isEmpty

            // ✨ 核心：空稿件就用 ASR 结果作为稿件（口述模式）
            if wasEmpty {
                logInfo("[ASR] auto-filling script from ASR text (\(segments.count) sentences)")
                s.lines = segments.map { $0.text }
                if s.title.contains("示例") || s.title.contains("未命名") {
                    // 自动改个有意义的标题：用第一句的前 12 字
                    if let first = segments.first?.text, !first.isEmpty {
                        s.title = String(first.prefix(12)) + (first.count > 12 ? "…" : "")
                    }
                }
            }

            s.rhythm = RhythmMap(
                segments: segments,
                audioFilename: audioURL.lastPathComponent,
                totalDuration: duration,
                createdAt: .now
            )
            currentScript = s
            currentIndex = 0

            logInfo("[ASR] script updated wasEmpty=\(wasEmpty) → lines=\(s.lines.count) title=\(s.title)")

            // ✨ 重置到第一句开头，等用户点 ▶ 才开始播放
            currentIndex = 0
            currentWordIndex = -1
            setStage(.ready)
            // 不再自动 playRhythm() —— 把控制权交给用户

        } catch {
            logError("[ASR] failed: \(error.localizedDescription)")
            setStage(.error("节奏对齐失败：\n\(error.localizedDescription)"))
        }
    }
}

// MARK: - main

@main
@MainActor
struct AppLauncher {
    static func main() {
        let app = NSApplication.shared
        let delegate = PreviewApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
