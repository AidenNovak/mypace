//
//  SettingsView.swift
//  MyPace
//
//  偏好设置 —— 对应 tahoe.html 的 #v7 部分。
//  macOS System Settings 同款风格：左 sidebar + 右 inset 卡片分组。
//

import SwiftUI

struct SettingsView: View {
    @State private var selected: SettingsTab = .asr

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                Section("常用") {
                    ForEach([SettingsTab.asr, .appearance, .shortcuts], id: \.self) { tab in
                        Label(tab.label, systemImage: tab.icon).tag(tab)
                    }
                }
                Section("数据") {
                    Label(SettingsTab.privacy.label, systemImage: SettingsTab.privacy.icon)
                        .tag(SettingsTab.privacy)
                    Label(SettingsTab.importExport.label, systemImage: SettingsTab.importExport.icon)
                        .tag(SettingsTab.importExport)
                }
                Section("系统") {
                    Label(SettingsTab.advanced.label, systemImage: SettingsTab.advanced.icon)
                        .tag(SettingsTab.advanced)
                    Label(SettingsTab.about.label, systemImage: SettingsTab.about.icon)
                        .tag(SettingsTab.about)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ScrollView {
                Group {
                    switch selected {
                    case .asr:           ASRSettingsPanel()
                    case .appearance:    SettingsPlaceholder(title: "外观与字体")
                    case .shortcuts:     SettingsPlaceholder(title: "快捷键")
                    case .privacy:       SettingsPlaceholder(title: "隐私与保留")
                    case .importExport:  SettingsPlaceholder(title: "导入 / 导出")
                    case .advanced:      SettingsPlaceholder(title: "高级参数")
                    case .about:         AboutPanel()
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color.bgPrimary)
        }
    }
}

enum SettingsTab: String, Hashable {
    case asr, appearance, shortcuts
    case privacy, importExport
    case advanced, about

    var label: String {
        switch self {
        case .asr:          "ASR 提供商"
        case .appearance:   "外观与字体"
        case .shortcuts:    "快捷键"
        case .privacy:      "隐私与保留"
        case .importExport: "导入 / 导出"
        case .advanced:     "高级参数"
        case .about:        "关于 MyPace"
        }
    }

    var icon: String {
        switch self {
        case .asr:          "waveform.badge.mic"
        case .appearance:   "paintbrush"
        case .shortcuts:    "keyboard"
        case .privacy:      "lock.shield"
        case .importExport: "square.and.arrow.up.on.square"
        case .advanced:     "slider.horizontal.3"
        case .about:        "info.circle"
        }
    }
}

// MARK: - ASR Panel（主要内容）

struct ASRSettingsPanel: View {
    @State private var hasCredentials = KeychainService.loadVolcengineCredentials() != nil
    @State private var showImportSheet = false
    @State private var showManualSheet = false
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var retentionPolicy: RetentionPolicy = .sevenDays

    enum RetentionPolicy: String, CaseIterable {
        case delete = "对齐后立即删除"
        case sevenDays = "保留 7 天（推荐）"
        case forever = "永久保留"

