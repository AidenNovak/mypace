//
//  Tokens.swift
//  MyPace
//
//  设计令牌 —— 完全对应 tahoe.html 的 :root CSS 变量。
//  这是从 HTML 设计稿到 SwiftUI 的"桥梁"，改一处就能全局生效。
//

import SwiftUI

// MARK: - Color Tokens

extension Color {
    // 背景层
    static let bgPrimary    = Color(hex: 0xF2F2F4)
    static let bgDeep       = Color(hex: 0xE8E8EC)
    static let sidebar      = Color(hex: 0xF5F5F7).opacity(0.78)
    static let surface      = Color.white.opacity(0.72)
    static let surfaceSolid = Color.white

    // 分隔线（hairline）
    static let line         = Color.black.opacity(0.08)
    static let lineStrong   = Color.black.opacity(0.14)
    static let separator    = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12)

    // 文字 —— 苹果 HIG 颜色
    static let textPrimary    = Color(hex: 0x1D1D1F)
    static let textSecondary  = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.72)
    static let textTertiary   = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.48)
    static let textQuaternary = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.28)

    // 强调色 —— 系统蓝 + 品牌橙
    static let appBlue       = Color(hex: 0x007AFF)
    static let appBlueHover  = Color(hex: 0x0A84FF)
    static let appOrange     = Color(hex: 0xFF8A1F)
    static let appOrangeBright = Color(hex: 0xFFB04A)
    static let appOrangeDeep = Color(hex: 0xF26A0E)
    static let appOrangeGlow = Color(hex: 0xFF8A1F).opacity(0.22)

    // 语义色
    static let appGreen  = Color(hex: 0x34C759)
    static let appRed    = Color(hex: 0xFF3B30)
    static let appYellow = Color(hex: 0xFF9500)

    // 深色（用于 Practice Recording / Floating Teleprompter）
    static let darkBg      = Color(hex: 0x1C1C1E)
    static let darkBgDeep  = Color(hex: 0x0F0F11)
}

// MARK: - Convenience Hex Init

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Radii

enum Radius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 22
    static let pill: CGFloat = 999
}

// MARK: - Orange Gradient（CTA 主色）

extension LinearGradient {
    static let orangeCTA = LinearGradient(
        colors: [
            Color(hex: 0xFFB04A),
            Color(hex: 0xFF8A1F),
            Color(hex: 0xF26A0E),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let orangeSubtle = LinearGradient(
        colors: [Color(hex: 0xFFB04A), Color(hex: 0xF26A0E)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let darkSurface = LinearGradient(
        colors: [Color(hex: 0x1C1C1E), Color(hex: 0x0F0F11)],
        startPoint: .top,
        endPoint: .bottom
    )
}
