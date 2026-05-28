# MyPace · SwiftUI MVP

> 一台能听懂你节奏的 macOS 提词器。专为 vlogger 设计。

这是 MyPace 的真实可编译 SwiftUI 工程骨架。HTML 设计稿 → 真实可装的 Mac App 的第一步。

---

## 当前包含

### ✅ MVP 第一阶段 · 已实现

| 模块 | 文件 | 说明 |
|---|---|---|
| App 入口 | `Sources/App/MyPaceApp.swift` | SwiftUI Scene + 多窗口管理 |
| AppDelegate | `Sources/App/AppDelegate.swift` | macOS 生命周期 + 全局快捷键 |
| 数据模型 | `Sources/Models/*.swift` | SwiftData：脚本 / 录音 / 节奏映射 |
| 主题系统 | `Sources/Theme/*.swift` | 对应 HTML 设计稿的 Liquid Glass 色彩与字体 |
| **窗口管理** | `Sources/Services/WindowManager.swift` | **ScreenCaptureKit 排除浮动窗口** —— vlogger 核心刚需 |
| 首页 | `Sources/Views/DashboardView.swift` | 三栏布局 + 玻璃 sidebar + 脚本列表 |
| 编辑器 | `Sources/Views/ScriptEditorView.swift` | 稿纸 + Inspector 抽屉 + 底部 CTA |
| 浮动提词器 | `Sources/Views/FloatingTeleprompterView.swift` | 半透深色玻璃浮窗 |

### ⏳ MVP 第二阶段 · 待实现（路线见 ROADMAP.md）

- `RecordingService.swift` —— AVAudioEngine 录音
- `ASRService.swift` —— 火山引擎 API 调用
- `KeychainService.swift` —— 闪电说凭证读取
- `PracticeRecordingView.swift` —— 练习录音 view
- `RhythmEditorView.swift` —— 节奏编辑器 view
- `SettingsView.swift` —— 偏好设置 view

---

## 如何开始

### 方案 A · Xcode 新建工程（推荐零基础）

1. 打开 **Xcode 16+**
2. **File → New → Project → macOS → App**
3. 配置：
   - Product Name: `MyPace`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData**
4. 把本目录的 `Sources/` 下所有 `.swift` 文件**拖进 Xcode** 工程
5. **Project Settings → Target → Signing & Capabilities** 添加：
   - **Screen Recording**（System Events 用，配 ScreenCaptureKit）
   - **Microphone**（录音用）
6. ⌘R 启动

### 方案 B · 用 XcodeGen 一键生成（推荐有经验的开发者）

```bash
brew install xcodegen
cd ~/MyPace-Swift
xcodegen generate   # 生成 MyPace.xcodeproj
open MyPace.xcodeproj
```

`project.yml` 已经配好，1 个命令搞定。

---

## 系统要求

- **macOS 14 Sonoma+**（用了 SwiftData、最新 ScreenCaptureKit API）
- **Xcode 16+**
- Apple Silicon 或 Intel Mac 都可

---

## 学习资料速通

| 投入 | 资源 |
|---|---|
| 半天 | [Apple 官方 Tutorial](https://developer.apple.com/tutorials/swiftui) —— 苹果亲自做的交互式入门 |
| 3 个月扎实 | [Hacking with Swift · 100 Days](https://www.hackingwithswift.com/100/swiftui) —— Paul Hudson，业内天花板 |
| 中文 | [onevcat 博客](https://onevcat.com/categories/Swift/) + [戴铭 SwiftPamphletApp](https://github.com/KwaiAppTeam/SwiftPamphletApp) |
| 公开课 | [Stanford CS193p](https://cs193p.sites.stanford.edu/) |

---

## 读代码顺序建议

1. `Sources/App/MyPaceApp.swift` —— 看 SwiftUI App 怎么搭骨架
2. `Sources/Models/Script.swift` —— 看 SwiftData @Model 怎么定义数据
3. `Sources/Theme/Tokens.swift` —— 看 HTML 设计稿的色彩怎么搬到 Swift
4. `Sources/Views/DashboardView.swift` —— 看 SwiftUI 怎么写布局
5. `Sources/Services/WindowManager.swift` —— **重点**，ScreenCaptureKit 排除窗口的关键代码
6. `Sources/Views/FloatingTeleprompterView.swift` —— 浮动窗口 view

---

## 关键架构决策

| 决策 | 选择 | 理由 |
|---|---|---|
| UI 框架 | **SwiftUI**（不用 AppKit） | 代码量少 2-3 倍，新项目首选 |
| 数据 | **SwiftData**（不用 Core Data） | iOS 17+ 新方案，更现代 |
| 异步 | **async/await** | 不用 Combine，更易读 |
| 窗口 | **NSWindow 包装**（不用 SwiftUI 原生 Scene） | 浮动提词器需要精细控制 always-on-top + 拖拽 |
| 录音 | **AVAudioEngine**（不用 AVAudioRecorder） | 实时波形 + 节奏标记需要 buffer 级访问 |
| ASR | 抽象 `ASRProvider` 协议 | v1 用火山，v2 可加本地 SenseVoice |

---

## 下一步

读 `ROADMAP.md` 看完整的开发计划与里程碑。
