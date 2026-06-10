//
//  ScriptEditorWindow.swift
//  MyPace Preview
//
//  稿件编辑器 —— 独立窗口，替代 NSAlert 弹窗方案
//  标题 + 正文编辑 + 稿件列表侧栏 + 节奏状态
//

import Cocoa

@MainActor
final class ScriptEditorWindow: NSWindow {

    static var current: ScriptEditorWindow?
    private var onSave: ((Script) -> Void)?

    static func present(script: Script, onSave: @escaping (Script) -> Void) {
        if let win = current {
            win.onSave = onSave
            win.makeKeyAndOrderFront(nil)
            return
        }

        let win = ScriptEditorWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = L(.editorWindowTitle)
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.center()
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 520, height: 400)
        win.onSave = onSave

        let content = ScriptEditorContent(script: script) { updated in
            onSave(updated)
        }
        win.contentView = content

        ScriptEditorWindow.current = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Editor Content

final class ScriptEditorContent: NSView {

    private var script: Script
    private let onSave: (Script) -> Void

    // Title
    private let titleField = NSTextField()

    // Editor
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    // Stats
    private let statsLabel = NSTextField(labelWithString: "")
    private let rhythmBadge = NSTextField(labelWithString: "")

    // Buttons
    private let saveBtn = NSButton(title: "", target: nil, action: nil)
    private let cancelBtn = NSButton(title: "", target: nil, action: nil)

    // Script list sidebar
    private let scriptList = NSTableView()
    private let listScrollView = NSScrollView()
    private var scripts: [Script] = []

    init(script: Script, onSave: @escaping (Script) -> Void) {
        self.script = script
        self.onSave = onSave
        super.init(frame: NSRect(x: 0, y: 0, width: 680, height: 520))
        self.scripts = ScriptStore.shared.scripts
        setupUI()
        loadScript(script)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 1.0).cgColor

        // -- Sidebar (script list) --
        listScrollView.translatesAutoresizingMaskIntoConstraints = false
        listScrollView.hasVerticalScroller = true
        listScrollView.wantsLayer = true
        listScrollView.drawsBackground = false
        listScrollView.layer?.backgroundColor = NSColor(white: 0.06, alpha: 1.0).cgColor
        if let clipView = listScrollView.contentView as? NSClipView {
            clipView.drawsBackground = false
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        column.width = 160
        scriptList.addTableColumn(column)
        scriptList.headerView = nil
        scriptList.style = .plain
        scriptList.backgroundColor = .clear
        scriptList.rowHeight = 36
        scriptList.delegate = self
        scriptList.dataSource = self
        scriptList.action = #selector(scriptListClicked)
        scriptList.target = self

        listScrollView.documentView = scriptList
        scriptList.frame = listScrollView.bounds
        scriptList.autoresizingMask = [.width, .height]
        addSubview(listScrollView)

        // Sidebar header
        let sidebarHeader = NSTextField(labelWithString: L(.editorAllScripts))
        sidebarHeader.font = .systemFont(ofSize: 11, weight: .semibold)
        sidebarHeader.textColor = NSColor(white: 1, alpha: 0.45)
        sidebarHeader.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebarHeader)

        // Add button in sidebar
        let addBtn = NSButton(title: "+", target: self, action: #selector(newScriptClicked))
        addBtn.isBordered = false
        addBtn.font = .systemFont(ofSize: 16, weight: .medium)
        addBtn.contentTintColor = NSColor(white: 1, alpha: 0.5)
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addBtn)

        // -- Right panel --
        let rightPanel = NSView()
        rightPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightPanel)

        // Title field
        titleField.font = .systemFont(ofSize: 18, weight: .semibold)
        titleField.textColor = .white
        titleField.backgroundColor = NSColor(white: 0.12, alpha: 1)
        titleField.isBordered = true
        titleField.drawsBackground = true
        titleField.focusRingType = .none
        titleField.placeholderString = L(.editorTitlePlaceholder)
        titleField.cell?.sendsActionOnEndEditing = false
        let titleCell = titleField.cell as? NSTextFieldCell
        titleCell?.backgroundColor = NSColor(white: 0.12, alpha: 1)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(titleField)

