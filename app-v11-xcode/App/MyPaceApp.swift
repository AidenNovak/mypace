//
//  MyPaceApp.swift
//  MyPace
//
//  App 入口。
//

import SwiftUI
import SwiftData

@main
struct MyPaceApp: App {

    // SwiftData 容器：自动持久化 Script / Recording / RhythmSegment
    let modelContainer: ModelContainer = {
        let schema = Schema([Script.self, Recording.self, RhythmSegment.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建 SwiftData 容器：\(error)")
        }
    }()

    // 接管 NSApplication 生命周期（处理全局快捷键 / Dock 等）
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // ---- 主窗口：Dashboard / Editor / Settings 在这里切 ----
        WindowGroup("MyPace") {
            RootView()
                .frame(minWidth: 980, minHeight: 680)
        }
        .modelContainer(modelContainer)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            // 标准 macOS 菜单 + 自定义快捷键
            CommandGroup(replacing: .newItem) {
                Button("新建脚本") {
                    NotificationCenter.default.post(name: .createNewScript, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("开始练习录音") {
                    NotificationCenter.default.post(name: .startPracticeRecording, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            CommandGroup(after: .windowList) {
                Button("显示浮动提词器") {
                    NotificationCenter.default.post(name: .showFloatingTeleprompter, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .option])
            }
        }

        // ---- 偏好设置窗口（⌘,）—— macOS 标准 ----
        Settings {
            SettingsView()
                .frame(minWidth: 720, minHeight: 520)
                .modelContainer(modelContainer)
        }
    }
}

// MARK: - 全局通知名

extension Notification.Name {
    static let createNewScript          = Notification.Name("createNewScript")
    static let startPracticeRecording   = Notification.Name("startPracticeRecording")
    static let showFloatingTeleprompter = Notification.Name("showFloatingTeleprompter")
}

// SettingsView 已抽到 Views/SettingsView.swift
