//
//  WindowManager.swift
//  MyPace
//
//  =====================================================================
//  整个 MyPace 项目最关键的一个文件。
//
//  做两件事：
//  1. 创建浮动提词器窗口（always-on-top、可拖拽、可调大小、半透明）
//  2. ✨ 把这个窗口从所有屏幕录制中"隐藏"，确保 vlogger 录视频时
//     提词器不会出现在录制画面里。
//
//  原理：
//  - macOS 13+ 提供了 NSWindow.sharingType = .none，告诉系统这个
//    窗口不参与屏幕共享。
//  - ScreenCaptureKit (macOS 13+) 在采集时会自动尊重这个标记。
//  - 这意味着 QuickTime、OBS、Loom、ZOOM 屏幕共享等所有走系统 API
//    的录制工具，都不会看到这个窗口。
//
//  这就是 MyPace 的技术护城河。
//  =====================================================================

import AppKit
import SwiftUI

@MainActor
final class WindowManager: ObservableObject {

    static let shared = WindowManager()

    private var floatingTeleprompterWindow: NSWindow?

    private init() {}

    // MARK: - 创建/显示浮动提词器窗口

    func showFloatingTeleprompter<Content: View>(@ViewBuilder content: () -> Content) {
        // 如果已存在，直接置前
        if let win = floatingTeleprompterWindow {
            win.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(rootView: content())

        let window = TransparentFloatingWindow(
            contentRect: NSRect(x: 200, y: 200, width: 520, height: 280),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // ---- 视觉 ----
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView = hostingView

        // ---- 行为：始终置顶 ----
        // .floating 表示比普通窗口高，但比 .modalPanel 低
        // 我们用 .statusBar 让它即使在全屏 App 上也可见（适合录屏场景）
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,         // 切换桌面也跟着
            .fullScreenAuxiliary,      // 全屏 App 上也显示
            .stationary                // 不参与 Mission Control 动画
        ]

        // ---- ✨ 核心：从屏幕录制中排除 ----
        // sharingType = .none → ScreenCaptureKit 采集时自动跳过这个窗口
        // 这就是 vlogger 第一刚需的实现
        if #available(macOS 13.0, *) {
            window.sharingType = .none
        }

        // ---- 圆角窗口 ----
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 16
        window.contentView?.layer?.masksToBounds = true

        floatingTeleprompterWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    func hideFloatingTeleprompter() {
        floatingTeleprompterWindow?.orderOut(nil)
    }

    func closeFloatingTeleprompter() {
        floatingTeleprompterWindow?.close()
        floatingTeleprompterWindow = nil
    }

    // MARK: - 切换 sharingType（设置里有"对相机隐形"开关）

    /// 把所有浮动窗口的"对相机隐形"功能临时关闭/打开
    /// 用户可能想让 demo 录屏时能看到提词器位置
    func setExcludedFromCapture(_ excluded: Bool) {
        if #available(macOS 13.0, *) {
            floatingTeleprompterWindow?.sharingType = excluded ? .none : .readWrite
        }
    }
}

// MARK: - 自定义浮动窗口子类
//
// 必须 override `canBecomeKey` 才能接收键盘事件（Space 暂停等）
// 否则 borderless 窗口默认不能获得焦点

final class TransparentFloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
