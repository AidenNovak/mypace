//
// verify_rec.swift
// 独立验证：AVAudioRecorder 能否录到声音（验证 v0.4 录音 bug 的修复）
// 录 5 秒到 /tmp/verify_rec_test.wav，打印文件大小 + 用 say 验证文件
//

import Foundation
import AVFoundation

@MainActor
class RecTest: NSObject, AVAudioRecorderDelegate {

    var recorder: AVAudioRecorder?

    func run() {
        let url = URL(fileURLWithPath: "/tmp/verify_rec_test.wav")
        try? FileManager.default.removeItem(at: url)

        let settings: [String: Any] = [
            AVFormatIDKey:               Int(kAudioFormatLinearPCM),
            AVSampleRateKey:             16000.0,
            AVNumberOfChannelsKey:       1,
            AVLinearPCMBitDepthKey:      16,
            AVLinearPCMIsBigEndianKey:   false,
            AVLinearPCMIsFloatKey:       false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true

            guard let rec = recorder, rec.prepareToRecord() else {
                print("❌ prepareToRecord failed")
                exit(1)
            }
            guard rec.record() else {
                print("❌ record() failed")
                exit(2)
            }

            print("✓ 开始录音 (5 秒)")
            print("  → 我现在用 say 命令朝麦克风外放一段中文...")

            // 用 say 命令同时播放声音（系统会从扬声器播，麦克风能拾到）
            Task.detached {
                let task = Process()
                task.launchPath = "/usr/bin/say"
                task.arguments = ["-v", "Tingting", "-r", "150", "测试录音。一二三四五。"]
                try? task.run()
            }

            // 5 秒后停止
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                Task { @MainActor in
                    self.finish(url: url)
                }
            }
        } catch {
            print("❌ AVAudioRecorder init failed: \(error)")
            exit(3)
        }
    }

    func finish(url: URL) {
        recorder?.stop()
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        print("")
        print("─────────────────────────────────────────────")
        print("录音完成: \(url.path)")
        print("文件大小: \(size) bytes")
        print("期望: > 80,000 bytes (5s × 16kHz × 16bit / 8)")

        if size > 80000 {
            print("✅ 录音成功！AVAudioRecorder fix works.")
        } else if size > 1024 {
            print("⚠️ 文件有内容但偏小，可能音量太小")
        } else {
            print("❌ 录音失败：文件几乎为空 (size=\(size))")
        }
        print("─────────────────────────────────────────────")
        exit(0)
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("delegate: finished, success=\(flag)")
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("delegate: encode error: \(error?.localizedDescription ?? "?")")
    }
}

@main
@MainActor
struct VerifyMain {
    static func main() {
        let test = RecTest()
        test.run()
        RunLoop.main.run()
    }
}
