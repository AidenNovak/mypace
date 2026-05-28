//
//  DashboardView.swift
//  MyPace
//
//  首页 —— 对应 tahoe.html 的 #v1 部分。
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    let scripts: [Script]
    let onOpenScript: (Script) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ---- 顶部问候 + 搜索 ----
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.pmCaption)
                            .foregroundStyle(.secondary)
                        Text("准备录什么？")
                            .font(.pmDisplayL)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    SearchField(text: $searchText)
                        .frame(maxWidth: 240)
                }

                // ---- 快速动作行 ----
                HStack(alignment: .top, spacing: 14) {
                    QuickHeroCard(onNew: createNewScript)
                        .layoutPriority(2)

                    VStack(spacing: 10) {
                        ContinueCard()
                        ImportCard()
                    }
                    .layoutPriority(1)
                }

                // ---- 最近脚本 ----
                HStack {
                    Text("最近脚本")
                        .font(.pmHeading)
                    Spacer()
                    Button("全部 \(scripts.count) 个  →") {}
                        .buttonStyle(.textBlue)
                }
                .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(scripts) { script in
                        ScriptCard(script: script)
                            .onTapGesture { onOpenScript(script) }
                    }
                }

                if scripts.isEmpty {
                    EmptyStateView(onCreate: createNewScript)
                        .padding(.vertical, 24)
                }

                // ---- 状态条 ----
                StatusFooter()
                    .padding(.top, 8)
            }
            .padding(32)
        }
        .background(Color.bgPrimary)
    }

    // MARK: - Actions

    private func createNewScript() {
        let new = Script(title: "未命名脚本")
        modelContext.insert(new)
        try? modelContext.save()
        onOpenScript(new)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "早上好"
        case 12..<14: return "中午好"
        case 14..<18: return "下午好"
        default:      return "晚上好"
        }
    }
}

// MARK: - 搜索框（macOS 风格）

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField("搜索脚本", text: $text)
                .textFieldStyle(.plain)
                .font(.pmBody)
            Text("⌘K")
                .font(.pmMonoSmall)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(Color.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - 大黑卡 · 新建提词器

struct QuickHeroCard: View {
    let onNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.appOrange)
                    .frame(width: 6, height: 6)
                    .shadow(color: .appOrange, radius: 4)
                Text("新建提词器")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            Spacer().frame(height: 8)
            Text("开始一段\n新的稿子")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .lineSpacing(2)
            Text("从空白稿纸开始，让 MyPace 帮你记住自己的节奏。")
                .font(.pmBody)
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: 300, alignment: .leading)
                .padding(.top, 6)
            HStack(spacing: 8) {
                Button(action: onNew) {
                    HStack(spacing: 6) {
                        Text("新建脚本")
                        Text("⌘ N")
                            .font(.pmMonoSmall)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .buttonStyle(.orangeCTA)

                Button("从模板") {}
                    .buttonStyle(.pill)
                    .colorScheme(.dark)
            }
            .padding(.top, 14)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1a1a1c), Color(hex: 0x0F0F11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .topTrailing) {
            // 右上角橙色光晕
            Circle()
                .fill(Color.appOrange)
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .opacity(0.4)
                .offset(x: 40, y: -40)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
    }
}

// MARK: - 继续上次

struct ContinueCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appBlue.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("继续上次")
                    .font(.pmBodyBold)
                Text("品牌发布会开场 · 待生成节奏")
                    .font(.pmCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("62%")
                .font(.pmMono)
                .foregroundStyle(Color.appBlue)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSolid)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 导入文本

struct ImportCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appOrange.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appOrangeDeep)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("导入文本")
                    .font(.pmBodyBold)
                Text("支持 .txt / .md / .docx")
                    .font(.pmCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("→")
                .font(.pmBody)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSolid)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 脚本卡片

struct ScriptCard: View {
    let script: Script

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(script.title)
                    .font(.pmBodyBold)
                    .lineLimit(2)
                Spacer()
                StatusBadge(status: script.status)
            }
            .padding(.bottom, 10)

            Text(script.content.prefix(60).appending(script.content.count > 60 ? "..." : ""))
                .font(.pmCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(height: 54, alignment: .topLeading)

            Divider()
                .padding(.vertical, 10)

            HStack(spacing: 14) {
                Label("\(script.wordCount) 字", systemImage: "")
                    .font(.pmMonoSmall)
                    .labelStyle(.titleOnly)
                if let dur = script.estimatedDuration {
                    Text(formatDuration(dur))
                        .font(.pmMonoSmall)
                }
                Text("\(script.recordings.count) 次")
                    .font(.pmMonoSmall)
                Spacer()
            }
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSolid)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        let m = Int(d) / 60
        let s = Int(d) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct StatusBadge: View {
    let status: ScriptStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(status.label)
                .font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .draft:    Color.textSecondary
        case .recorded: Color.appBlue
        case .mapped:   Color(hex: 0x0E7531)
        }
    }
}

// MARK: - 状态条

struct StatusFooter: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.appGreen)
                .frame(width: 7, height: 7)
                .shadow(color: .appGreen, radius: 3)
            Text("火山引擎已连接")
            Text("·").foregroundStyle(.tertiary)
            Text("本月剩余 4h 32m")
            Text("·").foregroundStyle(.tertiary)
            Text("平均延迟 187ms")
            Spacer()
            Text("MyPace 1.0 · 健康")
                .foregroundStyle(.secondary)
        }
        .font(.pmMono)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("还没有脚本")
                .font(.pmDisplayS)
            Text("点击「新建脚本」开始你的第一段稿子")
                .font(.pmBody)
                .foregroundStyle(.secondary)
            Button("新建脚本") { onCreate() }
                .buttonStyle(.orangeCTA)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
