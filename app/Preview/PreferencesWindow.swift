//
//  PreferencesWindow.swift
//  MyPace Preview
//
//  偏好设置面板 —— 分区：视觉 / 语音识别 / 数据管理
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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = L(.prefsTitle)
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.center()
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 440, height: 460)
        win.onChange = onChange

        let content = PreferencesContent { onChange() }
        win.contentView = content

        PreferencesWindow.current = win
        win.makeKeyAndOrderFront(nil)
    }
}

final class PreferencesContent: NSView {

    private let onChange: () -> Void

    // -- Visual --
    private let languagePopup = NSPopUpButton()
    private let fontSlider = NSSlider()
    private let opacitySlider = NSSlider()
    private let colorPopup = NSPopUpButton()
    private let screenCaptureSwitch = NSSwitch()

    // -- ASR --
    private let asrSourceLabel = NSTextField(labelWithString: "")
    private let asrAppIdField = NSTextField()
    private let asrTokenField = NSSecureTextField()
    private let asrStatusIcon = NSTextField(labelWithString: "")

    // -- Data --
    private let dataPathLabel = NSTextField(labelWithString: "")
    private let scriptCountLabel = NSTextField(labelWithString: "")

    private let fontValueLabel = NSTextField(labelWithString: "")
    private let opacityValueLabel = NSTextField(labelWithString: "")

