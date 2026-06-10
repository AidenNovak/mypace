//
//  WelcomeWindow.swift
//  MyPace Preview
//
//  首次启动欢迎页 —— 3 步介绍核心价值
//

import Cocoa

@MainActor
final class WelcomeWindow: NSWindow {

    static var current: WelcomeWindow?

    static func present(completion: @escaping () -> Void) {
        if let win = current {
            win.makeKeyAndOrderFront(nil)
            return
        }

        let win = WelcomeWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = L(.welcomeTitle)
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.center()
        win.isReleasedWhenClosed = false

        let content = WelcomeContent { [weak win] in
            UserSettings.shared.hasSeenWelcome = true
            win?.orderOut(nil)
            WelcomeWindow.current = nil
            completion()
        }
        win.contentView = content

        WelcomeWindow.current = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class WelcomeContent: NSView {

    private let onDismiss: () -> Void
    private var currentStep = 0

    private let logoLayer = CALayer()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let primaryBtn = NSButton(title: "", target: nil, action: nil)
    private let skipBtn = NSButton(title: "Skip", target: nil, action: nil)
    private let dotStack = NSStackView()
    private var dots: [CALayer] = []

    // 3 步引导 —— 用 L10nKey 引用本地化字符串
    private struct Step {
        let title: L10nKey
        let subtitle: L10nKey
        let body: L10nKey
        let primary: L10nKey
    }
    private let steps: [Step] = [
        Step(title: .welcomeFeature2Title, subtitle: .welcomeSubtitle, body: .welcomeFeature2Desc, primary: .dialogConfirm),
        Step(title: .welcomeFeature1Title, subtitle: .welcomeSubtitle, body: .welcomeFeature1Desc, primary: .dialogConfirm),
        Step(title: .welcomeFeature3Title, subtitle: .welcomeSubtitle, body: .welcomeFeature3Desc, primary: .welcomeStart),
    ]

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(frame: NSRect(x: 0, y: 0, width: 560, height: 480))
        setupUI()
        renderStep()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.99, alpha: 1.0).cgColor

        // 顶部 logo 区域（渐变橙）
        let topBg = NSView(frame: NSRect(x: 0, y: 280, width: 560, height: 200))
        topBg.wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor(red: 0.30, green: 0.50, blue: 0.95, alpha: 1.0).cgColor,
            NSColor(red: 0.55, green: 0.25, blue: 0.95, alpha: 1.0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.frame = topBg.bounds
        topBg.layer?.insertSublayer(gradient, at: 0)
        topBg.autoresizingMask = [.width]
        addSubview(topBg)

        // Logo M (serif italic)
        let logoLabel = NSTextField(labelWithString: "M")
        logoLabel.font = NSFont(name: "Georgia-BoldItalic", size: 96)
                       ?? NSFont.systemFont(ofSize: 96, weight: .bold)
        logoLabel.textColor = .white
        logoLabel.backgroundColor = .clear
        logoLabel.isBordered = false
        logoLabel.alignment = .center
        logoLabel.frame = NSRect(x: 0, y: 60, width: 560, height: 130)
        logoLabel.autoresizingMask = [.width]
        topBg.addSubview(logoLabel)

        // 引导线
        let line = NSView(frame: NSRect(x: 250, y: 55, width: 60, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.6).cgColor
        topBg.addSubview(line)

        // 主标题
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = NSColor(white: 0.1, alpha: 1)
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // 副标题
        subtitleLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        subtitleLabel.textColor = NSColor(red: 0.95, green: 0.42, blue: 0.06, alpha: 1)
        subtitleLabel.backgroundColor = .clear
        subtitleLabel.isBordered = false
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        // body
        bodyLabel.font = .systemFont(ofSize: 13.5, weight: .regular)
        bodyLabel.textColor = NSColor(white: 0.35, alpha: 1)
        bodyLabel.backgroundColor = .clear
        bodyLabel.isBordered = false
        bodyLabel.alignment = .center
        bodyLabel.maximumNumberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bodyLabel)

        // 主按钮
        primaryBtn.target = self
        primaryBtn.action = #selector(nextStep)
        primaryBtn.bezelStyle = .rounded
        primaryBtn.controlSize = .large
        primaryBtn.keyEquivalent = "\r"
        primaryBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(primaryBtn)

        // 跳过按钮
        skipBtn.target = self
        skipBtn.action = #selector(skip)
        skipBtn.bezelStyle = .accessoryBarAction
        skipBtn.isBordered = false
        skipBtn.contentTintColor = NSColor(white: 0.5, alpha: 1)
        skipBtn.font = .systemFont(ofSize: 11)
        skipBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(skipBtn)

        // 步骤点
        dotStack.orientation = .horizontal
        dotStack.spacing = 6
        dotStack.translatesAutoresizingMaskIntoConstraints = false
        for i in 0..<steps.count {
            let dot = NSView(frame: .zero)
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 3
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 6),
                dot.heightAnchor.constraint(equalToConstant: 6)
            ])
            if let layer = dot.layer { dots.append(layer); _ = layer }
            dotStack.addArrangedSubview(dot)
            _ = i
        }
        addSubview(dotStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 220),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            bodyLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 18),
            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 60),
            bodyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -60),

            primaryBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32),
            primaryBtn.centerXAnchor.constraint(equalTo: centerXAnchor),
            primaryBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            skipBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            skipBtn.centerXAnchor.constraint(equalTo: centerXAnchor),

            dotStack.bottomAnchor.constraint(equalTo: primaryBtn.topAnchor, constant: -22),
            dotStack.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    private func renderStep() {
        let s = steps[currentStep]
        titleLabel.stringValue = L(s.title)
        subtitleLabel.stringValue = L(s.subtitle).uppercased()
        bodyLabel.stringValue = L(s.body)
        primaryBtn.title = L(s.primary)

        // 最后一步隐藏跳过
        skipBtn.isHidden = (currentStep == steps.count - 1)

        // 更新步骤点
        for (i, layer) in dots.enumerated() {
            let active = (i == currentStep)
            layer.backgroundColor = active
                ? NSColor(red: 0.95, green: 0.42, blue: 0.06, alpha: 1).cgColor
                : NSColor(white: 0.85, alpha: 1).cgColor
        }
    }

    @objc private func nextStep() {
        if currentStep < steps.count - 1 {
            currentStep += 1
            renderStep()
        } else {
            onDismiss()
        }
    }

    @objc private func skip() {
        onDismiss()
    }
}
