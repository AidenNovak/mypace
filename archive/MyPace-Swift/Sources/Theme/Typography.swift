//
//  Typography.swift
//  MyPace
//
//  字体系统 —— 全部用系统字体，0 网络加载。
//

import SwiftUI

extension Font {
    // Display —— 大标题（28-64pt）
    static let pmDisplayXL = Font.system(size: 64, weight: .bold,    design: .default)
    static let pmDisplayL  = Font.system(size: 32, weight: .bold,    design: .default)
    static let pmDisplayM  = Font.system(size: 26, weight: .bold,    design: .default)
    static let pmDisplayS  = Font.system(size: 20, weight: .semibold,design: .default)

    // UI —— 界面文字
    static let pmHeading   = Font.system(size: 17, weight: .semibold, design: .default)
    static let pmBody      = Font.system(size: 13.5, weight: .regular, design: .default)
    static let pmBodyBold  = Font.system(size: 13.5, weight: .semibold, design: .default)
    static let pmCaption   = Font.system(size: 12, weight: .regular, design: .default)
    static let pmCaption2  = Font.system(size: 11, weight: .medium, design: .default)

    // Mono —— 技术信息（时间码、配额、快捷键）
    static let pmMono      = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let pmMonoSmall = Font.system(size: 10, weight: .semibold, design: .monospaced)
    static let pmMonoLarge = Font.system(size: 18, weight: .semibold, design: .monospaced)

    // Editor —— 稿纸正文（对应 HTML 17px / line-height 1.75）
    static let pmEditor    = Font.system(size: 17, weight: .regular, design: .default)
    static let pmEditorH1  = Font.system(size: 30, weight: .bold,    design: .default)

    // Teleprompter —— 浮动提词器
    static let pmTeleprompter = Font.system(size: 30, weight: .semibold, design: .default)
    static let pmTeleNext     = Font.system(size: 20, weight: .medium,   design: .default)

    // Practice mode —— 沉浸式录音的大字
    static let pmPracticeCurrent = Font.system(size: 38, weight: .semibold, design: .default)
    static let pmPracticeNext    = Font.system(size: 22, weight: .medium,   design: .default)
    static let pmPracticePast    = Font.system(size: 18, weight: .regular,  design: .default)
}