        // Text editor
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.font = .systemFont(ofSize: 14, weight: .regular)
        textView.textColor = NSColor(white: 1, alpha: 0.9)
        textView.backgroundColor = NSColor(white: 0.12, alpha: 1)
        textView.drawsBackground = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.insertionPointColor = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1)
        textView.delegate = self

        scrollView.documentView = textView
        textView.autoresizingMask = [.width, .height]
        rightPanel.addSubview(scrollView)

        // Stats bar
        statsLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statsLabel.textColor = NSColor(white: 1, alpha: 0.35)
        statsLabel.backgroundColor = .clear
        statsLabel.isBordered = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(statsLabel)

        rhythmBadge.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        rhythmBadge.textColor = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1)
        rhythmBadge.backgroundColor = .clear
        rhythmBadge.isBordered = false
        rhythmBadge.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(rhythmBadge)

        // Buttons
        saveBtn.title = L(.dialogSave)
        saveBtn.bezelStyle = .rounded
        saveBtn.controlSize = .regular
        saveBtn.keyEquivalent = "\r"
        saveBtn.target = self
        saveBtn.action = #selector(saveClicked)
        saveBtn.wantsLayer = true
        saveBtn.layer?.cornerRadius = 6
        saveBtn.layer?.backgroundColor = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1).cgColor
        saveBtn.contentTintColor = .white
        saveBtn.font = .systemFont(ofSize: 13, weight: .semibold)
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(saveBtn)

        cancelBtn.title = L(.dialogCancel)
        cancelBtn.bezelStyle = .rounded
        cancelBtn.controlSize = .regular
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.target = self
        cancelBtn.action = #selector(cancelClicked)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(cancelBtn)

        // Delete button
        let deleteBtn = NSButton(title: L(.dialogDelete), target: self, action: #selector(deleteClicked))
        deleteBtn.bezelStyle = .rounded
        deleteBtn.controlSize = .small
        deleteBtn.contentTintColor = NSColor.systemRed
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(deleteBtn)

        NSLayoutConstraint.activate([
            // Sidebar
            listScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            listScrollView.topAnchor.constraint(equalTo: topAnchor),
            listScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            listScrollView.widthAnchor.constraint(equalToConstant: 180),

            sidebarHeader.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            sidebarHeader.leadingAnchor.constraint(equalTo: listScrollView.leadingAnchor, constant: 14),

            addBtn.centerYAnchor.constraint(equalTo: sidebarHeader.centerYAnchor),
            addBtn.trailingAnchor.constraint(equalTo: listScrollView.trailingAnchor, constant: -10),

            // Right panel
            rightPanel.leadingAnchor.constraint(equalTo: listScrollView.trailingAnchor),
            rightPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightPanel.topAnchor.constraint(equalTo: topAnchor),
            rightPanel.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Title
            titleField.topAnchor.constraint(equalTo: rightPanel.topAnchor, constant: 18),
            titleField.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor, constant: 18),
            titleField.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor, constant: -18),
            titleField.heightAnchor.constraint(equalToConstant: 36),

            // Editor
            scrollView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor, constant: 18),
            scrollView.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor, constant: -18),
            scrollView.bottomAnchor.constraint(equalTo: statsLabel.topAnchor, constant: -8),

            // Stats
            statsLabel.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor, constant: 18),
            statsLabel.bottomAnchor.constraint(equalTo: rightPanel.bottomAnchor, constant: -52),

            rhythmBadge.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor, constant: -18),
            rhythmBadge.centerYAnchor.constraint(equalTo: statsLabel.centerYAnchor),

            // Buttons
            saveBtn.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor, constant: -18),
            saveBtn.bottomAnchor.constraint(equalTo: rightPanel.bottomAnchor, constant: -14),
            saveBtn.widthAnchor.constraint(equalToConstant: 80),
            saveBtn.heightAnchor.constraint(equalToConstant: 30),

            cancelBtn.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -8),
            cancelBtn.centerYAnchor.constraint(equalTo: saveBtn.centerYAnchor),
            cancelBtn.widthAnchor.constraint(equalToConstant: 70),
            cancelBtn.heightAnchor.constraint(equalToConstant: 30),

            deleteBtn.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor, constant: 18),
            deleteBtn.centerYAnchor.constraint(equalTo: saveBtn.centerYAnchor),
        ])
    }

    private func loadScript(_ s: Script) {
        titleField.stringValue = s.title
        textView.string = s.lines.joined(separator: "\n")
        updateStats()
        updateRhythmBadge(s)
        scrollToCursor()
    }

    private func updateStats() {
        let text = textView.string
        let lines = text.split(separator: "\n").filter { !$0.isEmpty }.count
        let chars = text.count
        let estimatedSeconds = Double(chars) / 4.0
        let mins = Int(estimatedSeconds) / 60
        let secs = Int(estimatedSeconds) % 60
        statsLabel.stringValue = "\(lines) \(L(.editorLines)) · \(chars) \(L(.editorChars)) · ~\(mins):\(String(format: "%02d", secs))"
    }

    private func updateRhythmBadge(_ s: Script) {
        if s.hasRhythm {
            rhythmBadge.stringValue = "● \(L(.editorHasRhythm))"
            rhythmBadge.textColor = NSColor(red: 0.3, green: 0.85, blue: 0.5, alpha: 1)
        } else {
            rhythmBadge.stringValue = L(.editorNoRhythm)
            rhythmBadge.textColor = NSColor(white: 1, alpha: 0.3)
        }
    }

    private func scrollToCursor() {
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    // MARK: - Actions

    @objc private func saveClicked() {
        let lines = textView.string.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        var s = script
        s.title = titleField.stringValue.isEmpty ? L(.untitledScript) : titleField.stringValue
        if s.lines != lines { s.rhythm = nil }
        s.lines = lines
        onSave(s)
        ScriptEditorWindow.current?.orderOut(nil)
        ScriptEditorWindow.current = nil
    }

    @objc private func cancelClicked() {
        ScriptEditorWindow.current?.orderOut(nil)
        ScriptEditorWindow.current = nil
    }

    @objc private func deleteClicked() {
        let alert = NSAlert()
        alert.messageText = L(.editorDeleteConfirm)
        alert.informativeText = String(format: L(.deleteScriptInfo), script.title)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L(.dialogDelete))
        alert.addButton(withTitle: L(.dialogCancel))
        if alert.runModal() == .alertFirstButtonReturn {
            ScriptStore.shared.delete(script)
            scripts = ScriptStore.shared.scripts
            scriptList.reloadData()
            if let first = scripts.first {
                loadScript(first)
            }
        }
    }

    @objc private func newScriptClicked() {
        let s = Script(title: "\(L(.untitledScript)) \(Date().formatted(.dateTime.month().day()))")
        ScriptStore.shared.save(s)
        scripts = ScriptStore.shared.scripts
        scriptList.reloadData()
        // Select the new script
        scriptList.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        script = s
        loadScript(s)
    }

    @objc private func scriptListClicked() {
        let row = scriptList.clickedRow
        guard scripts.indices.contains(row) else { return }
        guard scripts[row].id != script.id else { return }
        // Save current first
        let lines = textView.string.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        var current = script
        current.title = titleField.stringValue
        current.lines = lines
        ScriptStore.shared.save(current)
        // Switch
        script = scripts[row]
        loadScript(script)
        scriptList.reloadData()
    }
}

