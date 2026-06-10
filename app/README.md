# MyPace · v0.8 Preview（AppKit 版）

> 一台能听懂你节奏的 macOS 提词器。专为 vlogger 设计。

这是当前**真正可运行**的版本，包含完整的节奏回放引擎、逐字高亮和口述模式。

**构建方式**：纯 `swiftc` + shell，不需要 Xcode。

---

## 目录结构

```
app/
├── Preview/           核心源码（13 个 .swift 文件）
│   ├── MyPacePreview.swift   主程序（AppKit + CoreAnimation）
│   ├── RhythmPlayback.swift  30Hz 节奏回放引擎（核心）
│   ├── WordRunView.swift     逐字 CATextLayer 高亮动画（无抖动）
│   ├── Recording.swift       AVAudioEngine 录音
│   ├── ASR.swift             火山引擎 ASR（支持字级时间戳）
│   └── ...
├── Resources/         AppIcon.icns 等资源
├── build-app.sh       一键构建 .app + .dmg
├── gen_icon.swift     生成圆角 App 图标
├── README.md          本文件
├── ROADMAP.md         路线图
└── UPDATES.md         版本历史
```

---

## 快速开始

```bash
cd app
./build-app.sh
open "build/MyPace Preview.app"
```

构建产物：
- `build/MyPace Preview.app`
- `build/MyPace-Preview-0.8.0.dmg`

---

## 为什么是这个架构？

- **AppKit + Core Animation**：对 30Hz 节奏同步 + 逐字缩放动画需要极致控制，SwiftUI 当前难以达到同等无抖动效果。
- **纯 swiftc 构建**：开发迭代极快，不依赖重型 Xcode 环境。
- **已验证核心价值**：RhythmPlayback 引擎、WordRunView 逐字跟读、口述模式（空脚本自动 ASR 回填）全部可用。

（历史：曾尝试用 SwiftUI + Xcode 工程重写，因核心引擎实现缺失，已放弃并清理。）

---

## 相关文档

- 根目录 `README.md` — 仓库整体说明 + 发版策略
- `app/ROADMAP.md` — 当前开发路线
- `app/UPDATES.md` — 详细变更记录
- `verify/` — 核心技术验证脚本（字级 ASR、播放精度等）

---

## 注意

- 目前使用 ad-hoc 签名，正式分发前需要 Apple Developer ID 证书做 hardened runtime + notarize。
- 凭证：火山引擎 ASR 需要在 Keychain 或本地配置（见 `Preview/ASR.swift`）。
- 数据存储在 `~/Library/Application Support/MyPacePreview/`。