    // -- Tab buttons --
    private var tabButtons: [NSButton] = []
    private var tabViews: [NSView] = []
    private var currentTab = 0

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 480, height: 520))
        setupUI()
        loadValues()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 1.0).cgColor

        // Tab bar
        let tabBar = NSView()
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.wantsLayer = true
        tabBar.layer?.backgroundColor = NSColor(white: 0.06, alpha: 1.0).cgColor
        addSubview(tabBar)

        let tabTitles = [L(.prefsTabVisual), L(.prefsTabASR), L(.prefsTabData)]
        for (i, title) in tabTitles.enumerated() {
            let btn = NSButton(title: title, target: self, action: #selector(tabClicked(_:)))
            btn.isBordered = false
            btn.font = .systemFont(ofSize: 13, weight: i == 0 ? .semibold : .regular)
            btn.contentTintColor = i == 0 ? NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1) : NSColor(white: 1, alpha: 0.5)
            btn.tag = i
            btn.translatesAutoresizingMaskIntoConstraints = false
            tabBar.addSubview(btn)
            tabButtons.append(btn)
        }

        // Tab content container
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        // Build tab content views
        let visualTab = buildVisualTab()
        let asrTab = buildASRTab()
        let dataTab = buildDataTab()
        tabViews = [visualTab, asrTab, dataTab]

        for (i, tab) in tabViews.enumerated() {
            container.addSubview(tab)
            tab.translatesAutoresizingMaskIntoConstraints = false
            tab.isHidden = (i != 0)
            NSLayoutConstraint.activate([
                tab.topAnchor.constraint(equalTo: container.topAnchor),
                tab.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                tab.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                tab.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
            ])
        }

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 44),

            tabButtons[0].leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: 20),
            tabButtons[0].centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            tabButtons[1].leadingAnchor.constraint(equalTo: tabButtons[0].trailingAnchor, constant: 24),
            tabButtons[1].centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            tabButtons[2].leadingAnchor.constraint(equalTo: tabButtons[1].trailingAnchor, constant: 24),
            tabButtons[2].centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),

            container.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Tab switching

    @objc private func tabClicked(_ sender: NSButton) {
        currentTab = sender.tag
        for (i, btn) in tabButtons.enumerated() {
            btn.font = .systemFont(ofSize: 13, weight: i == currentTab ? .semibold : .regular)
            btn.contentTintColor = i == currentTab
                ? NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1)
                : NSColor(white: 1, alpha: 0.5)
            tabViews[i].isHidden = (i != currentTab)
        }
    }

    // MARK: - Visual Tab

    private func buildVisualTab() -> NSView {
        let tab = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        tab.addSubview(stack)

        // Language
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        languagePopup.translatesAutoresizingMaskIntoConstraints = false
        for lang in Language.allCases {
            let title = (lang == .auto) ? L(.prefsLanguageAuto) : lang.displayName
            languagePopup.addItem(withTitle: title)
        }
        stack.addArrangedSubview(makeRow(title: L(.prefsLanguage), control: languagePopup))

        // Font size
        let fontRow = makeSliderRow(
            title: L(.prefsFontSize), slider: fontSlider, valueLabel: fontValueLabel,
            min: 18, max: 56, action: #selector(fontChanged)
        )
        stack.addArrangedSubview(fontRow)

        // Opacity
        let opacityRow = makeSliderRow(
            title: L(.prefsOpacity), slider: opacitySlider, valueLabel: opacityValueLabel,
            min: 50, max: 100, action: #selector(opacityChanged)
        )
        stack.addArrangedSubview(opacityRow)

        // Accent color
        colorPopup.target = self
        colorPopup.action = #selector(colorChanged)
        colorPopup.translatesAutoresizingMaskIntoConstraints = false
        for c in AccentColor.allCases {
            let title: String = switch c {
            case .violet: L(.prefsAccentAmber)
            case .cyan:   L(.prefsAccentBlue)
            case .rose:   L(.prefsAccentGreen)
            }
            colorPopup.addItem(withTitle: title)
        }
        stack.addArrangedSubview(makeRow(title: L(.prefsAccentColor), control: colorPopup))

        // Screen capture
        stack.addArrangedSubview(makeSwitchRow(
            title: L(.prefsAllowCapture),
            subtitle: L(.prefsAllowCaptureHint),
            sw: screenCaptureSwitch, action: #selector(screenCaptureChanged)
        ))

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tab.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: tab.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: tab.trailingAnchor, constant: -24),
        ])
        return tab
    }

    // MARK: - ASR Tab

    private func buildASRTab() -> NSView {
        let tab = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        tab.addSubview(stack)

        // Section header
        let header = NSTextField(labelWithString: L(.prefsAsrSectionTitle))
        header.font = .systemFont(ofSize: 13, weight: .semibold)
        header.textColor = NSColor(white: 1, alpha: 0.85)
        stack.addArrangedSubview(header)

        // Current source
        asrSourceLabel.font = .systemFont(ofSize: 12, weight: .regular)
        asrSourceLabel.textColor = NSColor(white: 1, alpha: 0.5)
        stack.addArrangedSubview(asrSourceLabel)

        // Status
        asrStatusIcon.font = .systemFont(ofSize: 12, weight: .medium)
        stack.addArrangedSubview(asrStatusIcon)

        // Separator
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sep)
        NSLayoutConstraint.activate([
            sep.widthAnchor.constraint(equalToConstant: 400),
            sep.heightAnchor.constraint(equalToConstant: 1),
        ])

        // Custom credentials header
        let customHeader = NSTextField(labelWithString: L(.prefsAsrCustomTitle))
        customHeader.font = .systemFont(ofSize: 12, weight: .semibold)
        customHeader.textColor = NSColor(white: 1, alpha: 0.65)
        stack.addArrangedSubview(customHeader)

        let customHint = NSTextField(wrappingLabelWithString: L(.prefsAsrCustomHint))
        customHint.font = .systemFont(ofSize: 11, weight: .regular)
        customHint.textColor = NSColor(white: 1, alpha: 0.35)
        customHint.maximumNumberOfLines = 3
        customHint.preferredMaxLayoutWidth = 380
        stack.addArrangedSubview(customHint)

        // App ID
        let appIdRow = makeFieldRow(title: "App ID", field: asrAppIdField, placeholder: "volc_engine_app_id")
        asrAppIdField.target = self
        asrAppIdField.action = #selector(asrFieldChanged)
        stack.addArrangedSubview(appIdRow)

        // Access Token
        let tokenRow = makeFieldRow(title: "Access Token", field: asrTokenField, placeholder: "volc_engine_access_token")
        asrTokenField.target = self
        asrTokenField.action = #selector(asrFieldChanged)
        stack.addArrangedSubview(tokenRow)

        // Save ASR button
        let saveAsrBtn = NSButton(title: L(.prefsAsrSave), target: self, action: #selector(saveASRClicked))
        saveAsrBtn.bezelStyle = .rounded
        saveAsrBtn.controlSize = .small
        stack.addArrangedSubview(saveAsrBtn)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tab.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: tab.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: tab.trailingAnchor, constant: -24),
        ])
        return tab
    }

    // MARK: - Data Tab

    private func buildDataTab() -> NSView {
        let tab = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        tab.addSubview(stack)

        // Data path
        let pathHeader = NSTextField(labelWithString: L(.prefsDataPath))
        pathHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        pathHeader.textColor = NSColor(white: 1, alpha: 0.85)
        stack.addArrangedSubview(pathHeader)

        dataPathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        dataPathLabel.textColor = NSColor(white: 1, alpha: 0.45)
        dataPathLabel.maximumNumberOfLines = 2
        dataPathLabel.lineBreakMode = .byTruncatingMiddle
        dataPathLabel.preferredMaxLayoutWidth = 380
        stack.addArrangedSubview(dataPathLabel)

        let openFolderBtn = NSButton(title: L(.prefsOpenDataFolder), target: self, action: #selector(openDataFolder))
        openFolderBtn.bezelStyle = .rounded
        openFolderBtn.controlSize = .small
        stack.addArrangedSubview(openFolderBtn)

        // Separator
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sep)
        NSLayoutConstraint.activate([
            sep.widthAnchor.constraint(equalToConstant: 400),
            sep.heightAnchor.constraint(equalToConstant: 1),
        ])

        // Script stats
        let statsHeader = NSTextField(labelWithString: L(.prefsScriptStats))
        statsHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        statsHeader.textColor = NSColor(white: 1, alpha: 0.85)
        stack.addArrangedSubview(statsHeader)

        scriptCountLabel.font = .systemFont(ofSize: 12, weight: .regular)
        scriptCountLabel.textColor = NSColor(white: 1, alpha: 0.5)
        stack.addArrangedSubview(scriptCountLabel)

        // Recordings folder
        let recHeader = NSTextField(labelWithString: L(.prefsRecordings))
        recHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        recHeader.textColor = NSColor(white: 1, alpha: 0.85)
        stack.addArrangedSubview(recHeader)

        let openRecBtn = NSButton(title: L(.prefsOpenRecordings), target: self, action: #selector(openRecordingsFolder))
        openRecBtn.bezelStyle = .rounded
        openRecBtn.controlSize = .small
        stack.addArrangedSubview(openRecBtn)

        // Separator
        let sep2 = NSView()
        sep2.wantsLayer = true
        sep2.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        sep2.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sep2)
        NSLayoutConstraint.activate([
            sep2.widthAnchor.constraint(equalToConstant: 400),
            sep2.heightAnchor.constraint(equalToConstant: 1),
        ])

        // Log
        let logBtn = NSButton(title: L(.prefsOpenLog), target: self, action: #selector(openLogClicked))
        logBtn.bezelStyle = .rounded
        logBtn.controlSize = .small
        stack.addArrangedSubview(logBtn)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tab.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: tab.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: tab.trailingAnchor, constant: -24),
        ])
        return tab
    }

    // MARK: - Row helpers

    private func makeRow(title: String, control: NSControl) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor(white: 1, alpha: 0.85)
        let row = NSStackView(views: [label])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(control)
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 120),
            row.widthAnchor.constraint(equalToConstant: 400)
        ])
        return row
    }

    private func makeSliderRow(title: String, slider: NSSlider, valueLabel: NSTextField,
                               min: Double, max: Double, action: Selector) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor(white: 1, alpha: 0.85)
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
            row.widthAnchor.constraint(equalToConstant: 400)
        ])
        return row
    }

    private func makeSwitchRow(title: String, subtitle: String, sw: NSSwitch, action: Selector) -> NSView {
        let titleLbl = NSTextField(labelWithString: title)
        titleLbl.font = .systemFont(ofSize: 13, weight: .medium)
        titleLbl.textColor = NSColor(white: 1, alpha: 0.85)
        let subLbl = NSTextField(labelWithString: subtitle)
        subLbl.font = .systemFont(ofSize: 11)
        subLbl.textColor = NSColor(white: 1, alpha: 0.35)
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
            row.widthAnchor.constraint(equalToConstant: 400)
        ])
        return row
    }

    private func makeFieldRow(title: String, field: NSTextField, placeholder: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = NSColor(white: 1, alpha: 0.65)

        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.textColor = NSColor(white: 1, alpha: 0.9)
        field.backgroundColor = NSColor(white: 0.14, alpha: 1)
        field.drawsBackground = true
        field.isBordered = true
        field.focusRingType = .none
        field.placeholderString = placeholder
        field.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.addArrangedSubview(label)
        row.addArrangedSubview(field)
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 120),
            field.widthAnchor.constraint(equalToConstant: 280),
            row.widthAnchor.constraint(equalToConstant: 400),
        ])
        return row
    }

    // MARK: - Load / Save

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

        // ASR
        updateASRDisplay()
        if let custom = ASRCredentials.fromUserDefaults() {
            asrAppIdField.stringValue = custom.appID
            asrTokenField.stringValue = custom.accessToken
        }

        // Data
        dataPathLabel.stringValue = ScriptStore.dataDirectoryPath
        let scripts = ScriptStore.shared.scripts
        let withRhythm = scripts.filter { $0.hasRhythm }.count
        scriptCountLabel.stringValue = "\(scripts.count) \(L(.prefsScriptsTotal)) · \(withRhythm) \(L(.prefsScriptsRhythm))"
    }

    private func updateASRDisplay() {
        let cred = ASRCredentials.auto()
        let source = ASRCredentials.fromUserDefaults() != nil ? L(.prefsAsrSourceCustom) :
                     (ASRCredentials.fromShandianshuo() != nil ? L(.prefsAsrSourceShandian) : L(.prefsAsrSourceBundled))
        asrSourceLabel.stringValue = "\(L(.prefsAsrCurrentSource)): \(source) (app_id: \(cred.appID.prefix(8))…)"

        // Show whether credentials are valid
        if !cred.appID.isEmpty && !cred.accessToken.isEmpty {
            asrStatusIcon.stringValue = "● \(L(.prefsAsrReady))"
            asrStatusIcon.textColor = NSColor(red: 0.3, green: 0.85, blue: 0.5, alpha: 1)
        } else {
            asrStatusIcon.stringValue = "● \(L(.prefsAsrNotConfigured))"
            asrStatusIcon.textColor = NSColor.systemRed
        }
    }

    // MARK: - Visual Actions

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

    // MARK: - ASR Actions

    @objc private func asrFieldChanged() {
        // Real-time feedback while typing
    }

    @objc private func saveASRClicked() {
        let d = UserDefaults.standard
        let appId = asrAppIdField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = asrTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if appId.isEmpty || token.isEmpty {
            d.removeObject(forKey: "asr.custom.appID")
            d.removeObject(forKey: "asr.custom.accessToken")
        } else {
            d.set(appId, forKey: "asr.custom.appID")
            d.set(token, forKey: "asr.custom.accessToken")
        }
        updateASRDisplay()
    }

    // MARK: - Data Actions

    @objc private func openDataFolder() {
        NSWorkspace.shared.open(ScriptStore.dataDirectoryURL)
    }

    @objc private func openRecordingsFolder() {
        NSWorkspace.shared.open(ScriptStore.recordingsDirectoryURL)
    }

    @objc private func openLogClicked() {
        let url = URL(fileURLWithPath: MyPaceLogger.logPath)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? "(MyPace 还没产生日志)".data(using: .utf8)?.write(to: url)
        }
        NSWorkspace.shared.open(url)
    }
}
