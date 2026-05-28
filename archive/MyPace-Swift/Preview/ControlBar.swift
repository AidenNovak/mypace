//
//  ControlBar.swift
//  MyPace Preview v0.4
//
//  浮窗底部的"明显按钮组" —— 替代键盘快捷键，对 vlogger 友好。
//  按 stage 动态切换按钮。
//

import Cocoa

@MainActor
final class ControlBar: NSView {

    // MARK: - 回调（由 ContentView 注入）

    var onPrimary: () -> Void = {}      // 录音 / 播放 / 暂停 / 停止
    var onPrev:    () -> Void = {}
    var onNext:    () -> Void = {}

    // MARK: - 内部
    // 注意：编辑/切换/设置 按钮已迁移到 topBar 右上角（macOS 标准工具栏位置），
    // 让 ControlBar 只承载"当前主动作"和"上下句导航" —— 视觉上更聚焦。

    private let primaryBtn = PrimaryButton()
    private let prevBtn = MiniButton(systemSymbol: "chevron.up", tooltip: L(.tooltipPrevLine))
    private let nextBtn = MiniButton(systemSymbol: "chevron.down", tooltip: L(.tooltipNextLine))

    private var navStack: NSStackView!

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    private func setup() {
        wantsLayer = true
        #if DEBUG_LAYOUT
        layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.15).cgColor
        layer?.borderColor = NSColor.systemGreen.cgColor
        layer?.borderWidth = 1
        #else
        layer?.backgroundColor = NSColor.clear.cgColor
        #endif

        primaryBtn.translatesAutoresizingMaskIntoConstraints = false
        primaryBtn.target = self
        primaryBtn.action = #selector(primaryTapped)

        navStack = NSStackView(views: [prevBtn, nextBtn])
        navStack.orientation = .horizontal
        navStack.spacing = 6
        navStack.translatesAutoresizingMaskIntoConstraints = false
        prevBtn.target = self; prevBtn.action = #selector(prevTapped)
        nextBtn.target = self; nextBtn.action = #selector(nextTapped)
        #if DEBUG_LAYOUT
        navStack.wantsLayer = true
        navStack.layer?.borderColor = NSColor.systemBlue.cgColor
        navStack.layer?.borderWidth = 1
        #endif

        addSubview(navStack)
        addSubview(primaryBtn)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 50),

            // 主按钮：往右偏 18px —— 跟右上角的工具按钮形成视觉重心平衡
            primaryBtn.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 18),
            primaryBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            primaryBtn.heightAnchor.constraint(equalToConstant: 42),

            // 上下句导航：紧靠主按钮左边
            navStack.trailingAnchor.constraint(equalTo: primaryBtn.leadingAnchor, constant: -12),
            navStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    // MARK: - 按 stage 更新外观

    func update(stage: AppStage, hasRhythm: Bool) {
        switch stage {
        case .ready:
            if hasRhythm {
                primaryBtn.configure(title: L(.btnPlayRhythm), symbol: "play.fill", style: .amber)
            } else {
                primaryBtn.configure(title: L(.btnStartRecording), symbol: "record.circle.fill", style: .red)
            }
            navStack.isHidden = !hasRhythm
            prevBtn.isEnabled = hasRhythm
            nextBtn.isEnabled = hasRhythm

        case .recording:
            primaryBtn.configure(title: L(.btnStopRecording), symbol: "stop.fill", style: .red)
            navStack.isHidden = true

        case .aligning(let p):
            let pct = Int(p * 100)
            let title = L10n.shared.t(.btnAligning, pct)
            primaryBtn.configure(title: title, symbol: "waveform", style: .processing)
            primaryBtn.isEnabled = false
            navStack.isHidden = true
            return

        case .playing:
            primaryBtn.configure(title: L(.btnPause), symbol: "pause.fill", style: .amber)
            navStack.isHidden = false
            prevBtn.isEnabled = true
            nextBtn.isEnabled = true

        case .error:
            primaryBtn.configure(title: L(.btnStartRecording), symbol: "record.circle.fill", style: .red)
            navStack.isHidden = true
        }
        primaryBtn.isEnabled = true
    }

    /// 语言切换后刷新 tooltip + 当前按钮文字
    func refreshLocalization(stage: AppStage, hasRhythm: Bool) {
        prevBtn.toolTip = L(.tooltipPrevLine)
        nextBtn.toolTip = L(.tooltipNextLine)
        update(stage: stage, hasRhythm: hasRhythm)
    }

    // MARK: - Actions

    @objc private func primaryTapped() { onPrimary() }
    @objc private func prevTapped()    { onPrev() }
    @objc private func nextTapped()    { onNext() }
}

