//
//  Script.swift
//  MyPace
//
//  脚本数据模型 —— SwiftData @Model。
//  对应设计稿里 Dashboard 的"最近脚本"卡片 + Editor 编辑的内容。
//

import Foundation
import SwiftData

@Model
final class Script {
    // MARK: 标识
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    // MARK: 内容
    var title: String
    var content: String         // Markdown 文本（支持 --- 断点语法）
    var tags: [String]          // ["口播视频", "知识科普"] 等

    // MARK: 视觉偏好（编辑器右侧 Inspector 控制）
    var fontSize: Double = 48
    var opacity: Double = 0.92
    var textColorRaw: String = "cream"     // cream / white / amber
    var bgColorRaw: String = "ink"         // ink / dark / black
    var showGuideLine: Bool = true
    var showNextLine: Bool = true
    var paragraphPause: Bool = false
    var excludeFromCapture: Bool = true    // ScreenCaptureKit 排除

    // MARK: 滚动模式
    var scrollModeRaw: String = "manual"   // "manual" / "rhythm"

    // MARK: 关联
    @Relationship(deleteRule: .cascade, inverse: \Recording.script)
    var recordings: [Recording] = []

    // MARK: 派生属性
    var wordCount: Int {
        content.filter { !$0.isWhitespace && !$0.isNewline }.count
    }

    /// 基于最近一次有 rhythmMap 的录音，估算时长（秒）
    var estimatedDuration: TimeInterval? {
        recordings.sorted { $0.createdAt > $1.createdAt }
                  .first(where: { $0.rhythmMap != nil })?
                  .duration
    }

    var status: ScriptStatus {
        if recordings.contains(where: { $0.rhythmMap != nil }) {
            return .mapped
        } else if recordings.isEmpty {
            return .draft
        } else {
            return .recorded
        }
    }

    // MARK: Init
    init(title: String, content: String = "", tags: [String] = []) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.title = title
        self.content = content
        self.tags = tags
    }
}

// MARK: - Enums

enum ScriptStatus: String, CaseIterable {
    case draft       // 草稿
    case recorded    // 已录制
    case mapped      // 已映射

    var label: String {
        switch self {
        case .draft:    "草稿"
        case .recorded: "已录制"
        case .mapped:   "已映射"
        }
    }
}

enum ScrollMode: String, CaseIterable {
    case manual    // 手动
    case rhythm    // 节奏同步

    var label: String {
        switch self {
        case .manual: "手动"
        case .rhythm: "节奏同步"
        }
    }
}

// MARK: - 预览数据（开发期用）

extension Script {
    static var preview: Script {
        let s = Script(
            title: "三分钟讲清「价值锚定」",
            content: """
            # 三分钟讲清「价值锚定」

            很多人以为定价是个数学题。其实它更像一场心理游戏 —— 你卖的不是产品本身，而是它在客户心里值多少。

            ---

            我给你举一个反直觉的例子。假设你卖一杯咖啡，标价 30 块。客户大概率觉得贵。

            但如果你把它放在一份 198 块的下午茶套餐里，同样的咖啡，客户连眼都不眨。因为参照系变了。

            ---

            所以做定价之前，你要先想：我让客户拿什么跟我比？
            """,
            tags: ["知识科普"]
        )
        return s
    }

    static var previewList: [Script] {
        [
            Script(title: "三分钟讲清「价值锚定」", tags: ["知识科普"]),
            Script(title: "品牌发布会开场", tags: ["口播视频"]),
            Script(title: "给团队的年终回顾", tags: ["口播视频"]),
            Script(title: "访谈开场白 · Vol.07", tags: ["口播视频"]),
            Script(title: "课程模块 02 · 视觉锚点", tags: ["知识科普"]),
            Script(title: "30 秒产品演示", tags: ["短带货"]),
        ]
    }
}