        var desc: String {
            switch self {
            case .delete:    "最隐私 · 但无法重新对齐"
            case .sevenDays: "可随时重新对齐节奏"
            case .forever:   "手动清理 · 占用本机空间"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("语音识别").font(.pmDisplayM)
            Text("MyPace 用 **火山引擎** 把你的练习录音对齐成精确到字的节奏映射。原始音频默认**只在本机暂存**，对齐完成后按你的策略自动删除。")
                .font(.pmBody)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 640, alignment: .leading)

            // ---- 火山引擎卡片 ----
            VolcengineProviderCard(
                hasCredentials: hasCredentials,
                testResult: testResult,
                isTesting: isTesting,
                onTest: testConnection
            )

            // ---- 隐私 tip ----
            PrivacyTipCard()

            // ---- 闪电说导入 ----
            ShandianshuoImportCard(
                isInstalled: KeychainService.isShandianshuoInstalled(),
                lastImportedDaysAgo: 24,
                onImport: importFromShandianshuo
            )

            // ---- 保留策略 ----
            VStack(alignment: .leading, spacing: 8) {
                Text("练习音频保留策略")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.leading, 12)

                VStack(spacing: 0) {
                    ForEach(Array(RetentionPolicy.allCases.enumerated()), id: \.offset) { i, p in
                        retentionRow(p)
                        if i < RetentionPolicy.allCases.count - 1 {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .background(Color.surfaceSolid)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.separator, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // ---- 危险操作 ----
            Button {
                // TODO: 实际清空音频文件
            } label: {
                Label("清除所有练习音频（12 个 · 287 MB）", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(Color.appRed)
            .controlSize(.large)
        }
        .frame(maxWidth: 720, alignment: .topLeading)
        .sheet(isPresented: $showManualSheet) {
            ManualCredentialEntrySheet(onSaved: {
                hasCredentials = KeychainService.loadVolcengineCredentials() != nil
            })
        }
    }

    private func retentionRow(_ p: RetentionPolicy) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.rawValue).font(.pmBody)
                Text(p.desc).font(.pmCaption).foregroundStyle(.tertiary)
            }
            Spacer()
            ZStack {
                Circle()
                    .strokeBorder(retentionPolicy == p ? Color.appBlue : Color.lineStrong,
                                  lineWidth: retentionPolicy == p ? 6 : 1.5)
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { retentionPolicy = p }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            guard let cred = KeychainService.loadVolcengineCredentials() else {
                testResult = "未配置凭证"
                isTesting = false
                return
            }
            // 真实测试可以发一个 ping request 给火山
            // 这里先 mock 一下延迟
            try? await Task.sleep(for: .milliseconds(600))
            testResult = "✓ 连接正常 · 延迟 187 ms"
            isTesting = false
        }
    }

    private func importFromShandianshuo() {
        if let _ = KeychainService.importFromShandianshuo() {
            hasCredentials = true
        }
    }
}

// MARK: - 火山引擎卡片

struct VolcengineProviderCard: View {
    let hasCredentials: Bool
    let testResult: String?
    let isTesting: Bool
    let onTest: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左侧：介绍 + 指标
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    badge("推荐", color: Color.appOrange, white: true)
                    badge("已连接", color: Color.appGreen.opacity(0.18), textColor: Color(hex: 0x0E7531), withDot: true)
                    badge("VOLCENGINE · v3 · STREAMING", color: Color.black.opacity(0.06), textColor: .secondary)
                }
                Text("火山引擎")
                    .font(.system(size: 28, weight: .bold))
                Text("中文识别精度业内领先 · 平均延迟 200ms 以内")
                    .font(.pmMono)
                    .foregroundStyle(Color.appOrangeDeep)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text("MyPace 选了云端方案，因为**精确到字的时间戳对齐**对节奏映射至关重要。凭证由闪电说托管，调用时通过系统 Keychain 读取，本机不复制不外传。")
                    .font(.pmBody)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 380, alignment: .leading)

                // 3 个大指标
                HStack(spacing: 18) {
                    statBlock(num: "96.4", suffix: "%", label: "中文准确率")
                    statBlock(num: "187", suffix: "ms", label: "实测平均延迟")
                    statBlock(num: "4h 32", suffix: "m", label: "本月剩余配额")
                }
                .padding(.top, 8)
                .overlay(Divider(), alignment: .top)
                .padding(.top, 0)
            }
            .padding(22)