// MARK: - 主按钮（圆角矩形 + 图标 + 文字）

final class PrimaryButton: NSButton {

    enum Style {
        case red          // 录音 / 停止
        case amber        // 播放 / 暂停
        case processing   // 对齐中
    }

    private var currentStyle: Style = .red

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 21
        layer?.masksToBounds = false
        bezelStyle = .regularSquare        // 不显示原生 bezel，由我们自己画
        imagePosition = .imageLeft
        imageScaling = .scaleProportionallyDown
        contentTintColor = .white
        translatesAutoresizingMaskIntoConstraints = false
        // 关键：让 image 和 title 作为一组居中显示，而不是 image 贴左
        if #available(macOS 12.0, *) {
            self.imageHugsTitle = true
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, symbol: String, style: Style) {
        // 用 attributedTitle 确保文字始终白色 + 居中
        // 注意首字符前加 1 个全角空格，给 image 跟文字之间留视觉间距
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para
        ]
        self.attributedTitle = NSAttributedString(string: "   " + title + "   ", attributes: attrs)

        // SF Symbol 放大到 19pt —— 圆形符号视觉感受比方块字小，需要更大
        if #available(macOS 11.0, *) {
            self.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 19, weight: .semibold))
        }

        invalidateIntrinsicContentSize()

        self.currentStyle = style
        updateAppearance()
    }

    override var intrinsicContentSize: NSSize {
        var s = super.intrinsicContentSize
        s.width = max(168, s.width + 32)
        s.height = 42
        return s
    }

    private func updateAppearance() {
        let bg: NSColor
        switch currentStyle {
        case .red:        bg = NSColor(red: 0.95, green: 0.27, blue: 0.22, alpha: 1)
        case .amber:      bg = NSColor(red: 0.95, green: 0.55, blue: 0.18, alpha: 1)
        case .processing: bg = NSColor(red: 0.5,  green: 0.5,  blue: 0.5, alpha: 1)
        }
        layer?.backgroundColor = bg.cgColor
        // 微阴影
        layer?.shadowColor = bg.cgColor
        layer?.shadowOpacity = 0.4
        layer?.shadowRadius = 6
        layer?.shadowOffset = CGSize(width: 0, height: 2)
    }

    // hover 高亮
    private var trackingArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds,
                              options: [.mouseEnteredAndExited, .activeAlways],
                              owner: self, userInfo: nil)
        addTrackingArea(t)
        trackingArea = t
    }
    override func mouseEntered(with event: NSEvent) {
        animator().alphaValue = 0.85
    }
    override func mouseExited(with event: NSEvent) {
        animator().alphaValue = 1.0
    }
}

// MARK: - 小圆按钮（图标）

final class MiniButton: NSButton {

    init(systemSymbol: String, tooltip: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 15
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        bezelStyle = .accessoryBarAction
        imagePosition = .imageOnly
        contentTintColor = NSColor.white.withAlphaComponent(0.85)
        toolTip = tooltip

        if #available(macOS 11.0, *) {
            self.image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        }

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 30),
            heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isEnabled: Bool {
        didSet { alphaValue = isEnabled ? 1.0 : 0.3 }
    }

    private var trackingArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds,
                              options: [.mouseEnteredAndExited, .activeAlways],
                              owner: self, userInfo: nil)
        addTrackingArea(t)
        trackingArea = t
    }
    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
    }
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
    }
}

// MARK: - 工具栏小按钮（右上角）

/// 比 MiniButton 更小、无背景圆 —— 像 macOS 工具栏图标按钮：
/// 静默状态只露 SF Symbol，悬停才出微弱的 hover 圆。
final class ToolbarMiniButton: NSButton {

    init(systemSymbol: String, tooltip: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.clear.cgColor
        bezelStyle = .accessoryBarAction
        imagePosition = .imageOnly
        contentTintColor = NSColor.white.withAlphaComponent(0.55)
        toolTip = tooltip

        if #available(macOS 11.0, *) {
            self.image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        }

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 26),
            heightAnchor.constraint(equalToConstant: 26)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    private var trackingArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds,
                              options: [.mouseEnteredAndExited, .activeAlways],
                              owner: self, userInfo: nil)
        addTrackingArea(t)
        trackingArea = t
    }
    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        contentTintColor = NSColor.white.withAlphaComponent(0.9)
    }
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
        contentTintColor = NSColor.white.withAlphaComponent(0.55)
    }
}