// MARK: - NSTableView DataSource / Delegate

extension ScriptEditorContent: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        scripts.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard scripts.indices.contains(row) else { return nil }

        let cellId = NSUserInterfaceItemIdentifier("ScriptCell")
        let cell = tableView.makeView(withIdentifier: cellId, owner: nil) as? ScriptListCell
            ?? ScriptListCell(identifier: cellId)

        let s = scripts[row]
        let selected = tableView.selectedRow == row || scripts[row].id == script.id
        cell.configure(title: s.title, hasRhythm: s.hasRhythm, isSelected: selected)
        return cell
    }

    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        rowView.backgroundColor = .clear
        rowView.selectionHighlightStyle = .none
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        36
    }

    func tableView(_ tableView: NSTableView, isSelected row: Int) -> Bool {
        scripts[row].id == script.id
    }
}

// MARK: - Script List Cell

final class ScriptListCell: NSTableCellView {

    private let titleLabel = NSTextField(labelWithString: "")
    private let rhythmDot = NSView()

    private let bgLayer = NSView()

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: NSRect.zero)
        self.identifier = identifier

        wantsLayer = true
        layer?.cornerRadius = 6

        bgLayer.wantsLayer = true
        bgLayer.layer?.cornerRadius = 6
        bgLayer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bgLayer)

        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = NSColor(white: 1, alpha: 0.85)
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        rhythmDot.wantsLayer = true
        rhythmDot.layer?.cornerRadius = 3
        rhythmDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rhythmDot)

        NSLayoutConstraint.activate([
            bgLayer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            bgLayer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            bgLayer.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            bgLayer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: rhythmDot.leadingAnchor, constant: -6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            rhythmDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rhythmDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            rhythmDot.widthAnchor.constraint(equalToConstant: 6),
            rhythmDot.heightAnchor.constraint(equalToConstant: 6),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, hasRhythm: Bool, isSelected: Bool = false) {
        titleLabel.stringValue = title
        rhythmDot.layer?.backgroundColor = hasRhythm
            ? NSColor(red: 0.3, green: 0.85, blue: 0.5, alpha: 1).cgColor
            : NSColor(white: 1, alpha: 0.15).cgColor
        bgLayer.layer?.backgroundColor = isSelected
            ? NSColor(white: 1, alpha: 0.08).cgColor
            : .clear
        titleLabel.textColor = isSelected
            ? NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1)
            : NSColor(white: 1, alpha: 0.85)
    }
}

// MARK: - NSTextViewDelegate

extension ScriptEditorContent: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        updateStats()
    }
}
