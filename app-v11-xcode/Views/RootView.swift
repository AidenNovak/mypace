//
//  RootView.swift
//  MyPace
//
//  根视图 —— 决定显示 Dashboard 还是 Script Editor。
//  用 NavigationSplitView 实现 macOS 标准三栏布局（侧栏 + 列表 + 详情）。
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Script.updatedAt, order: .reverse) private var scripts: [Script]

    @State private var selectedSidebar: SidebarItem? = .home
    @State private var selectedScript: Script?

    var body: some View {
        NavigationSplitView {
            // ---- 侧栏 ----
            SidebarView(selection: $selectedSidebar, scriptCount: scripts.count)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            // ---- 内容区 ----
            Group {
                switch selectedSidebar {
                case .home, .none:
                    DashboardView(
                        scripts: scripts,
                        onOpenScript: { script in
                            selectedScript = script
                        }
                    )
                case .allScripts:
                    Text("脚本列表 · 待实现")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.bgPrimary)
                case .templates:
                    Text("模板库 · 待实现")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.bgPrimary)
                case .history:
                    Text("录制历史 · 待实现")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.bgPrimary)
                }
            }
            .sheet(item: $selectedScript) { script in
                ScriptEditorView(script: script)
                    .frame(minWidth: 980, minHeight: 680)
            }
        }
        // 监听全局快捷键
        .onReceive(NotificationCenter.default.publisher(for: .createNewScript)) { _ in
            createNewScript()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFloatingTeleprompter)) { _ in
            showFloatingTeleprompter()
        }
    }

    // MARK: - Actions

    private func createNewScript() {
        let new = Script(title: "未命名脚本")
        modelContext.insert(new)
        try? modelContext.save()
        selectedScript = new
    }

    private func showFloatingTeleprompter() {
        guard let script = selectedScript ?? scripts.first else { return }
        WindowManager.shared.showFloatingTeleprompter {
            FloatingTeleprompterView(script: script)
        }
    }
}

// MARK: - Sidebar

enum SidebarItem: String, Hashable, CaseIterable {
    case home
    case allScripts
    case templates
    case history

    var label: String {
        switch self {
        case .home:       "首页"
        case .allScripts: "全部脚本"
        case .templates:  "模板"
        case .history:    "录制历史"
        }
    }

    var systemImage: String {
        switch self {
        case .home:       "house"
        case .allScripts: "doc.text"
        case .templates:  "square.grid.2x2"
        case .history:    "clock"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let scriptCount: Int

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(SidebarItem.allCases, id: \.self) { item in
                    Label(item.label, systemImage: item.systemImage)
                        .tag(item)
                        .badge(item == .allScripts ? scriptCount : 0)
                }
            }

            Section("标签") {
                Label("口播视频", systemImage: "circle.fill")
                    .foregroundStyle(.primary)
                    .labelStyle(TagLabelStyle(color: .appBlue))
                Label("知识科普", systemImage: "circle.fill")
                    .labelStyle(TagLabelStyle(color: .appOrange))
                Label("短带货", systemImage: "circle.fill")
                    .labelStyle(TagLabelStyle(color: .appGreen))
            }
        }
        .listStyle(.sidebar)
    }
}

struct TagLabelStyle: LabelStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .foregroundStyle(color)
                .font(.system(size: 8))
            configuration.title
        }
    }
}
