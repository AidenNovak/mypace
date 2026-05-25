//
//  ButtonStyles.swift
//  MyPace
//
//  按钮样式系统 —— 对应 HTML 设计稿的 .btn-primary / .btn-blue / .btn-ghost / .btn-pill。
//

import SwiftUI

// MARK: - 主 CTA · 渐变橙（"开始练习录音"等核心动作）

struct OrangeCTAButtonStyle: ButtonStyle {
    var size: ButtonSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(.white)
            .padding(.horizontal, size.hPadding)
            .padding(.vertical, size.vPadding)
            .background(
                LinearGradient.orangeCTA
                    .overlay(
                        // 内高光
                        LinearGradient(
                            colors: [.white.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .shadow(color: .appOrangeGlow, radius: 12, x: 0, y: 4)
            .shadow(color: .appOrangeGlow.opacity(0.5), radius: 28, x: 0, y: 12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    enum ButtonSize {
        case small, regular, large

        var font: Font {
            switch self {
            case .small:   .system(size: 12, weight: .semibold)
            case .regular: .system(size: 14, weight: .semibold)
            case .large:   .system(size: 15, weight: .semibold)
            }
        }
        var hPadding: CGFloat {
            switch self { case .small: 14; case .regular: 22; case .large: 26 }
        }
        var vPadding: CGFloat {
            switch self { case .small: 8;  case .regular: 13; case .large: 16 }
        }
    }
}

// MARK: - 蓝色 CTA · systemBlue（Modal 主操作"同意 · 开始"等）

struct BlueCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.appBlue)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: .appBlue.opacity(0.3), radius: 4, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - 玻璃灰 · 次操作（"取消"等）

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - 文字按钮（"本次跳过对齐"等）

struct TextButtonStyle: ButtonStyle {
    var color: Color = .appBlue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - 玻璃按钮（深色场景，如 Practice Recording）

struct GlassCircleButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    var role: GlassRole = .neutral

    enum GlassRole { case neutral, danger }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .foregroundStyle(.white)
            .background(
                Circle()
                    .fill(role == .danger ? Color.appRed : Color.white.opacity(0.1))
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: role == .danger ? .appRed.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 便捷扩展（让调用更顺手）

extension ButtonStyle where Self == OrangeCTAButtonStyle {
    static var orangeCTA: OrangeCTAButtonStyle { .init() }
    static func orangeCTA(size: OrangeCTAButtonStyle.ButtonSize) -> OrangeCTAButtonStyle {
        .init(size: size)
    }
}

extension ButtonStyle where Self == BlueCTAButtonStyle {
    static var blueCTA: BlueCTAButtonStyle { .init() }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { .init() }
}

extension ButtonStyle where Self == TextButtonStyle {
    static var textBlue: TextButtonStyle { .init(color: .appBlue) }
    static func textColor(_ color: Color) -> TextButtonStyle { .init(color: color) }
}