            // 右侧：实时状态
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Circle().fill(Color.appGreen).frame(width: 10, height: 10).modifier(PulsingModifier())
                        .shadow(color: .appGreen, radius: 4)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("服务正常").font(.pmBodyBold)
                        Text("最近测试 · 4h 前").font(.pmMonoSmall).foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom, 10)
                .overlay(Divider(), alignment: .bottom)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("本月用量").font(.pmMono).foregroundStyle(.secondary)
                        Spacer()
                        Text("35%").font(.pmMono).foregroundStyle(Color.appOrangeDeep).fontWeight(.semibold)
                    }
                    ProgressView(value: 0.35)
                        .progressViewStyle(.linear)
                        .tint(LinearGradient.orangeSubtle)
                    Text("已用 2h 28m / 总配额 7h")
                        .font(.pmMonoSmall)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Button(action: onTest) {
                        HStack {
                            if isTesting {
                                ProgressView().controlSize(.small).tint(Color.appGreen)
                            } else {
                                Circle().fill(Color.appGreen).frame(width: 7, height: 7)
                            }
                            Text(isTesting ? "测试中..." : "测试连接")
                        }
                    }
                    .buttonStyle(.pill)

                    if let res = testResult {
                        Text(res).font(.pmCaption).foregroundStyle(Color.appGreen)
                    }
                    Button("查看详细用量 →") {}
                        .buttonStyle(.textBlue)
                }
            }
            .padding(22)
            .frame(width: 220, alignment: .topLeading)
            .background(Color.bgPrimary)
            .overlay(Divider(), alignment: .leading)
        }
        .background(
            LinearGradient(colors: [Color(hex: 0xFFF6E6), Color(hex: 0xFFFCF5)],
                           startPoint: .top, endPoint: .bottom)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.appOrange, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .appOrangeGlow, radius: 16, y: 8)
    }

    private func badge(_ text: String, color: Color, textColor: Color = .white, white: Bool = false, withDot: Bool = false) -> some View {
        HStack(spacing: 5) {
            if withDot { Circle().fill(Color.appGreen).frame(width: 6, height: 6) }
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(white ? .white : textColor)
                .tracking(0.6)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color, in: RoundedRectangle(cornerRadius: 5))
    }

    private func statBlock(num: String, suffix: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(num).font(.system(size: 26, weight: .bold))
                Text(suffix).font(.pmBody).foregroundStyle(.tertiary)
            }
            Text(label)
                .font(.pmMonoSmall)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
    }
}

// MARK: - 隐私 tip

struct PrivacyTipCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFCC4D), Color(hex: 0xFF9500)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Text("!").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("关于隐私：音频会上传到火山引擎").font(.pmBodyBold)
                Text("每次练习前会弹窗提示。音频在传输和存储过程中加密，对齐完成后按你的保留策略自动删除（默认 7 天）。")
                    .font(.pmCaption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("隐私策略 →") {}.buttonStyle(.textBlue)
        }
        .padding(14)
        .background(Color.appYellow.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.appYellow.opacity(0.25), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 闪电说导入

struct ShandianshuoImportCard: View {
    let isInstalled: Bool
    let lastImportedDaysAgo: Int?
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient.orangeSubtle)
                    .frame(width: 40, height: 40)
                Text("闪").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("从「闪电说」一键导入凭证").font(.pmBodyBold)
                if isInstalled, let days = lastImportedDaysAgo {
                    Text("检测到本机已安装闪电说 · 已成功导入 · **\(days) 天前**")
                        .font(.pmCaption).foregroundStyle(.secondary)
                } else if isInstalled {
                    Text("检测到本机已安装闪电说 · 点击导入")
                        .font(.pmCaption).foregroundStyle(.secondary)
                } else {
                    Text("未检测到闪电说 · [安装闪电说 →](https://shandianshuo.app)")
                        .font(.pmCaption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(isInstalled ? "重新导入" : "手动输入", action: onImport)
                .buttonStyle(.pill)
                .disabled(false)
        }
        .padding(14)
        .background(Color.surfaceSolid)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.separator, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 手动输入凭证 sheet

struct ManualCredentialEntrySheet: View {
    let onSaved: () -> Void
    @State private var appID = ""
    @State private var accessToken = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("手动输入火山引擎凭证").font(.pmHeading)
            Text("如果没安装闪电说，可以在这里直接输入。")
                .font(.pmCaption).foregroundStyle(.secondary)

            TextField("App ID", text: $appID)
                .textFieldStyle(.roundedBorder)
            SecureField("Access Token", text: $accessToken)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(.pill)
                Button("保存") {
                    try? KeychainService.saveVolcengineCredentials(appID: appID, accessToken: accessToken)
                    onSaved()
                    dismiss()
                }
                .buttonStyle(.orangeCTA)
                .disabled(appID.isEmpty || accessToken.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 420)
    }
}

// MARK: - 其他面板占位

struct SettingsPlaceholder: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.pmDisplayM)
            Text("该面板将在后续阶段实现。")
                .font(.pmBody).foregroundStyle(.secondary)
        }
    }
}

struct AboutPanel: View {
    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient.orangeSubtle)
                    .frame(width: 96, height: 96)
                Text("M").font(.system(size: 56, weight: .bold)).foregroundStyle(.white)
            }
            Text("MyPace").font(.pmDisplayL)
            Text("Version 1.0.0 (build 1)")
                .font(.pmMono).foregroundStyle(.secondary)
            Text("一台能听懂你节奏的提词器。")
                .font(.pmBody).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
