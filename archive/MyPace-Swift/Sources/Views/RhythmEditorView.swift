//
//  RhythmEditorView.swift
//  MyPace
//
//  节奏编辑器 —— 对应 tahoe.html 的 #v4 部分。
//  这是 MyPace 的差异化核心 —— 节奏映射"可被人手修正"。
//

import SwiftUI
import SwiftData

struct RhythmEditorView: View {
    let recording: Recording

    @State private var selectedSegmentID: UUID?
    @State private var playheadPosition: TimeInterval = 0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0
    @State private var unsavedChanges = 7   // demo

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                wavePane.frame(maxWidth: .infinity)
                Divider()
                segmentPane.frame(width: 380)
            }
            Divider()
            transport
        }
        .background(Color.bgPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("节奏映射 · Practice #\(recording.script?.recordings.count ?? 1)")
                    .font(.pmHeading)
                HStack(spacing: 12) {
                    Text("由 VOLCENGINE 生成 · \(formatTime(recording.createdAt))")
                    Text("·").foregroundStyle(.tertiary)
                    Text("耗时 4.2 s")
                }
                .font(.pmMono)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if unsavedChanges > 0 {
                HStack(spacing: 7) {
                    Circle().fill(Color.white).frame(width: 6, height: 6).modifier(PulsingModifier())
                    Text("\(unsavedChanges) 处未保存修改")
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(LinearGradient.orangeSubtle, in: Capsule())
                .shadow(color: .appOrangeGlow, radius: 6, y: 2)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Wave pane

    private var wavePane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("", selection: .constant("100%")) {
                    Text("−").tag("-")
                    Text("100%").tag("100%")
                    Text("+").tag("+")
                    Text("适合屏幕").tag("fit")
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Spacer()
                Text("16 kHz · 单声道 · \(formatDuration(recording.duration)) 总时长")
                    .font(.pmMono)
                    .foregroundStyle(.tertiary)
            }

            // 时间轴
            HStack {
                ForEach([0, 30, 60, 90, 120, 150, 180], id: \.self) { sec in
                    Text(formatDuration(TimeInterval(sec)))
                        .font(.pmMonoSmall)
                        .foregroundStyle(.tertiary)
                    if sec != 180 { Spacer() }
                }
            }
            .padding(.vertical, 4)
            .overlay(Divider(), alignment: .bottom)

            // 波形画布
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12).fill(Color.surfaceSolid)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.separator, lineWidth: 0.5))

                RhythmWaveform(segments: recording.segments)
                    .padding(10)

                // playhead
                Rectangle()
                    .fill(Color.appRed)
                    .frame(width: 2)
                    .offset(x: 320)     // demo
                    .shadow(color: .appRed, radius: 8)
            }

            // 图例
            HStack(spacing: 14) {
                legendDot(.appGreen,  label: "高置信")
                legendDot(.appYellow, label: "需复核")
                legendDot(.appRed,    label: "低置信")
                Spacer()
                Text("右键拖拽 · 调整边界")
                    .font(.pmMono)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .background(Color.bgPrimary)
    }

    private func legendDot(_ color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(label).font(.pmMono).foregroundStyle(.secondary)
        }
    }

    // MARK: - Segment pane

    private var segmentPane: some View {
        VStack(spacing: 0) {
            // header
            HStack {
                Text("\(recording.segments.count) 个句子")
                    .font(.pmBodyBold)
                Spacer()
                let warn = recording.segments.filter { $0.tier == .medium }.count
                let bad = recording.segments.filter { $0.tier == .low }.count
                HStack(spacing: 6) {
                    Text("\(warn) 需复核")
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(bad) 低置信").foregroundStyle(Color.appRed)
                }
                .font(.pmMono)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .overlay(Divider(), alignment: .bottom)

            // list
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(recording.segments.sorted(by: { $0.index < $1.index })) { seg in
                        SegmentCard(
                            segment: seg,
                            isSelected: selectedSegmentID == seg.id
                        )
                        .onTapGesture { selectedSegmentID = seg.id }
                    }
                }
                .padding(14)
            }
        }
        .background(Color.surfaceSolid)
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: 14) {
            Button {} label: { Image(systemName: "backward.fill") }.buttonStyle(TransportButtonStyle())
            Button { isPlaying.toggle() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(Color.appOrangeBright)
            }
            .buttonStyle(TransportButtonStyle(isPrimary: true))
            Button {} label: { Image(systemName: "forward.fill") }.buttonStyle(TransportButtonStyle())

            HStack(spacing: 8) {
                Text("速度").font(.pmMono).foregroundStyle(.secondary)
                Slider(value: $playbackSpeed, in: 0.5...2.0).frame(width: 120)
                Text("\(playbackSpeed, specifier: "%.1f")×")
                    .font(.pmMono).foregroundStyle(Color.appBlue)
                    .frame(width: 36, alignment: .leading)
            }
            .padding(.leading, 12)

            Button("试播此句") {}.buttonStyle(.textColor(.secondary))
            Button("试播全部") {}.buttonStyle(.textColor(.secondary))

            Spacer()
            Button("丢弃修改") {}.buttonStyle(.pill)
            Button("保存并应用") {}.buttonStyle(.orangeCTA)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private func formatTime(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: d)
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        let m = Int(d) / 60
        let s = Int(d) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Segment Card

struct SegmentCard: View {
    let segment: RhythmSegment
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(format: "%02d", segment.index + 1))
                    .font(.pmMono).foregroundStyle(.secondary).fontWeight(.semibold)
                Spacer()
                Text("**\(formatTime(segment.startTime))** — \(formatTime(segment.endTime))")
                    .font(.pmMono).foregroundStyle(.tertiary)
            }
            Text(segment.text)
                .font(.pmBody)
                .foregroundStyle(.primary)
                .lineLimit(3)
            HStack(spacing: 8) {
                ProgressView(value: segment.confidence)
                    .progressViewStyle(.linear)
                    .tint(confidenceColor)
                    .frame(maxWidth: .infinity)
                Text("\(Int(segment.confidence * 100))%")
                    .font(.pmMonoSmall)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.appBlue : Color.separator,
                              lineWidth: isSelected ? 1.5 : 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .overlay(alignment: .topTrailing) {
            if segment.tier == .medium {
                Text("需复核").modifier(TierBadge(color: .appYellow))
            } else if segment.tier == .low {
                Text("低置信").modifier(TierBadge(color: .appRed))
            }
        }
    }

    private var cardBackground: some View {
        Group {
            switch segment.tier {
            case .high: Color.surfaceSolid
            case .medium:
                LinearGradient(colors: [Color(hex: 0xFFFCF2), Color(hex: 0xFFF8E0)],
                               startPoint: .top, endPoint: .bottom)
            case .low:
                LinearGradient(colors: [Color(hex: 0xFFF5F2), Color(hex: 0xFFECE5)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private var confidenceColor: Color {
        switch segment.tier {
        case .high: .appGreen
        case .medium: .appYellow
        case .low: .appRed
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct TierBadge: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color, in: UnevenRoundedRectangle(bottomLeadingRadius: 8))
            .tracking(0.4)
    }
}

// MARK: - Rhythm waveform (彩色按置信度分段)

struct RhythmWaveform: View {
    let segments: [RhythmSegment]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<200, id: \.self) { i in
                let s = pseudoSegment(at: i)
                Capsule()
                    .fill(color(for: s.tier))
                    .frame(width: 3, height: heightFor(i))
                    .opacity(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pseudoSegment(at i: Int) -> RhythmSegment {
        // demo：每 20 个柱子换一段
        let segIdx = i / 20
        if segIdx < segments.count {
            return segments[segIdx]
        }
        return RhythmSegment(index: 0, startTime: 0, endTime: 0, text: "", confidence: 0.9)
    }

    private func heightFor(_ i: Int) -> CGFloat {
        let center = 10.0
        let dist = abs(Double(i % 20) - center) / center
        let base = 0.45 + (1 - dist) * 0.55
        let noise = (sin(Double(i) * 0.7) + cos(Double(i) * 1.3)) * 0.15
        return CGFloat(max(5, (base + noise) * 160))
    }

    private func color(for tier: RhythmSegment.ConfidenceTier) -> Color {
        switch tier {
        case .high: .appGreen
        case .medium: .appYellow
        case .low: .appRed
        }
    }
}

// MARK: - Transport button style

struct TransportButtonStyle: ButtonStyle {
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isPrimary ? Color.appOrangeBright : Color.textPrimary)
            .frame(width: isPrimary ? 40 : 34, height: isPrimary ? 40 : 34)
            .background(
                Group {
                    if isPrimary {
                        Circle().fill(Color(hex: 0x1D1D1F))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.surfaceSolid)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.separator, lineWidth: 0.5))
                    }
                }
            )
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
