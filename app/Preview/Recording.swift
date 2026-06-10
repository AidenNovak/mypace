//
//  Recording.swift
//  MyPace Preview v0.5
//
//  录音 service —— 改用 AVAudioRecorder（v0.4 之前用 AVAudioEngine 录到 0 字节，bug）
//
//  AVAudioRecorder：
//    + 简单可靠，直接写 16kHz mono Int16 WAV
//    + 内置 metering，averagePower 拿实时音量
//    + macOS 沙盒友好
//    + 跟 AVAudioRecorder 在 iOS 一样的标准做法
//

import Foundation
import AVFoundation

@MainActor
final class RecordingService: NSObject {

    enum State: Equatable {
        case idle
        case requesting        // 请求麦克风权限中
        case recording
        case finished(URL, TimeInterval)
        case failed(String)
    }

    private(set) var state: State = .idle
    var onStateChange: ((State) -> Void)?
    var onLevel: ((Float) -> Void)?       // 实时音量 0.0-1.0

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var startedAt: Date?
    private var outputURL: URL?

    // MARK: - Permission

    /// 请求麦克风权限。已授权返回 true。
    static func requestMicrophonePermission() async -> Bool {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await AVAudioApplication.requestRecordPermission()
            @unknown default:
                return false
            }
        }
        return true    // 早期 macOS 不需要
    }

    static var microphonePermissionStatus: String {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:      return "已授权"
            case .denied:       return "已拒绝"
            case .undetermined: return "未询问"
            @unknown default:   return "未知"
            }
        }
        return "N/A"
    }

    // MARK: - Public API

    func start(saveTo url: URL) {
        if state != .idle {
            logWarn("RecordingService.start: forcing reset from state=\(state)")
            resetToIdle()
        }

        let outURL = url.deletingPathExtension().appendingPathExtension("wav")
        outputURL = outURL

        // 火山 ASR 要求的格式：16kHz, 16bit, mono, raw PCM in WAV
        let settings: [String: Any] = [
            AVFormatIDKey:               Int(kAudioFormatLinearPCM),
            AVSampleRateKey:             16000.0,
            AVNumberOfChannelsKey:       1,
            AVLinearPCMBitDepthKey:      16,
            AVLinearPCMIsBigEndianKey:   false,
            AVLinearPCMIsFloatKey:       false,
            AVLinearPCMIsNonInterleaved: false,
            AVEncoderAudioQualityKey:    AVAudioQuality.high.rawValue,
        ]

        logInfo("[REC] start saveTo=\(outURL.lastPathComponent) settings=16kHz/16bit/mono")

        do {
            let recorder = try AVAudioRecorder(url: outURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true

            guard recorder.prepareToRecord() else {
                logError("[REC] prepareToRecord returned false")
                setState(.failed("无法准备录音设备。请检查麦克风权限。"))
                return
            }

            guard recorder.record() else {
                logError("[REC] record() returned false")
                setState(.failed("无法开始录音。请检查麦克风权限或换个输入设备。"))
                return
            }

            self.recorder = recorder
            startedAt = .now
            setState(.recording)
            logInfo("[REC] recording started")

            // 启动音量轮询（每 50ms 一次）
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateLevel() }
            }
        } catch {
            logError("[REC] AVAudioRecorder init failed: \(error.localizedDescription)")
            setState(.failed("初始化录音失败：\(error.localizedDescription)"))
        }
    }

    func stop() {
        guard state == .recording, let recorder = recorder else {
            logWarn("[REC] stop ignored: state=\(state)")
            return
        }

        logInfo("[REC] stop called")
        recorder.stop()
        levelTimer?.invalidate()
        levelTimer = nil

        let duration = startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        guard let url = outputURL else {
            setState(.failed("录音输出路径丢失"))
            return
        }

        // 检查文件是否有内容
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        logInfo("[REC] finished file=\(url.lastPathComponent) duration=\(String(format: "%.2f", duration))s size=\(size) bytes")

        // WAV header 是 44 bytes；16kHz mono 16bit 录 1s 就是 32044 bytes
        // 小于 1KB 判定为"没采到声音"
        if size < 1024 {
            logError("[REC] file too small (\(size) bytes), microphone may not be granted")
            setState(.failed("录音文件几乎为空（\(size) 字节）。可能麦克风权限被拒绝。\n\n打开 系统设置 → 隐私与安全 → 麦克风，确认 MyPace Preview 已勾选。"))
            return
        }

        setState(.finished(url, duration))
    }

    // MARK: - 私有

    private func setState(_ new: State) {
        state = new
        onStateChange?(new)

        // 终端状态交付后立即重置为 idle，允许下一次新建录音
        if case .finished = new {
            Task { @MainActor in self.resetToIdle() }
        } else if case .failed = new {
            Task { @MainActor in self.resetToIdle() }
        }
    }

    private func resetToIdle() {
        recorder?.stop()
        levelTimer?.invalidate()
        levelTimer = nil
        recorder = nil
        startedAt = nil
        outputURL = nil
        state = .idle
    }

    private func updateLevel() {
        guard let recorder = recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        // averagePower 是 -160 (静音) ~ 0 (最响) dB
        let dB = recorder.averagePower(forChannel: 0)
        // 转成 0-1 的归一化值（-50dB → 0, 0dB → 1）
        let normalized = max(0, min(1, (dB + 50) / 50))
        onLevel?(normalized)
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            logInfo("[REC] delegate finished, success=\(flag)")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            logError("[REC] encode error: \(error?.localizedDescription ?? "unknown")")
        }
    }
}
