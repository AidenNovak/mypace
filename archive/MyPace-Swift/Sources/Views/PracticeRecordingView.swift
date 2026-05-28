//
//  PracticeRecordingView.swift
//  MyPace
//
//  练习录音 view —— 对应 tahoe.html 的 #v3 部分。
//  深色沉浸式 + 当前句呼吸高亮 + 底部实时波形。
//

import SwiftUI
import SwiftData

struct PracticeRecordingView: View {
    let script: Script

    @StateObject private var recorder = RecordingService()
    @State private var currentLineIndex: Int = 2  // demo：当前在第 3 句
    @State private var showAlignmentSheet: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            LinearGradient.darkSurface.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                stage
                shortcutsHint
                bottomBar
            }
        }
        .foregroundStyle(.white)
        .onAppear { try? recorder.startRecording() }
        .onDisappear { recorder.stopRecording() }
        .sheet(isPresented: $showAlignmentSheet) {
            AlignmentProgressSheet(
                audioURL: recorderAudioURL,
                script: script,
                onDone: { dismiss() }
            )
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 14) {
                RecPill()
                Text("\(script.title) · 练习 #\(script.recordings.count + 1)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()

            // 段落 / 进度
            HStack(spacing: 18) {
                meterGroup(label: "段落", value: "\(currentLineIndex+1)", suffix: "/\(lines.count)")
                meterGroup(label: "进度", value: "\(Int(progress * 100))", suffix: "%", showBar: true)
            }
        }
        .padding(.horizontal, 28).padding(.vertical, 18)
        .background(Color.white.opacity(0.05))
        .overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5), alignment: .bottom)
    }

    private func meterGroup(label: String, value: String, suffix: String, showBar: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.8)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text(suffix)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.appOrange)
            if showBar {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Color.appOrange)
                    .frame(width: 120)
            }
        }
    }

    // MARK: - Stage

    private var stage: some View {
        VStack(spacing: 14) {
            ForEach(visibleLines, id: \.0) { (index, text, style) in
                Text(text)
                    .font(style.font)
                    .foregroundStyle(style.color)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 780)
                    .padding(.leading, style == .current ? 36 : 0)
                    .shadow(
                        color: style == .current ? .appOrange.opacity(0.35) : .clear,
                        radius: 40
                    )
                    .overlay(alignment: .leading) {
                        if style == .current {
                            Circle()
                                .fill(Color.appRed)
                                .frame(width: 10, height: 10)
                                .shadow(color: .appRed, radius: 8)
                                .offset(x: 18)
                                .modifier(PulsingModifier())
                        }
                    }
            }
        }
        .padding(.horizontal, 100)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var visibleLines: [(Int, String, LineStyle)] {
        let total = lines.count
        let i = currentLineIndex
        var result: [(Int, String, LineStyle)] = []
        // past two
        if i - 2 >= 0 { result.append((i-2, lines[i-2], .past)) }
        if i - 1 >= 0 { result.append((i-1, lines[i-1], .past)) }
        // current
        if i < total { result.append((i, lines[i], .current)) }
        // next two
        if i + 1 < total { result.append((i+1, lines[i+1], .next)) }
        if i + 2 < total { result.append((i+2, lines[i+2], .future)) }
        return result
    }

    enum LineStyle {
        case past, current, next, future
        var font: Font {
            switch self {
            case .past: .pmPracticePast
            case .current: .pmPracticeCurrent
            case .next: .pmPracticeNext
            case .future: .pmPracticePast
            }
        }
        var color: Color {
            switch self {
            case .past, .future: .white.opacity(0.2)
            case .current: .appOrangeBright
            case .next: .white.opacity(0.45)
            }
        }
    }

    // MARK: - Shortcuts hint

    private var shortcutsHint: some View {
        HStack(spacing: 18) {
            shortcutPair("Space", "暂停")
            shortcutPair("R", "重录此句")
            shortcutPair("↑↓", "跳转")
            shortcutPair("Esc", "结束")
        }
        .padding(.vertical, 12)
        .font(.system(size: 10.5, weight: .regular, design: .monospaced))
        .foregroundStyle(.white.opacity(0.3))
    }

    private func shortcutPair(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                .foregroundStyle(.white.opacity(0.65))
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            Text(label)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 22) {
            // 时间码
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(formatTime(recorder.currentTime))
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                Text("/ ~ \(formatTime(estimatedTotal))")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            // 实时波形
            Waveform(samples: recorder.waveform, head: recorder.currentTime)
                .frame(height: 48)

            // 按钮组
            HStack(spacing: 8) {
                Button { recorder.markBeat() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(GlassCircleButtonStyle())

                Button {
                    if recorder.state == .recording {
                        recorder.pauseRecording()
                    } else if recorder.state == .paused {
                        try? recorder.resumeRecording()
                    }
                } label: {
                    Image(systemName: recorder.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(GlassCircleButtonStyle())

                Button { finishAndAlign() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(GlassCircleButtonStyle(role: .danger))
            }
        }
        .padding(.horizontal, 28).padding(.vertical, 20)
        .background(Color.black.opacity(0.25))
        .overlay(Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5), alignment: .top)
    }

    // MARK: - Helpers

    private var lines: [String] {
        script.content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.starts(with: "---") && !$0.starts(with: "#") }
    }

    private var progress: Double {
        guard !lines.isEmpty else { return 0 }
        return Double(currentLineIndex + 1) / Double(lines.count)
    }

    private var estimatedTotal: TimeInterval {
        Double(script.wordCount) / 3.0   // 3 字/秒
    }

    private var recorderAudioURL: URL? {
        if case .finished(let url) = recorder.state { return url }
        return nil
    }

    private func formatTime(_ d: TimeInterval) -> String {
        let m = Int(d) / 60
        let s = Int(d) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func finishAndAlign() {
        recorder.stopRecording()
        showAlignmentSheet = true
    }
}

// MARK: - Components

struct RecPill: View {
    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color.appRed)
                .frame(width: 7, height: 7)
                .shadow(color: .appRed, radius: 4)
                .modifier(PulsingModifier())
            Text("RECORDING")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(hex: 0xFF6B5E))
                .tracking(0.8)
        }
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(Color.appRed.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.appRed.opacity(0.35), lineWidth: 0.5))
    }
}

