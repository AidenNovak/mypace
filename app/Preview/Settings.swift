//
//  Settings.swift
//  MyPace Preview
//
//  用户偏好 —— 字号、透明度、文字颜色等
//  存到 UserDefaults
//

import Foundation
import AppKit

@MainActor
final class UserSettings {

    static let shared = UserSettings()

    // MARK: - Keys

    private enum Key {
        static let hasSeenWelcome = "hasSeenWelcome"
        static let currentFontSize = "currentFontSize"
        static let opacity = "opacity"
        static let accentColor = "accentColor"
        static let showGuideline = "showGuideline"
        static let breathingDot = "breathingDot"
        static let allowScreenCapture = "allowScreenCapture"
        static let language = "language"
    }

    private let defaults = UserDefaults.standard

    // MARK: - 欢迎页

    var hasSeenWelcome: Bool {
        get { defaults.bool(forKey: Key.hasSeenWelcome) }
        set { defaults.set(newValue, forKey: Key.hasSeenWelcome) }
    }

    // MARK: - 视觉偏好

    var currentFontSize: CGFloat {
        get {
            let v = defaults.double(forKey: Key.currentFontSize)
            return v > 0 ? CGFloat(v) : 28
        }
        set { defaults.set(Double(newValue), forKey: Key.currentFontSize) }
    }

    var opacity: CGFloat {
        get {
            let v = defaults.double(forKey: Key.opacity)
            return v > 0 ? CGFloat(v) : 0.92
        }
        set { defaults.set(Double(newValue), forKey: Key.opacity) }
    }

    var accentColor: AccentColor {
        get {
            let raw = defaults.string(forKey: Key.accentColor) ?? AccentColor.violet.rawValue
            return AccentColor(rawValue: raw) ?? .violet
        }
        set { defaults.set(newValue.rawValue, forKey: Key.accentColor) }
    }

    var showGuideline: Bool {
        get {
            if defaults.object(forKey: Key.showGuideline) == nil { return true }
            return defaults.bool(forKey: Key.showGuideline)
        }
        set { defaults.set(newValue, forKey: Key.showGuideline) }
    }

    var breathingDot: Bool {
        get {
            if defaults.object(forKey: Key.breathingDot) == nil { return true }
            return defaults.bool(forKey: Key.breathingDot)
        }
        set { defaults.set(newValue, forKey: Key.breathingDot) }
    }

    /// 调试用：是否允许窗口被屏幕录制看到（默认 false,即对相机隐形）
    /// vlogger 想截图发反馈时打开
    var allowScreenCapture: Bool {
        get { defaults.bool(forKey: Key.allowScreenCapture) }
        set { defaults.set(newValue, forKey: Key.allowScreenCapture) }
    }

    // MARK: - 语言

    var language: Language {
        get {
            let raw = defaults.string(forKey: Key.language) ?? Language.auto.rawValue
            return Language(rawValue: raw) ?? .auto
        }
        set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }
}

// MARK: - 色彩主题

enum AccentColor: String, CaseIterable {
    case violet = "violet"    // 蓝紫（默认，与图标一致）
    case cyan   = "cyan"      // 青蓝
    case rose   = "rose"      // 玫瑰粉

    var color: NSColor {
        switch self {
        case .violet: NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1)
        case .cyan:   NSColor(red: 0.30, green: 0.70, blue: 0.95, alpha: 1)
        case .rose:   NSColor(red: 0.90, green: 0.40, blue: 0.60, alpha: 1)
        }
    }

    var label: String {
        switch self {
        case .violet: "蓝紫"
        case .cyan:   "青蓝"
        case .rose:   "玫瑰"
        }
    }
}
