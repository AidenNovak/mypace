//
//  ScriptEditorView.swift
//  MyPace
//
//  脚本编辑器 —— 对应 tahoe.html 的 #v2 部分。
//  左侧：稿纸 TextEditor。右侧：Inspector 抽屉。底部：CTA bar。
//

import SwiftUI
import SwiftData

struct ScriptEditorView: View {
    @Bindable var script: Script
    @Environment(\.dismiss) private var dismiss
    @State private var showInspector = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // ---- 左侧稿纸 ----
                PaperArea(script: script)
                    .frame(maxWidth: .infinity)

                // ---- 右侧 Inspector ----
                if showInspector {
                    Divider()
                    InspectorPanel(script: script)
                        .frame(width: 280)
                        .background(Color.sidebar)
                }
            }
            // ---- 底部 CTA bar ----
            Divider()
            BottomBar(
                script: script,
                onPracticeRecord: startPracticeRecording,
                onDirectRecord:   startDirectRecording
            )
        }
        .background(Color.surfaceSolid)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(script.title.isEmpty ? "未命名脚本" : script.title)
                    .font(.pmHeading)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showInspector.toggle() } label: {
                    Image(systemName: showInspector ? "sidebar.right" : "sidebar.right")
                }
            }
        }
    }

    private func startPracticeRecording() {
        // TODO（阶段 2）：跳转到 PracticeRecordingView
        // 这里可以 present 一个全屏 sheet
        print("[MVP] startPracticeRecording — 待 RecordingService 实现")
    }

    private func startDirectRecording() {
        // 直接打开浮动提词器
        WindowManager.shared.showFloatingTeleprompter {
            FloatingTeleprompterView(script: script)
        }
    }
}

// MARK: - 稿纸区

struct PaperArea: View {
    @Bindable var script: Script

    var body: some View {
        VStack(spacing: 0) {
            // 顶部格式工具栏
            HStack(spacing: 4) {
                FormatButton("H1")
                FormatButton("H2")
                Divider().frame(height: 18).padding(.horizontal, 4)
                FormatButton("B", bold: true)
                FormatButton("I", italic: true)
                Divider().frame(height: 18).padding(.horizontal, 4)
                FormatButton("—") // 断点
                FormatButton("⏸") // 停顿
                Spacer()
                Text("Markdown · 已开启")
                    .font(.pmMonoSmall)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24).padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .bottom)

            // 主要编辑区
            ScrollView {
                TextEditor(text: $script.content)
                    .font(.pmEditor)
                    .lineSpacing(8)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 56)
                    .padding(.vertical, 48)
                    .frame(maxWidth: .infinity, minHeight: 480, alignment: .topLeading)
                    .onChange(of: script.content) { _, _ in
                        script.updatedAt = .now
                    }
            }
            .background(Color.surfaceSolid)

            // 底部状态
            HStack {
                Text("**\(script.wordCount)** 字 · 预计 **\(estimatedDuration)**")
                    .font(.pmMono)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(Color.appGreen).frame(width: 6, height: 6)
                    Text("已自动保存 · \(formatTime(script.updatedAt))")
                }
                .font(.pmMono)
                .foregroundStyle(Color.appGreen)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .top)
        }
    }

    private var estimatedDuration: String {
        if let d = script.estimatedDuration {
            let m = Int(d) / 60
            let s = Int(d) % 60
            return String(format: "%d 分 %02d 秒（基于上次节奏）", m, s)
        } else {
            // 粗略：3 字/秒
            let secs = script.wordCount / 3
            let m = secs / 60
            let s = secs % 60
            return String(format: "~%d 分 %02d 秒（估算）", m, s)
        }
    }

    private func formatTime(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: d)
    }
}

struct FormatButton: View {
    let title: String
    var bold: Bool = false
    var italic: Bool = false

    init(_ title: String, bold: Bool = false, italic: Bool = false) {
        self.title = title
        self.bold = bold
        self.italic = italic
    }

    var body: some View {
        Button(action: {}) {
            Text(title)
                .font(.system(size: 13, weight: bold ? .bold : .semibold, design: .default))
                .italic(italic)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .background(Color.black.opacity(0.001))    // 让 hover 区域生效
        .onHover { hovering in
            // 苹果原生 hover 效果（实际项目可加 background animation）
        }
    }
}

// MARK: - Inspector 抽屉

struct InspectorPanel: View {
    @Bindable var script: Script

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // 外观
                InsetGroup(title: "外观") {
                    InsetRow("字号") {
                        Slider(value: $script.fontSize, in: 18...72)
                            .frame(width: 100)
                        Text("\(Int(script.fontSize))")
                            .font(.pmMono).foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                    InsetRow("透明度") {
                        Slider(value: $script.opacity, in: 0.4...1.0)
                            .frame(width: 100)
                        Text("\(Int(script.opacity * 100))%")
                            .font(.pmMono).foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                }

                // 滚动模式
                InsetGroup(title: "滚动模式") {
                    Picker("", selection: scrollModeBinding) {
                        Text("节奏同步").tag(ScrollMode.rhythm)
                        Text("手动").tag(ScrollMode.manual)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                // 辅助
                InsetGroup(title: "辅助") {
                    InsetToggleRow("阅读引导线",
                                   desc: "当前句下方一条横线",
                                   isOn: $script.showGuideLine)
                    InsetToggleRow("下一句预览",
                                   desc: "提前显示下一行",
                                   isOn: $script.showNextLine)
                    InsetToggleRow("段落停顿",
                                   desc: "断点处 600ms 缓冲",
                                   isOn: $script.paragraphPause)
                    InsetToggleRow("窗口对相机隐形",
                                   desc: "ScreenCaptureKit 排除",
                                   isOn: $script.excludeFromCapture)
                }
            }
            .padding(16)
        }
    }

    private var scrollModeBinding: Binding<ScrollMode> {
        Binding(
            get: { ScrollMode(rawValue: script.scrollModeRaw) ?? .manual },
            set: { script.scrollModeRaw = $0.rawValue }
        )
    }
}

struct InsetGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 6)
            VStack(spacing: 0) { content }
        }
        .padding(.bottom, 6)
        .background(Color.surfaceSolid)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Color.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

struct InsetRow<Right: View>: View {
    let title: String
    @ViewBuilder var right: Right

    init(_ title: String, @ViewBuilder right: () -> Right) {
        self.title = title
        self.right = right()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.pmBody)
            Spacer()
            right
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .overlay(Divider(), alignment: .top)
    }
}

struct InsetToggleRow: View {
    let title: String
    let desc: String
    @Binding var isOn: Bool

    init(_ title: String, desc: String, isOn: Binding<Bool>) {
        self.title = title
        self.desc = desc
        _isOn = isOn
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.pmBody)
                Text(desc).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .overlay(Divider(), alignment: .top)
    }
}

// MARK: - 底部 CTA bar

struct BottomBar: View {
    let script: Script
    let onPracticeRecord: () -> Void
    let onDirectRecord: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Button("保存为模板") {}.buttonStyle(.textColor(.secondary))
                Button("导入 .txt / .md") {}.buttonStyle(.textColor(.secondary))
            }
            Spacer()
            HStack(spacing: 10) {
                Button("直接开始录制", action: onDirectRecord)
                    .buttonStyle(.pill)

                Button(action: onPracticeRecord) {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                        Text("开始练习录音")
                        Text("⇧⌘R").font(.pmMonoSmall).opacity(0.7)
                    }
                }
                .buttonStyle(.orangeCTA(size: .large))
                .disabled(script.wordCount == 0)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(.regularMaterial)
    }
}
