//
//  ASRService.swift
//  MyPace
//
//  语音识别服务抽象层。
//  v1 只接火山引擎；v1.1+ 可以加 SenseVoice / macOS Speech 实现同一协议。
//

import Foundation

// MARK: - 协议

/// 所有 ASR 提供商必须实现这个协议
protocol ASRProvider {
    /// 把录音文件对齐到脚本，返回带时间戳的句子列表
    /// - Parameters:
    ///   - audioURL: 本地音频文件（wav / m4a，16kHz 单声道最优）
    ///   - scriptHint: 已知的稿件文本（提高识别精度，火山支持 hot-words）
    ///   - progress: 上传/识别进度回调（0.0 - 1.0）
    /// - Returns: 按时间排序的句子列表
    func transcribe(
        audioURL: URL,
        scriptHint: String?,
        progress: ((Double) -> Void)?
    ) async throws -> [TranscribedSegment]

    /// 提供商显示名（"火山引擎" / "SenseVoice"）
    var displayName: String { get }

    /// 是否需要联网
    var isCloudBased: Bool { get }
}

// MARK: - 中间数据结构

/// ASR 返回的原始识别结果（还没绑定到 SwiftData Recording）
struct TranscribedSegment {
    let index: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let confidence: Double          // 0.0 - 1.0
    let alternativeTexts: [String]  // 备选词
}

// MARK: - 错误类型

enum ASRError: LocalizedError {
    case missingCredentials
    case invalidAudioFile
    case networkFailure(underlying: Error)
    case serverError(code: Int, message: String)
    case timeout
    case lowConfidence(averageConfidence: Double)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "缺少 ASR 凭证。请在设置里导入闪电说凭证或手动输入。"
        case .invalidAudioFile:
            "音频文件无效或损坏。"
        case .networkFailure(let err):
            "网络错误：\(err.localizedDescription)"
        case .serverError(let code, let msg):
            "服务端错误 (\(code))：\(msg)"
        case .timeout:
            "对齐超时（>60s），建议重试或切换网络。"
        case .lowConfidence(let avg):
            "整体置信度偏低（\(Int(avg*100))%），建议重新录制。"
        }
    }
}

// MARK: - Mock 实现（开发期 + 没凭证时跑 UI）

/// 离线 Mock —— 不依赖网络，返回 fake 数据
final class MockASRProvider: ASRProvider {
    let displayName = "Mock (Dev)"
    let isCloudBased = false

    func transcribe(
        audioURL: URL,
        scriptHint: String?,
        progress: ((Double) -> Void)?
    ) async throws -> [TranscribedSegment] {
        // 模拟上传/识别耗时 + 进度回调
        for step in stride(from: 0.0, through: 1.0, by: 0.1) {
            try? await Task.sleep(for: .milliseconds(200))
            progress?(step)
        }

        // 用脚本提示生成假数据；没提示就用 demo 数据
        let sentences = (scriptHint?
            .split(whereSeparator: { ",.!?。，！？\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        ) ?? [
            "很多人以为定价是个数学题",
            "其实它更像一场心理游戏",
            "你卖的不是产品本身",
            "而是它在客户心里值多少"
        ]

        var t: TimeInterval = 0
        return sentences.enumerated().map { i, text in
            let duration = Double(text.count) * 0.3 + 0.5  // 0.3s/字
            let segment = TranscribedSegment(
                index: i,
                startTime: t,
                endTime: t + duration,
                text: text,
                confidence: confidenceForDemo(i),
                alternativeTexts: i == 2 ? ["你卖的不是产品本身", "你贵的不是产品本身"] : []
            )
            t += duration + 0.2
            return segment
        }
    }

    // 让 demo 数据有"低置信"句子，方便测试 UI
    private func confidenceForDemo(_ i: Int) -> Double {
        switch i % 5 {
        case 0: 0.92
        case 1: 0.88
        case 2: 0.64  // warn
        case 3: 0.38  // bad
        default: 0.91
        }
    }
}
