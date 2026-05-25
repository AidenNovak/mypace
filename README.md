# MyPace · Monorepo

> An invisible teleprompter for vloggers on macOS.
> 为视频创作者打造的隐形提词器。

[![status](https://img.shields.io/badge/status-v0.8%20preview-orange)]() [![platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)]() [![build](https://img.shields.io/badge/build-swiftc%20%2B%20shell-lightgrey)]()

---

## 一句话

录音先行 → AI 把你的话整理成带节奏的稿件 → 按你的节奏跟读 → 录视频时**画面里看不到这个窗口**。

---

## 仓库结构

```
mypace/
├── app/                v0.8 当前在用的 app 源码（swiftc + shell 构建，不需要 Xcode）
│   ├── Preview/          13 个 Swift 文件（核心实现）
│   ├── Resources/        AppIcon.icns 等
│   ├── build-app.sh      一键打包脚本 → 输出 .app + .dmg
│   ├── gen_icon.swift    生成 macOS 圆角图标的脚本
│   ├── README.md         开发者文档
│   ├── ROADMAP.md        路线图
│   ├── UPDATES.md        版本历史
│   └── VLOGGER-README.md vlogger 安装指南（DMG 内附）
│
├── app-v11-xcode/      v1.1 Xcode 工程骨架（沙盒 + App Store 准备，未启用）
│   ├── App/ Models/ Services/ Theme/ Views/
│   ├── MyPace.entitlements
│   └── project.yml       XcodeGen 配置
│
├── site/               文档站（Cloudflare Pages 部署根目录）
│   ├── index.html        macOS Tahoe 风 + 三语 marketing landing
│   ├── shots/            7 张精致 v0.8 截图
│   ├── archive-design-*  v1 / tahoe 旧设计稿（归档）
│   └── MyPace-Preview-0.8.0.dmg  可下载安装包
│
├── docs/               PRD / 技术规格 / UI/UX 基础（早期设计文档）
│   ├── prd.md
│   ├── technical-spec.md
│   ├── ui-ux-foundation.md
│   └── PRD-README.md
│
├── verify/             单文件 POC（验证核心技术）
│   ├── verify_spike.swift          ScreenCaptureKit 隐形窗口
│   ├── verify_rec.swift            AVAudioRecorder 录音
│   ├── verify_asr.swift            火山引擎 ASR 调用
│   ├── verify_asr_words.swift      字级时间戳
│   ├── verify_word_playback.swift  字级动效回放
│   └── verify_control.swift        UI 控件实验
│
├── .gitignore          排除 build / DMG / 旧二进制 / 凭证
└── README.md           （本文件）
```

---

## 快速开始

### 跑当前 v0.8 (Preview 版)

```bash
cd app
./build-app.sh
open "build/MyPace Preview.app"
```

需要：

- macOS 14+ 编译，13+ 运行
- Xcode Command Line Tools（`xcode-select --install`）
- 火山引擎 ASR 凭证（在 `Preview/ASR.swift` 里读 keychain）

### 本地预览文档站

```bash
cd site
python3 -m http.server 8765
open http://localhost:8765/
```

### 编译验证脚本

```bash
cd verify
swiftc verify_spike.swift -o verify_spike && ./verify_spike
```

---

## 当前状态（v0.8 · 2026-05）

- ✅ 录音先行的口述工作流
- ✅ 火山引擎 ASR + 字级时间戳
- ✅ ScreenCaptureKit `sharingType = .none`（录屏看不到）
- ✅ 字级跟读动效（CATextLayer per char，无抖动）
- ✅ 中 / 英 / 日 i18n（自动跟随系统 + 手动切换）
- ✅ 窗口可拖拽 resize
- ✅ 文档站（macOS Tahoe 风 + 真实截图 + 三语）
- ⏸ Apple Developer ID 签名 + Notarization（待证书）
- ⏸ App Store 上架（需要 v1.1 Xcode 工程）

---

## 发版路径

详见 `app/ROADMAP.md`。两条 track：

1. **Track A · 公测分发**（自托管 DMG，5 天内）：注册 Apple Developer → notarize → 部署 Cloudflare Pages
2. **Track B · App Store 上架**（3–4 周）：装 Xcode → 工程化 `app-v11-xcode/` → 沙盒兼容 → 提交审核

---

## 技术栈

| 层 | 选型 |
|---|---|
| UI | Swift + AppKit + CoreAnimation（不用 SwiftUI，保留 v1.1 备选） |
| 录音 | `AVAudioRecorder`（16 kHz mono WAV）|
| ASR | 火山引擎 v3（big-model + `show_words` + `enable_word_time_offset`） |
| 字级渲染 | `CATextLayer` per character |
| 隐形录屏 | `NSWindow.sharingType = .none`（ScreenCaptureKit 排除）|
| 持久化 | JSON（在 `~/Library/Application Support/MyPacePreview/`）|
| i18n | 纯 Swift 字典（`Preview/L10n.swift`），无 `.strings` 文件依赖 |
| 构建 | `xcrun swiftc` + `codesign --options runtime` + `hdiutil` |

---

## 隐私

- 录音音频会上传到**火山引擎**做 ASR，每次都有进度条提示
- 稿件 JSON、生成的节奏映射、录音 WAV 都**只存你 mac 本地**：`~/Library/Application Support/MyPacePreview/`
- 不上云，不埋点，不上报崩溃
- 想清干净一句 `rm -rf ~/Library/Application\ Support/MyPacePreview/`

---

## 协作 & 许可

- 维护者: [@AidenNovak](https://github.com/AidenNovak)
- 当前是 **private** 仓库，未公开
- 许可协议：待定（计划 v1.0 上架时定为 MIT 或商业付费）
