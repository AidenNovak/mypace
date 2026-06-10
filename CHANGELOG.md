# MyPace · Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/).

---

## [Unreleased]

### 方向调整（2026-05）
- 移除不完整的 `app-v11-xcode/`（SwiftUI + SwiftData 骨架，核心节奏引擎未实现）
- 决定全力保留并打磨 v0.8（AppKit + 纯 swiftc 构建）
  - v0.8 已具备 RhythmPlayback 30Hz 引擎、逐字 CATextLayer 高亮、口述模式（空脚本 ASR 自动生成稿件）
  - 先走 DMG 公测验证核心价值，再评估是否需要 App Store 版本

### 发版策略
- 专注自托管 DMG + notarization 公测（Track A）
- App Store 作为后续选项（需时再启动沙盒化工作）

---

## [0.8.0] — 2026-05-26

### Monorepo 重构
- 合并为 `mypace/` monorepo，统一管理 app / site / docs / verify
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
