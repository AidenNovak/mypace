//
//  Models.swift
//  MyPace Preview
//
//  Codable 数据模型 —— 全部用 JSON 持久化（不需要 SwiftData，因此不需要 Xcode）
//

import Foundation

// MARK: - Script

struct Script: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var lines: [String]
    var createdAt: Date
    var updatedAt: Date

    // 节奏映射：每句一个时间戳，nil 表示尚未生成
    var rhythm: RhythmMap?

    init(id: UUID = UUID(), title: String, lines: [String] = []) {
        self.id = id
        self.title = title
        self.lines = lines
        self.createdAt = .now
        self.updatedAt = .now
    }

    var hasRhythm: Bool { rhythm != nil && !(rhythm?.segments.isEmpty ?? true) }
}

// MARK: - Rhythm Map（节奏映射）

struct RhythmMap: Codable, Equatable {
    var segments: [Segment]
    var audioFilename: String?      // 录音文件名（相对于 Recordings/ 目录）
    var totalDuration: TimeInterval
    var createdAt: Date

    struct Segment: Codable, Equatable {
        var index: Int              // 对应 Script.lines 的索引
        var startTime: TimeInterval // 秒
        var endTime: TimeInterval
        var text: String            // ASR 识别到的文本
        var confidence: Double      // 0.0 - 1.0
        var words: [Word]?          // ✨ 字级时间戳（火山引擎返回的 per-character 时间戳）
    }

    /// 单字时间戳 —— 用于做"逐字跟读"高亮动效
    struct Word: Codable, Equatable {
        var text: String            // 单个字 / 词
        var startTime: TimeInterval // 秒（火山原始数据是 ms，存的时候转秒）
        var endTime: TimeInterval
    }
}

// MARK: - Demo Script（首次启动种子数据）

extension Script {
    static func demo() -> Script {
        Script(title: "MyPace · 示例稿件", lines: [
            "大家好，欢迎来到本期视频。",
            "今天我想跟你聊一件被严重低估的事 ——",
            "好的内容，永远赢不过好的节奏。",
            "你说的同一段话，节奏不一样，效果差十倍。",
            "下面我用三个例子说明。",
            "第一个例子：开场。",
            "高手开场只有三句话，但每一句都是钩子。",
            "第二个例子：转折。",
            "在最关键的地方，他们一定会停一秒。",
            "第三个例子：结尾。",
            "结尾不是结束，而是把观众推向下一个动作。"
        ])
    }
}
