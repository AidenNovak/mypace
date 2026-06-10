//
//  WordRunView.swift
//  MyPace Preview
//
//  字级跟读视图 —— 每个字独立 CATextLayer。
//  当前字 scale(1.05) 不抖（因为 transform 不影响其他 layer 的 frame）。
//

import Cocoa

@MainActor
final class WordRunView: NSView {

    // MARK: - 公共状态

    private(set) var words: [String] = []
    private var currentIdx: Int = -1
    /// 渲染模式：tracking = 跟读（当前字缩放）; idle = 待播放（全亮等待）
    private var mode: Mode = .idle

    enum Mode { case idle, tracking }

    var fontSize: CGFloat = 28 {
        didSet { rebuildIfNeeded() }
    }
    var accentColor: NSColor = .systemOrange {
        didSet { restyleAll() }
    }

    // MARK: - 内部

    private var layers: [CATextLayer] = []
    private var lineRanges: [Range<Int>] = []    // 每行包含哪些 layer 的 index

    /// 当前缩放比例（仅当前字）
    private let currentScale: CGFloat = 1.05

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    /// 设置完整字数组 —— 重建所有 layer + 布局
    func setWords(_ newWords: [String], currentIdx: Int = -1) {
        let needRebuild = (newWords != words)
        words = newWords

        if needRebuild {
            rebuildLayers()
        }
        layoutLayers()
        setCurrent(currentIdx, animated: false)
    }

    /// 切换模式：idle = 全亮等待；tracking = 字级跟读
    func setMode(_ newMode: Mode, animated: Bool = true) {
        if mode == newMode { return }
        mode = newMode
        restyleAll(animated: animated)
    }

    /// 切换当前字（带 spring 过渡动画）
    func setCurrent(_ idx: Int, animated: Bool = true) {
        let old = currentIdx
        currentIdx = idx
        if old == idx { return }

        // 旧当前字：恢复 identity scale + 普通色
        if old >= 0 && old < layers.count {
            styleLayer(layers[old], distance: distanceFrom(idx: old, current: idx), animated: animated)
        }
        // 新当前字：放大 + 高亮
        if idx >= 0 && idx < layers.count {
            styleLayer(layers[idx], distance: 0, animated: animated)
        }
        // ±1 ±2 字也要更新（它们的 distance 变了）
        for offset in [-2, -1, 1, 2] {
            for i in [old + offset, idx + offset] {
                if i >= 0 && i < layers.count && i != old && i != idx {
                    styleLayer(layers[i], distance: distanceFrom(idx: i, current: idx), animated: animated)
                }
            }
        }
        // 已念的字（前一字往前到 old-2）也要从"前后字"变回"已念过"
        if old > idx {
            // 跳句回退场景，重新刷全部
            restyleAll()
        }
    }

    // MARK: - 布局

    private func rebuildIfNeeded() {
        rebuildLayers()
        layoutLayers()
    }

    private func rebuildLayers() {
        // 移除旧 layer
        layers.forEach { $0.removeFromSuperlayer() }
        layers.removeAll()

        guard let parent = layer else { return }
        let scale = window?.backingScaleFactor ?? 2.0

        for w in words {
            let l = CATextLayer()
            l.string = w
            l.font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
            l.fontSize = fontSize
            l.alignmentMode = .center
            l.contentsScale = scale
            l.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            l.allowsEdgeAntialiasing = true
            l.allowsFontSubpixelQuantization = true
            l.foregroundColor = accentColor.withAlphaComponent(0.42).cgColor
            parent.addSublayer(l)
            layers.append(l)
        }
    }

    private func layoutLayers() {
        guard !layers.isEmpty else { return }

        let maxWidth = bounds.width
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let lineHeight = ceil(font.ascender - font.descender + font.leading) * 1.2

        // 1. 算每个字的宽度（按"凸"字给点 padding 避免被 transform 切边）
        let widths = words.map { word -> CGFloat in
            let s = (word as NSString).size(withAttributes: [.font: font])
            return ceil(s.width) + 2    // +2 给 scale 1.05 留 buffer
        }

        // 2. 分行
        var lines: [[Int]] = []
        var current: [Int] = []
        var lineW: CGFloat = 0
        for (i, w) in widths.enumerated() {
            if lineW + w > maxWidth && !current.isEmpty {
                lines.append(current)
                current = []
                lineW = 0
            }
            current.append(i)
            lineW += w
        }
        if !current.isEmpty { lines.append(current) }
        lineRanges = lines.map { ($0.first!)..<($0.last! + 1) }

        // 3. 放置（垂直居中所有行）
        let totalH = CGFloat(lines.count) * lineHeight
        var y = bounds.midY + totalH / 2 - lineHeight / 2

        for line in lines {
            let lineWidth = line.reduce(0) { $0 + widths[$1] }
            var x = (maxWidth - lineWidth) / 2    // 居中
            for idx in line {
                let w = widths[idx]
                layers[idx].bounds = CGRect(x: 0, y: 0, width: w, height: lineHeight)
                layers[idx].position = CGPoint(x: x + w / 2, y: y)
                x += w
            }
            y -= lineHeight
        }
    }

    override func layout() {
        super.layout()
        layoutLayers()
    }

    // MARK: - 样式

    /// distance: 跟当前字的距离（绝对值）。-1 表示没有当前字。
    private func distanceFrom(idx: Int, current: Int) -> Int {
        guard current >= 0 else { return Int.max }
        return idx - current    // 注意：含正负号（已念 vs 未念）
    }

    /// 给单个 layer 应用样式（颜色 + scale）
    private func styleLayer(_ l: CATextLayer, distance d: Int, animated: Bool) {
        // Idle 模式：所有字 100% accent，无缩放（等待用户点播放）
        if mode == .idle {
            let apply: () -> Void = {
                l.foregroundColor = self.accentColor.cgColor
                l.transform = CATransform3DIdentity
            }
            if animated {
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.15)
                apply()
                CATransaction.commit()
            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                apply()
                CATransaction.commit()
            }
            return
        }

        // Tracking 模式：按距离当前字渲染
        let absD = abs(d)
        let color: NSColor
        let scale: CGFloat
        switch absD {
        case 0:
            color = accentColor                     // 当前字
            scale = currentScale                    // 1.05
        case 1:
            color = accentColor.withAlphaComponent(0.82)
            scale = 1.0
        case 2:
            color = accentColor.withAlphaComponent(0.60)
            scale = 1.0
        case Int.max:
            color = accentColor.withAlphaComponent(0.42)    // 没当前字（句间）
            scale = 1.0
        default:
            if d < -2 {
                // 已念过的字
                color = NSColor.white.withAlphaComponent(0.28)
            } else {
                // 未念到的字
                color = accentColor.withAlphaComponent(0.42)
            }
            scale = 1.0
        }

        let apply: () -> Void = {
            l.foregroundColor = color.cgColor
            l.transform = CATransform3DMakeScale(scale, scale, 1)
        }

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.18)
            // 用 timing function 模拟 spring 感（不真的 spring，因为 CABasicAnimation 不支持）
            CATransaction.setAnimationTimingFunction(
                CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)   // overshoot
            )
            apply()
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            apply()
            CATransaction.commit()
        }
    }

    private func restyleAll(animated: Bool = false) {
        for (i, l) in layers.enumerated() {
            styleLayer(l, distance: distanceFrom(idx: i, current: currentIdx), animated: animated)
        }
    }
}
