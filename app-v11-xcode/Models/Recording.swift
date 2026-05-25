//
//  Recording.swift
//  MyPace
//
//  录音 + 节奏映射数据模型。
//

import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var createdAt: Date
    var duration: TimeInterval        // 录音总时长（秒）
    var audioFileURLString: String?   // 沙盒内音频文件路径
    var script: Script?

    /// 节奏映射：每个句子的时间戳 + 置信度
    /// nil 表示尚未对齐
    @Relationship(deleteRule: .cascade, inverse: \RhythmSegment.recording)
    var segments: [RhythmSegment] = []

    /// 是否已生成节奏映射（segments 非空）
    var rhythmMap: [RhythmSegment]? {
        segments.isEmpty ? nil : segments
    }

    /// 平均置信度（用于判断是否要弹"低置信"警告）
    var averageConfidence: Double {
        guard !segments.isEmpty else { return 0 }
        let sum = segments.reduce(0.0) { $0 + $1.confidence }
        return sum / Double(segments.count)
    }

    /// 低置信句子数
    var lowConfidenceCount: Int {
        segments.filter { $0.confidence < 0.5 }.count
    }

    init(duration: TimeInterval = 0, audioFileURLString: String? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.duration = duration
        self.audioFileURLString = audioFileURLString
    }
}

@Model
final class RhythmSegment {
    var id: UUID
    var index: Int                 // 句子在脚本中的序号
    var startTime: TimeInterval    // 起始时间戳（秒）
    var endTime: TimeInterval      // 结束时间戳（秒）
    var text: String               // ASR 识别出的文本
    var confidence: Double         // 0.0 - 1.0 置信度
    var alternativeTexts: [String] // ASR 给的备选词，[值多少 / 直多少]
    var recording: Recording?

    enum ConfidenceTier {
        case high, medium, low
    }

    var tier: ConfidenceTier {
        if confidence >= 0.8 { return .high }
        if confidence >= 0.5 { return .medium }
        return .low
    }

    init(
        index: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        confidence: Double = 1.0,
        alternativeTexts: [String] = []
    ) {
        self.id = UUID()
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
        self.alternativeTexts = alternativeTexts
    }
}
