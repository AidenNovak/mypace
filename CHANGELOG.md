# MyPace · Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/).

---

## [Unreleased]

### Planned — v1.1 App Store
- [ ] 安装 Xcode + `xcodegen generate` 验证 v1.1 工程
- [ ] 注册 Apple Developer Program ($99/年)
- [ ] App 图标设计（macOS 标准多尺寸）
- [ ] App Store Connect 配置 + 截图
- [ ] PrivacyInfo.xcprivacy 隐私清单
- [ ] StoreKit 2 内购（¥128 一次性购买）
- [ ] 沙盒权限申明（Microphone / Screen Recording / File Access）
- [ ] Notarization + 提交审核

### Planned — v1.1 功能
- [ ] 全局快捷键（⌘N、⇧⌘R、Space 暂停）
- [ ] 浮动窗口拖拽 + 大小记忆
- [ ] 节奏同步滚动算法（按时间戳推进高亮）
- [ ] 错误处理：网络失败 / ASR 超时 / 权限被拒
- [ ] 首次启动 3 步 onboarding

---

## [0.8.0] — 2026-05-26

### Monorepo 重构
- 合并为 `mypace/` monorepo，统一管理 app / site / docs / verify
- 新增 `app-v11-xcode/` — SwiftUI + SwiftData Xcode 工程骨架（未编译）
- Cloudflare Pages 部署文档站：https://mypace-aaz.pages.dev/
- GitHub Actions 自动部署 `site/**` 变更

### 核心功能（v0.8 Preview，AppKit 架构）
- 录音先行口述工作流（AVAudioRecorder → 16kHz mono WAV）
- 火山引擎 ASR v3（big-model + 字级时间戳 `show_words` + `enable_word_time_offset`）
- ScreenCaptureKit `sharingType = .none` — 录屏时浮动窗口不可见
- 字级跟读动效（CATextLayer per char，60fps 无抖动）
- 中 / 英 / 日 i18n（自动跟随系统 + 手动切换）
- 窗口可拖拽 resize
- 闪电说 Keychain 凭证读取（占位实现）

### 构建
- `build-app.sh` — 纯 `xcrun swiftc` + `codesign --options runtime` + `hdiutil`
- 输出 `MyPace-Preview-0.8.0.dmg`（~1.3 MB）
- Bundle ID: `ai.mypace.preview`

### 已知限制
- ad-hoc 签名（无 Developer ID，需手动允许运行）
- 无沙盒（不能上架 App Store）
- 无内购 / 无 StoreKit
- 闪电说 Keychain 命名未确认

---

## [0.7.0] — 2026-05-24

- 字级动效回放优化（verify_word_playback）
- ASR 字级时间戳验证（verify_asr_words）
- MyPace-Swift workspace 预编译二进制 v0.5 → v0.7

---

## [0.6.0] — 2026-05-24

- 录音服务 RecordingService 实现
- 实时波形显示

---

## [0.5.0] — 2026-05-24

- 初始 AppKit 框架搭建
- 浮动透明窗口 + ScreenCaptureKit 排除验证通过
- 火山引擎 ASR 基础调用（verify_asr）
- UI 控件实验（verify_control）

---

## [0.1.0] — 2026-05-23

- 技术验证阶段：ScreenCaptureKit 排除浮动窗口 POC
- verify_spike.swift — 证明 `sharingType = .none` 可行
- HTML 设计稿（tahoe / v1）完成
