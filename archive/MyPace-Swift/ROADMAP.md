# MyPace · Roadmap

从 HTML 设计稿到上架 Mac App Store 的完整路线图。

---

## 阶段 1 · 技术验证（本周）

> 目标：证明"窗口不被录到"在技术上可行

- [x] 工程骨架搭建
- [x] SwiftData 数据模型
- [x] 主题系统（对应 HTML 设计稿）
- [x] **WindowManager: ScreenCaptureKit 排除浮动窗口**
- [x] DashboardView 静态布局
- [x] FloatingTeleprompterView 浮动窗口实现
- [ ] **关键验证**：开 OBS / Loom / QuickTime 录屏，确认浮动提词器**不出现在录制画面里**

如果这一步通过 ✅，整个项目就有意义。

---

## 阶段 2 · 录制流程闭环（2-3 周）

> 目标：让用户能完整走完"输入稿件 → 录音 → 看到节奏映射"

- [ ] `RecordingService` —— AVAudioEngine 录制 + 实时波形
- [ ] `ASRService` —— 火山引擎 SDK 接入
- [ ] `KeychainService` —— 闪电说凭证读取
- [ ] `PracticeRecordingView` —— 练习录音 UI
- [ ] `RhythmEditorView` —— 节奏可视化编辑器
- [ ] 数据持久化：录音文件 + 节奏映射 JSON 写入沙盒

---

## 阶段 3 · 体验打磨（1-2 周）

> 目标：让产品"用起来不别扭"

- [ ] 全局快捷键：⌘N、⇧⌘R、Space（录制时暂停）
- [ ] 浮动窗口拖拽 + 大小记忆
- [ ] 节奏同步滚动算法（按时间戳推进高亮）
- [ ] `SettingsView` —— ASR 凭证 + 数据保留策略
- [ ] 错误处理：网络失败 / ASR 超时 / 权限被拒
- [ ] 引导：首次启动的 3 步 onboarding

---

## 阶段 4 · 上架准备（1-2 周）

> 目标：能在 Mac App Store 卖 ¥128

- [ ] App 图标设计（macOS 标准多尺寸）
- [ ] App Store Connect 配置 + 截图
- [ ] 隐私清单（PrivacyInfo.xcprivacy） —— 苹果强制要求
- [ ] 内购集成（StoreKit 2，做 ¥128 一次性购买）
- [ ] 沙盒权限申明（Microphone / Screen Recording / File Access）
- [ ] 公证（notarization）+ 提交审核

---

## 风险与备选方案

| 风险 | 概率 | 备选 |
|---|---|---|
| ScreenCaptureKit 排除窗口在某些 macOS 版本失败 | 中 | 退化为提示用户"录屏前最小化提词器" |
| 火山引擎 API 国际网络延迟高 | 低 | v1.1 加本地 SenseVoice |
| 长音频上传慢 | 中 | 分段上传 + 进度反馈 |
| Mac App Store 拒审（涉及录屏） | 低 | 直接 DMG 分发 + 自建支付（Stripe / Lemon Squeezy） |

---

## 性能目标

- **冷启动 < 1.5s**（vs Electron 通常 3-5s）
- **空闲内存 < 80MB**
- **录制时 CPU < 20%**
- **浮动窗口 60fps 滚动**

---

## v1.0 不做的事

明确不做，避免范围蔓延：

- ❌ iOS 配套 app
- ❌ Windows 版本
- ❌ 团队协作 / 云同步
- ❌ AI 改稿建议
- ❌ 多人参与
- ❌ 长视频后期剪辑导出

留给 v1.1 / v2.0。
