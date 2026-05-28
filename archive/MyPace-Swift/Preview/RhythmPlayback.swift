//
//  RhythmPlayback.swift
//  MyPace Preview v0.2
//
//  按节奏映射自动滚动 —— MyPace 的核心差异化
//  每 100ms 检查时间戳，决定当前应该高亮哪一句
//

import Foundation

@MainActor
final class RhythmPlayback {

    private var rhythm: RhythmMap?
    private var timer: Timer?
    private var startedAt: Date?
    private var pausedAt: Date?
    private var totalPausedDuration: TimeInterval = 0

    private(set) var isPlaying = false
    private(set) var currentIndex: Int = 0
    /// 当前句里的第几个字（字级跟读用）。-1 表示句间停顿/无当前字
    private(set) var currentWordIndex: Int = -1

    /// 当前时间（秒）—— 受暂停影响
    var currentTime: TimeInterval {
        guard let started = startedAt else { return 0 }
        if let paused = pausedAt {
            return paused.timeIntervalSince(started) - totalPausedDuration
        }
        return Date.now.timeIntervalSince(started) - totalPausedDuration
    }

    var totalDuration: TimeInterval {
        rhythm?.totalDuration ?? 0
    }

    /// 当前播放进度 0.0 - 1.0
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1.0, currentTime / totalDuration)
    }

    /// 每次 tick 都调（30Hz），(sentenceIdx, wordIdx, currentTime)
    /// wordIdx = -1 表示当前没有字在念（句间停顿）
    var onTick: ((Int, Int, TimeInterval) -> Void)?
    var onComplete: (() -> Void)?

    // MARK: - 控制

    func load(rhythm: RhythmMap) {
        self.rhythm = rhythm
    }

    func start() {
        guard rhythm != nil, !isPlaying else { return }
        if startedAt == nil {
            startedAt = .now
            totalPausedDuration = 0
            currentIndex = 0
        } else if let paused = pausedAt {
            // 从暂停恢复
            totalPausedDuration += Date.now.timeIntervalSince(paused)
            pausedAt = nil
        }
        isPlaying = true
        startTimer()
    }

    func pause() {
        guard isPlaying else { return }
        pausedAt = .now
        isPlaying = false
        timer?.invalidate()
    }

    func reset() {
        timer?.invalidate()
        startedAt = nil
        pausedAt = nil
        totalPausedDuration = 0
        currentIndex = 0
        currentWordIndex = -1
        isPlaying = false
    }

    func toggle() {
        if isPlaying { pause() } else { start() }
    }

    /// 跳到指定句子（暂停状态下也能跳）
    func seek(toIndex i: Int) {
        guard let segs = rhythm?.segments, i >= 0, i < segs.count else { return }
        currentIndex = i
        // 把 startedAt 倒推，让 currentTime = segs[i].startTime
        let targetTime = segs[i].startTime
        if isPlaying {
            startedAt = .now.addingTimeInterval(-targetTime)
            totalPausedDuration = 0
            pausedAt = nil
        } else {
            // 暂停状态下也调整
            startedAt = .now.addingTimeInterval(-targetTime)
            pausedAt = .now
            totalPausedDuration = 0
        }
    }

    // MARK: - 私有

    private func startTimer() {
        timer?.invalidate()
        // 33ms ≈ 30Hz，对字级跟读够细腻又不太耗 CPU
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let segs = rhythm?.segments, !segs.isEmpty else { return }

        let t = currentTime

        // 1) 找当前句
        var newIndex = currentIndex
        for (i, seg) in segs.enumerated() {
            if t >= seg.startTime && t < seg.endTime {
                newIndex = i
                break
            }
            if t >= seg.endTime {
                newIndex = i
            }
        }
        if newIndex != currentIndex {
            currentIndex = newIndex
            currentWordIndex = -1    // 切句，重置
        }

        // 2) 在当前句里找当前字
        var newWordIdx = -1
        if let words = segs[currentIndex].words {
            for (i, w) in words.enumerated() {
                if t >= w.startTime && t < w.endTime {
                    newWordIdx = i
                    break
                }
                // 已经过了这个字（但还没到下一个） → 锁定在这个字上
                if t >= w.endTime {
                    newWordIdx = i
                }
            }
        }
        currentWordIndex = newWordIdx

        onTick?(currentIndex, currentWordIndex, t)

        // 全部播完
        if let last = segs.last, t >= last.endTime + 1.0 {
            pause()
            onComplete?()
        }
    }
}
