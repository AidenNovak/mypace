//
//  PreferencesWindow.swift
//  MyPace Preview
//
//  偏好设置面板 (⌘,) —— 语言 / 字号 / 透明度 / 颜色 / 录屏可见
//

import Cocoa

@MainActor
final class PreferencesWindow: NSWindow {

    static var current: PreferencesWindow?
    private var onChange: () -> Void = {}

    static func present(onChange: @escaping () -> Void) {
        if let win = current {
            win.onChange = onChange
            win.makeKeyAndOrderFront(nil)
            return
        }

        let win = PreferencesWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = L(.prefsTitle)
        win.center()
        win.isReleasedWhenClosed = false
        win.onChange = onChange

        let content = PreferencesContent { onChange() }
        win.contentView = content

        PreferencesWindow.current = win
        win.makeKeyAndOrderFront(nil)
    }
}

final class PreferencesContent: NSView {

    private let onChange: () -> Void
    private let languagePopup = NSPopUpButton()
    private let fontSlider = NSSlider()
    private let opacitySlider = NSSlider()
    private let colorPopup = NSPopUpButton()
    private let screenCaptureSwitch = NSSwitch()

    private let fontValueLabel = NSTextField(labelWithString: "")
    private let opacityValueLabel = NSTextField(labelWithString: "")

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 360))
        setupUI()
        loadValues()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // 语言
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        languagePopup.translatesAutoresizingMaskIntoConstraints = false
        for lang in Language.allCases {
            let title = (lang == .auto) ? L(.prefsLanguageAuto) : lang.displayName
            languagePopup.addItem(withTitle: title)
        }
        stack.addArrangedSubview(makeRow(title: L(.prefsLanguage), control: languagePopup))

        // 字号
        let fontRow = makeSliderRow(
            title: L(.prefsFontSize),
            slider: fontSlider,
            valueLabel: fontValueLabel,
            min: 18, max: 56, action: #selector(fontChanged)
        )
        stack.addArrangedSubview(fontRow)

        // 透明度
        let opacityRow = makeSliderRow(
            title: L(.prefsOpacity),
            slider: opacitySlider,
            valueLabel: opacityValueLabel,
            min: 50, max: 100, action: #selector(opacityChanged)
        )
        stack.addArrangedSubview(opacityRow)

        // 颜色
        colorPopup.target = self
        colorPopup.action = #selector(colorChanged)
        colorPopup.translatesAutoresizingMaskIntoConstraints = false
        for c in AccentColor.allCases {
            let title: String = switch c {
            case .amber: L(.prefsAccentAmber)
            case .cream: L(.prefsAccentBlue)        // cream 复用 blue 翻译位
            case .green: L(.prefsAccentGreen)
            }
            colorPopup.addItem(withTitle: title)
        }
        stack.addArrangedSubview(makeRow(title: L(.prefsAccentColor), control: colorPopup))

        // 允许被录屏
        stack.addArrangedSubview(makeSwitchRow(
            title: L(.prefsAllowCapture),
            subtitle: L(.prefsAllowCaptureHint),
            sw: screenCaptureSwitch, action: #selector(screenCaptureChanged)
        ))

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
        ])
    }

    private func makeRow(title: String, control: NSControl) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        let row = NSStackView(views: [label])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(control)
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 120),
            row.widthAnchor.constraint(equalToConstant: 372)
        ])
        return row
    }

    private func makeSliderRow(title: String, slider: NSSlider, valueLabel: NSTextField,
                               min: Double, max: Double, action: Selector) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        slider.minValue = min
        slider.maxValue = max
        slider.target = self
        slider.action = action
        slider.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.addArrangedSubview(label)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 120),
            valueLabel.widthAnchor.constraint(equalToConstant: 44),
            row.widthAnchor.constraint(equalToConstant: 372)
        ])
        return row
    }

    private func makeSwitchRow(title: String, subtitle: String, sw: NSSwitch, action: Selector) -> NSView {
        let titleLbl = NSTextField(labelWithString: title)
        titleLbl.font = .systemFont(ofSize: 13, weight: .medium)
        let subLbl = NSTextField(labelWithString: subtitle)
        subLbl.font = .systemFont(ofSize: 11)
        subLbl.textColor = .secondaryLabelColor
        subLbl.maximumNumberOfLines = 2
        subLbl.preferredMaxLayoutWidth = 280

        let leftStack = NSStackView(views: [titleLbl, subLbl])
        leftStack.orientation = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 2

        sw.target = self
        sw.action = action
        sw.controlSize = .small

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.addArrangedSubview(leftStack)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(sw)
        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalToConstant: 372)
        ])
        return row
    }

    private func loadValues() {
        let s = UserSettings.shared
        if let idx = Language.allCases.firstIndex(of: s.language) {
            languagePopup.selectItem(at: idx)
        }
        fontSlider.doubleValue = Double(s.currentFontSize)
        opacitySlider.doubleValue = Double(s.opacity * 100)
        fontValueLabel.stringValue = "\(Int(s.currentFontSize)) pt"
        opacityValueLabel.stringValue = "\(Int(s.opacity * 100))%"
        if let idx = AccentColor.allCases.firstIndex(of: s.accentColor) {
            colorPopup.selectItem(at: idx)
        }
        screenCaptureSwitch.state = s.allowScreenCapture ? .on : .off
    }

    @objc private func languageChanged() {
        let idx = languagePopup.indexOfSelectedItem
        if Language.allCases.indices.contains(idx) {
            L10n.shared.language = Language.allCases[idx]
            onChange()
        }
    }

    @objc private func fontChanged() {
        let v = CGFloat(fontSlider.doubleValue)
        UserSettings.shared.currentFontSize = v
        fontValueLabel.stringValue = "\(Int(v)) pt"
        onChange()
    }

    @objc private func opacityChanged() {
        let v = CGFloat(opacitySlider.doubleValue / 100.0)
        UserSettings.shared.opacity = v
        opacityValueLabel.stringValue = "\(Int(v * 100))%"
        onChange()
    }

    @objc private func colorChanged() {
        let idx = colorPopup.indexOfSelectedItem
        if AccentColor.allCases.indices.contains(idx) {
            UserSettings.shared.accentColor = AccentColor.allCases[idx]
            onChange()
        }
    }

    @objc private func screenCaptureChanged() {
        UserSettings.shared.allowScreenCapture = (screenCaptureSwitch.state == .on)
        onChange()
    }
}