struct PulsingModifier: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 0.5 : 1)
            .scaleEffect(on ? 0.85 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    on.toggle()
                }
            }
    }
}

struct Waveform: View {
    let samples: [Float]
    let head: TimeInterval     // 当前时间（秒）—— 用来定位 playhead

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(displaySamples.enumerated()), id: \.offset) { i, v in
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.appOrangeBright, Color.appOrangeDeep],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 3, height: max(4, CGFloat(v) * geo.size.height))
                        .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 抽稀：最多显示 80 个柱子
    private var displaySamples: [Float] {
        guard samples.count > 80 else {
            // 不够 80 就用假数据填满
            let needed = 80 - samples.count
            return Array(repeating: Float(0.05), count: needed) + samples
        }
        let step = samples.count / 80
        return stride(from: 0, to: samples.count, by: step).map { samples[$0] }
    }
}

// MARK: - Alignment progress sheet

struct AlignmentProgressSheet: View {
    let audioURL: URL?
    let script: Script
    let onDone: () -> Void

    @State private var progress: Double = 0
    @State private var stepIndex: Int = 0
    @State private var errorMessage: String?
    @State private var resultSegments: [TranscribedSegment] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient.orangeSubtle)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().fill(Color.white).frame(width: 16, height: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text("正在生成节奏映射")
                        .font(.pmHeading)
                    Text("VOLCENGINE · ALIGNING")
                        .font(.pmMonoSmall)
                        .foregroundStyle(.tertiary)
                        .tracking(0.8)
                }
            }
            .padding(.bottom, 6)
            .overlay(Divider(), alignment: .bottom)

            Text("用 **火山引擎** 把刚才的练习对齐到稿子。完成后会自动跳到节奏编辑器。")
                .font(.pmBody)
                .foregroundStyle(.secondary)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.appOrange)

            HStack {
                Text("步骤 **\(stepIndex)** / 4")
                Spacer()
                Text("**\(Int(progress * 100))%**")
            }
            .font(.pmMono)
            .foregroundStyle(.secondary)

            if let err = errorMessage {
                Text(err).font(.pmBody).foregroundStyle(Color.appRed)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.pill)
            }
        }
        .padding(24)
        .frame(width: 440)
        .task { await runAlignment() }
    }

    private func runAlignment() async {
        guard let url = audioURL else {
            errorMessage = "没有录音文件"
            return
        }

        // v1 用 Mock；真实环境会从 KeychainService 读凭证
        let provider: ASRProvider = {
            if let cred = KeychainService.loadVolcengineCredentials() {
                return VolcengineASRProvider(appID: cred.appID, accessToken: cred.accessToken)
            }
            return MockASRProvider()
        }()

        stepIndex = 1
        do {
            resultSegments = try await provider.transcribe(
                audioURL: url,
                scriptHint: script.content,
                progress: { p in
                    Task { @MainActor in
                        self.progress = p
                        self.stepIndex = Int(p * 4) + 1
                    }
                }
            )
            stepIndex = 4
            progress = 1.0
            try? await Task.sleep(for: .milliseconds(400))
            onDone()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
