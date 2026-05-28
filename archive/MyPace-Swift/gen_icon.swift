//
// gen_icon.swift
// 用 Cocoa 程序生成 macOS 原生 squircle 图标
// 输出 1024x1024 PNG（透明背景 + squircle 橙色 + 大 M + 引导线）
//

import Cocoa
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@MainActor
func makeIcon(size: CGFloat) -> CGImage? {
    let pxSize = Int(size)
    guard let ctx = CGContext(
        data: nil,
        width: pxSize,
        height: pxSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // 设置 NSGraphicsContext 让 NSBezierPath 等 AppKit 接口能用
    let gCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gCtx
    defer { NSGraphicsContext.restoreGraphicsState() }

    // 1. 清空（透明）
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // 2. squircle 路径（macOS Big Sur+ 标准 superellipse）
    // 苹果原生比例：图标占整个方形 ~824/1024 ≈ 80.5%
    // 圆角半径 ≈ 22.37% of squircle width
    let inset = size * (1024 - 824) / 1024 / 2     // 边距
    let squircleRect = CGRect(x: inset, y: inset, width: size - inset*2, height: size - inset*2)
    let cornerRadius = squircleRect.width * 0.2237
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)

    // 3. 橙色渐变填充
    let colors = [
        NSColor(red: 1.0, green: 0.69, blue: 0.29, alpha: 1).cgColor,    // 顶部亮橙
        NSColor(red: 0.95, green: 0.42, blue: 0.06, alpha: 1).cgColor    // 底部深橙
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors as CFArray,
                              locations: [0, 1])!

    ctx.saveGState()
    squirclePath.addClip()
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: squircleRect.minX, y: squircleRect.maxY),
                           end: CGPoint(x: squircleRect.maxX, y: squircleRect.minY),
                           options: [])

    // 4. 顶部柔光（模拟苹果常见的光泽）
    let topLight = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.18).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor
        ] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(topLight,
                          start: CGPoint(x: 0, y: squircleRect.maxY),
                          end: CGPoint(x: 0, y: squircleRect.maxY - squircleRect.height * 0.5),
                          options: [])
    ctx.restoreGState()

    // 5. 内描边（提升立体感）
    ctx.saveGState()
    squirclePath.lineWidth = max(1, size / 512)
    NSColor.black.withAlphaComponent(0.12).setStroke()
    squirclePath.stroke()
    ctx.restoreGState()

    // 6. 大写 M（serif italic）
    let mFontSize = squircleRect.width * 0.62
    let mFont = NSFont(name: "Georgia-BoldItalic", size: mFontSize)
                ?? NSFont(name: "Times-BoldItalic", size: mFontSize)
                ?? NSFont.boldSystemFont(ofSize: mFontSize)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowOffset = NSSize(width: 0, height: -size/256)
    shadow.shadowBlurRadius = size / 128

    let mAttr: [NSAttributedString.Key: Any] = [
        .font: mFont,
        .foregroundColor: NSColor.white,
        .shadow: shadow,
    ]
    let mString = NSAttributedString(string: "M", attributes: mAttr)
    let mSize = mString.size()

    // 字体度量不准（特别是 italic），所以视觉居中 + 略微向上
    let mX = squircleRect.midX - mSize.width / 2
    let mY = squircleRect.midY - mSize.height / 2 + size * 0.04
    mString.draw(at: NSPoint(x: mX, y: mY))

    // 7. 底部引导线（提词器隐喻）
    ctx.saveGState()
    let lineWidth = squircleRect.width * 0.32
    let lineY = squircleRect.minY + squircleRect.height * 0.22
    let lineHeight = max(2, size / 256)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.5).cgColor)
    ctx.fill(CGRect(x: squircleRect.midX - lineWidth/2,
                    y: lineY,
                    width: lineWidth,
                    height: lineHeight))
    ctx.restoreGState()

    return ctx.makeImage()
}

func savePNG(_ cgImage: CGImage, to url: URL) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                      "public.png" as CFString,
                                                      1, nil) else { return false }
    CGImageDestinationAddImage(dest, cgImage, nil)
    return CGImageDestinationFinalize(dest)
}

@MainActor
func generateAllIcons() {
    let outDir = URL(fileURLWithPath: "Resources/AppIcon.iconset")
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    let sizes: [(name: String, px: Int)] = [
        ("16x16",        16),
        ("16x16@2x",     32),
        ("32x32",        32),
        ("32x32@2x",     64),
        ("128x128",      128),
        ("128x128@2x",   256),
        ("256x256",      256),
        ("256x256@2x",   512),
        ("512x512",      512),
        ("512x512@2x",   1024),
    ]

    for (name, px) in sizes {
        guard let img = makeIcon(size: CGFloat(px)) else {
            print("✗ failed: \(name)")
            continue
        }
        let out = outDir.appendingPathComponent("icon_\(name).png")
        if savePNG(img, to: out) {
            print("✓ \(name) (\(px)×\(px)) → \(out.lastPathComponent)")
        } else {
            print("✗ failed: \(name)")
        }
    }

    // 1024 单独再存一份原图（用于 README / 网站）
    if let big = makeIcon(size: 1024) {
        _ = savePNG(big, to: URL(fileURLWithPath: "Resources/icon-1024.png"))
    }
    print("\n✅ 全部生成完成")
}

@main
@MainActor
struct IconGen {
    static func main() {
        generateAllIcons()
    }
}
