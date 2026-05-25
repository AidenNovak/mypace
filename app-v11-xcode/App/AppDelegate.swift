//
//  AppDelegate.swift
//  MyPace
//
//  接管 NSApplication 生命周期。
//  SwiftUI 没有覆盖到的低层 Cocoa 行为（Dock、菜单、激活策略等）放这里。
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 让主窗口能被键盘聚焦（默认有时不行）
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    /// 关闭最后一个窗口时不退出（用户可能只是在用浮动提词器）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 点击 Dock 图标时如果没窗口，自动开主窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 让 SwiftUI WindowGroup 重新打开主窗口
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}
