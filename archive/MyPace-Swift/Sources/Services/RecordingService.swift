//
//  RecordingService.swift
//  MyPace
//
//  录音服务 —— AVAudioEngine 实时录制 + 波形采样。
//  比 AVAudioRecorder 复杂，但能提供：
//    - 实时音量条
//    - 实时波形（每 50ms 一个采样）
//    - 节奏标记（用户按 R 时记录时间点）
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class RecordingService: ObservableObject {

    // MARK: - 发布的状态（SwiftUI 监听）

    @Published private(set) var state: State = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var amplitude: Float = 0       // 0.0 - 1.0 即时音量
    @Published private(set) var waveform: [Float] = []     // 历史波形采样
    @Published private(set) var beatMarkers: [TimeInterval] = []  // 用户标记的节拍点

    enum State: Equatable {
        case idle
        case recording
        case paused
        case finished(audioURL: URL)
        case error(message: String)
    }

    // MARK: - 内部

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var audioURL: URL?
    private var startedAt: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastPauseDate: Date?

    // 波形采样：每 50ms 一个，最多保留 60s × 20 = 1200 个
    private let waveformSampleInterval: TimeInterval = 0.05
    private var lastWaveformSampleAt: TimeInterval = 0
    private let maxWaveformSamples = 1200

    // MARK: - Public API

    func startRecording() throws {
        guard state == .idle else { return }

        // 准备文件
        let fm = FileManager.default
        let supportDir = try fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("MyPace/Recordings", isDirectory: true)
        try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)

        let url = supportDir.appendingPathComponent("\(UUID().uuidString).caf")
        audioURL = url

        // 准备 engine
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        // tap：每帧拿到 buffer，写文件 + 采样波形
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            try? self.audioFile?.write(from: buffer)
            self.processBuffer(buffer)
        }

        try engine.start()
        startedAt = .now
        pausedDuration = 0
        waveform.removeAll()
        beatMarkers.removeAll()
        state = .recording

        // 定时更新 currentTime
        startTimer()
    }

    func pauseRecording() {
        guard state == .recording else { return }
        lastPauseDate = .now
        engine.pause()
        state = .paused
    }

    func resumeRecording() throws {
        guard state == .paused else { return }
        if let paused = lastPauseDate {
            pausedDuration += Date.now.timeIntervalSince(paused)
            lastPauseDate = nil
        }
        try engine.start()
        state = .recording
    }

    func stopRecording() {
        guard state != .idle else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        timer?.invalidate()

        if let url = audioURL {
            state = .finished(audioURL: url)
        } else {
            state = .error(message: "音频文件未创建")
        }
    }

    /// 用户按 R 标记一个节拍点（"这一句重新念了"）
    func markBeat() {
        guard state == .recording else { return }
        beatMarkers.append(currentTime)
    }

    // MARK: - 私有

    private var timer: Timer?

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }

    private func updateCurrentTime() {
        guard let started = startedAt, state == .recording else { return }
        currentTime = Date.now.timeIntervalSince(started) - pausedDuration
    }

    private nonisolated func processBuffer(_ buffer: AVAudioPCMBuffer) {
        // 算 RMS（root mean square）音量
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameCount {
            let v = channelData[i]
            sum += v * v
        }
        let rms = sqrt(sum / Float(frameCount))
        // 归一化到 0-1（loose mapping）
        let normalized = min(1.0, rms * 8)

        Task { @MainActor in
            self.amplitude = normalized

            // 按时间间隔记录到 waveform
            if self.currentTime - self.lastWaveformSampleAt >= self.waveformSampleInterval {
                self.lastWaveformSampleAt = self.currentTime
                self.waveform.append(normalized)
                if self.waveform.count > self.maxWaveformSamples {
                    self.waveform.removeFirst(self.waveform.count - self.maxWaveformSamples)
                }
            }
        }
    }
}
