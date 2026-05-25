# 技术规格文档（Technical Specification）— MyPace

> **版本**：v1.0 (macOS First)  
> **状态**：草案 / 待评审  
> **最后更新**：2026-05-21  
> **范围声明**：v1 版本**仅支持 macOS**（macOS 13 Ventura 及以上，优先支持 Apple Silicon M 系列）。  
> **ASR 策略**：练习阶段默认使用火山引擎（复用“闪电说”已配置的凭证与流式调用模式），正式录制全程本地。Windows 支持计划在 v2。

---

## 1. 整体技术架构

### 1.1 核心设计目标
- **极致本地化 + 可选云端**：正式录制全程零网络；仅在“练习录音对齐”阶段可调用云端 ASR（用户显式授权）。
- **零可见脚本**：提词器窗口内容**绝对不进入**任何录屏捕获（这是 v1 的最高优先级技术约束）。
- **精确节奏驱动**：滚动必须严格按照用户练习录音生成的时间戳映射表进行，偏差控制在 150ms 以内。
- **极简录制体验**：录制过程中 UI 干扰最小化（3 秒无操作自动隐藏）。

### 1.2 推荐技术栈（macOS v1）
| 层级           | 技术选型                          | 理由 |
|----------------|-----------------------------------|------|
| 桌面框架       | **Tauri 2.0** (Rust + WebView)   | 体积小、性能好、原生 macOS API 调用方便、代码签名友好 |
| 前端 UI        | React + TypeScript + Tailwind    | 快速开发、易于实现平滑滚动与波形可视化 |
| 音频录制       | **AVAudioEngine** + **AVAudioRecorder** | 系统原生，高质量，完美支持 16kHz / 24kHz |
| 本地语音识别   | **SFSpeechRecognizer** (系统) + **whisper.cpp** | 双路径兜底，SFSpeechRecognizer 零依赖 |
| 云端对齐       | OpenAI Whisper API（首选）+ 火山引擎（国内备选） | 时间戳精度高，支持 prompt 注入参考文稿 |
| 文本对齐算法   | Levenshtein Distance + 动态规划   | 轻量、可控、易于调试 |
| 窗口管理       | **ScreenCaptureKit** + NSWindow   | 原生支持 excludedWindows，彻底实现零捕获 |
| 滚动渲染       | WebView Canvas / requestAnimationFrame + WebGL | 60fps+ 平滑滚动，易于实现“呼吸高亮”和“连续两行” |
| 数据持久化     | 文件系统 + JSON（节奏映射） + SQLite（可选） | 简单可靠 |

**强烈推荐**：v1 直接采用 **Tauri 2.0**，Rust 负责所有原生能力（音频、窗口排除、文件 I/O），前端只负责 UI 和交互。

### 1.3 进程与线程模型
- **主进程**（Rust）：窗口管理、ScreenCaptureKit 配置、文件系统、云端请求协调
- **音频采集线程**：AVAudioEngine 输入节点 → PCM buffer → 练习录音文件
- **滚动渲染线程**：独立高优先级线程驱动时间戳 → 像素滚动（避免主线程卡顿）
- **WebView 渲染**：前端负责视觉呈现与用户交互

---

## 2. 练习录音与节奏映射引擎（云端火山引擎优先）

**v1 策略**：默认使用**火山引擎（Volcengine）ASR**（复用本地“闪电说”应用已有的生产级凭证和调用模式），作为高精度主力路径；同时保留本地 SenseVoice / macOS 系统 ASR 作为完全离线兜底。

目标：拿到用户练习录音后，生成**严格对齐用户原始文稿**的句子级时间戳映射，实现“一次练习，精确复刻个人节奏”。

### 2.1 凭证与配置复用（闪电说）

“闪电说”已在用户机器上配置并稳定使用火山引擎 ASR，凭证存储在：

```bash
~/Library/Application Support/Shandianshuo/config.json
```

关键字段（v1 直接读取）：

```json
"asr": {
  "provider": "volcengine",
  "volcengine": {
    "app_id": "3053469381",
    "access_token": "YM7Ra64iSu90M8jawU_MMfTjTpiPrUi4",
    "model": "bigmodel_nostream"   // 或 streaming 变体
  }
}
```

**实现建议**：
- MyPace 在首次启动或设置页面提供“一键导入闪电说凭证”按钮。
- 读取上述 JSON，提取 `app_id` + `access_token`。
- 提供“使用自己的火山引擎凭证”作为备选输入。
- 凭证以明文或 Keychain 形式本地存储（参考闪电说做法）。

### 2.2 火山引擎 ASR 调用方式（推荐方案）

#### 2.2.1 推荐模式：流式 WebSocket（与闪电说一致）
闪电说实际使用的是 **Volcengine 流式 WebSocket ASR**（日志中可见 `VolcengineASR`、`CloudASR-Streaming`、`Flushing stream`）。

对练习录音（离线文件）同样适用：

**调用流程**：
1. 建立 WebSocket 连接到火山引擎 ASR 流式端点（通常 `wss://...volcengine...`）。
2. 发送 `start` 消息，携带：
   - `app_id`
   - `access_token`
   - `model`（推荐 `bigmodel_nostream` 或支持热词的流式模型）
   - `audio_format`: "wav" / "pcm"
   - `sample_rate`: 16000
   - `hotwords` / `context`：**把用户完整原始文稿按短语切分后作为热词列表注入**（这是提升对齐质量的关键）。
3. 分块发送音频 PCM（每 100~200ms 一包，或整段文件分块推送）。
4. 最后发送 `finish` / flush 包。
5. 接收最终结果（包含 `utterances` 或 `words` 数组，带 `start_time` / `end_time`）。

**热词注入示例（伪代码）**：
```rust
let hotwords = split_script_into_phrases(user_original_script); // 每 3-8 个字一个短语
let request = StartRequest {
    app_id: "...",
    access_token: "...",
    model: "bigmodel_nostream",
    hotwords: hotwords,           // 强烈建议
    context: user_original_script, // 部分模型支持全文上下文
    ...
};
```

#### 2.2.2 备选：非流式文件上传（如果服务支持）
如果火山引擎提供 “bigmodel_nostream” 的文件直传接口，可直接上传完整 WAV + 热词，拿到一次性结果，代码更简单。

### 2.3 时间戳获取与解析

火山引擎返回的典型结构（基于闪电说实际使用模式推断）：

```json
{
  "result": {
    "utterances": [
      {
        "text": "大家好，今天我想和大家聊聊 MyPace",
        "start_time": 820,     // 毫秒
        "end_time": 4150,
        "words": [             // 如果模型支持词级
          {"word": "大家好", "start_time": 820, "end_time": 1230},
          ...
        ]
      }
    ]
  }
}
```

**处理策略**：
- 优先使用 `utterances` 级时间戳（句子级，对提词器最友好）。
- 如果只有词级，合并成句子级。
- 所有时间戳统一转为**秒**（带小数），存储到节奏映射文件中。
- 记录 `raw_asr_response`（调试用，可选持久化）。

### 2.4 本地参考文本对齐层（核心，必做）

即使注入热词，火山引擎返回的文本仍可能与用户原始文稿有差异（filler words、轻微改写、同义替换、标点）。**必须做本地对齐**，把时间戳“强映射”回用户原始文稿。

#### 2.4.1 对齐流程

1. **参考序列生成**  
   把用户原始文稿按**逻辑句子**切分（标点 + 用户手动插入的 `---` 断点），得到 `original_segments: Vec<String>`。

2. **ASR 结果序列化**  
   把火山引擎返回的 `utterances` / `words` 展平成带时间戳的词/短语列表。

3. **序列对齐**（Rust 推荐实现）：
   - 使用 **Levenshtein Distance（编辑距离）** 或 **Needleman-Wunsch** 全局对齐算法。
   - 为每个 `original_segment` 找到最佳匹配的 ASR 片段。
   - 取该片段的最小 `start_time` 和最大 `end_time` 作为最终时间戳。
   - 计算匹配置信度：`1 - (edit_distance / max_len)`。

4. **置信度分级**（用于 UI 高亮）：
   - ≥ 0.85 → 绿色（自动接受）
   - 0.60 ~ 0.85 → 黄色（建议检查）
   - < 0.60 → 红色（必须手动修正）

#### 2.4.2 局部重对齐支持
- 用户可在节奏编辑器中选中任意句子 → “重新练习本句” → 只对该句重新跑 ASR + 对齐。
- 支持合并/拆分句子后自动重新计算边界时间。

### 2.5 完整端到端流程（练习阶段）

```mermaid
flowchart TD
    A[用户点击「开始练习录音」] --> B[高质量本地录制 WAV<br/>AVAudioEngine 16kHz]
    B --> C{用户选择对齐方式}
    C -->|云端火山引擎（默认）| D[读取闪电说凭证<br/>建立 WebSocket 连接]
    C -->|完全本地| E[本地 SenseVoice / SFSpeechRecognizer]
    
    D --> F[发送 start + hotwords（原始文稿短语）]
    F --> G[分块推送音频 + 最终 flush]
    G --> H[接收带时间戳结果]
    H --> I[本地 Levenshtein 对齐层<br/>映射回原始文稿]
    I --> J[生成节奏映射 .rhythm.json<br/>source = "volcengine"]
    
    E --> I
    
    J --> K[进入节奏可视化编辑器<br/>置信度高亮 + 可拖拽微调]
    K --> L[用户确认 → 正式录制时严格按此节奏滚动]
```

### 2.6 错误处理与降级策略

- 云端请求失败 / 超时 / 配额不足 → 自动降级到本地 SenseVoice（如果模型已下载）或提示用户手动对齐。
- 对齐置信度整体过低（< 0.65）→ 弹窗提示“ASR 识别偏差较大，建议检查或重新练习”，并默认打开编辑器高亮问题句子。
- 热词注入失败（某些模型不支持超长 hotwords）→ 自动截断为高频关键词列表。
- 用户中途取消上传 → 立即终止连接，进入纯手动模式。

### 2.7 节奏映射文件最终 Schema（更新版）

```json
{
  "version": 1,
  "scriptId": "uuid",
  "practiceId": "uuid",
  "source": "volcengine" | "sensevoice-local" | "sfspeech" | "manual",
  "asr_model": "volcengine-bigmodel_nostream",
  "created_at": "2026-05-21T17:03:00Z",
  "duration": 187.42,
  "raw_asr_confidence": 0.91,
  "segments": [
    {
      "text": "大家好，今天我想和大家聊聊 MyPace",
      "start": 0.82,
      "end": 4.15,
      "confidence": 0.97,
      "raw_asr_text": "大家好，今天我想和大家聊聊 mypace 呀"
    }
  ]
}
```

### 2.8 实现优先级建议（macOS v1）

1. 先实现 **音频录制 + 节奏映射文件读写 + 可视化编辑器**（不依赖 ASR）。
2. 实现 **火山引擎 WebSocket 客户端**（复用闪电说模式 + hotwords 注入）。
3. 实现 **本地对齐算法**（Levenshtein）。
4. 集成凭证导入 + 降级逻辑。
5. 最后打通 E2E 并做对齐精度验证（准备 5-10 段真实测试稿）。

---

**本节完成度**：已达到可直接指导 Rust + 前端开发的工程规格级别。后续可在此基础上补充具体请求结构体、错误码映射、热词切分策略等实现细节。

---

## 3. 窗口捕获排除机制（macOS）—— v1 最高优先级

由于 v1 **仅支持 macOS**，这个曾经最难的问题现在变成**最容易解决**的部分。

### 3.1 推荐实现方式（ScreenCaptureKit）
- 使用 `SCStreamConfiguration` + `SCContentFilter` 的 `excludedWindows` 数组
- 在创建提词器窗口时，立即把该 `NSWindow` 的 `windowNumber` 加入排除列表
- 必须在录制开始前就完成排除配置

**关键代码路径**（需验证）：
```swift
let filter = SCContentFilter(
    display: display,
    excludingWindows: [teleprompterWindow]
)
```

### 3.2 额外保护措施（防御性编程）
- 窗口样式设置为 `NSWindowStyleMask` 特殊组合（避免某些第三方录屏工具通过 CGWindowList 绕过）
- 提供“强制副屏录制”引导（当用户使用不支持 exclude 的老旧录屏工具时）
- 录制中禁止用户把提词器窗口拖到被录区域（或给出强烈视觉警告）

### 3.3 验证 Checklist（必须在 v1 上线前全部通过）
- [ ] macOS 内置“屏幕录制”无法捕获提词器内容
- [ ] OBS Studio（最新版）无法捕获
- [ ] CapCut / FocuSee / Screen Studio 等主流工具验证
- [ ] 窗口透明度 30%~70% 各种组合均通过
- [ ] 多显示器场景（提词器在副屏，被录内容在主屏）

**验收标准**：任何主流 macOS 录屏工具在默认设置下捕获概率必须为 **0%**。

---

## 4. 滚动引擎实现（macOS）

- 核心驱动：根据节奏映射表中的 `(start, end)` 时间戳 + 当前系统时间，计算当前应该显示到哪一行
- 渲染目标：WebView 中的 Canvas 或纯 DOM + CSS transform
- 平滑策略：
  - ease-out cubic + 轻微惯性
  - 当前行“呼吸式”高亮（opacity 1.0 ↔ 0.85）
  - “连续两行”：当前句 100% + 下一句 60-70% 不透明
- 性能目标：60fps+，即使在 M1 低功耗模式下滚动也丝滑

---

## 5. 构建、打包与分发（macOS）

- 推荐使用 **Tauri 2.0** + `tauri-plugin-shell` 等
- 代码签名 + Notarization 必须支持（`tauri.conf.json` 中配置 `bundle`）
- whisper.cpp 模型文件：首次启动按需下载（~300MB~800MB，根据用户选择量化级别）
- DMG / .app 打包
- 未来可考虑 Mac App Store（需额外处理沙盒与权限）

---

## 6. 隐私与数据流（macOS 特别说明）

- 练习音频：默认对齐完成后立即删除（用户可选保留）
- 节奏映射文件：存储在 `~/Library/Application Support/MyPace/rhythms/`
- 云端调用：仅在用户明确勾选“云端优先”且点击“开始练习”后才发生
- 所有正式录制行为：零网络请求

---

## 7. 性能与资源预算（macOS）

| 指标                    | v1 目标值              |
|-------------------------|------------------------|
| 滚动帧率                | ≥ 60fps（M1 及以上）   |
| 透明窗口 + 置顶功耗     | 低功耗模式下 < 8% CPU  |
| 800 字文稿云端对齐耗时  | < 6 秒（Wi-Fi）        |
| 长时间录制（2 小时）内存增长 | < 120MB             |
| 提词器窗口被捕获概率    | 0%                     |

---

## 8. 测试策略（macOS）

- **零捕获验证矩阵**：不同 macOS 版本（13/14/15）+ 不同录屏工具
- **对齐精度测试**：准备 10 段不同长度、不同语速、带口音的测试音频，手动标注 ground truth，对比系统输出
- **E2E 流程测试**：完整“输入文稿 → 练习 → 对齐 → 编辑 → 正式录制”流程
- **无障碍测试**：VoiceOver + 键盘全流程

---

## 9. 开放决策与风险（macOS v1）

**已锁定**：
- macOS 13+ 作为最低支持版本
- Tauri 2.0 作为首选框架

**待决策**：
- 是否在 v1 同时支持 Intel Mac（还是 Apple Silicon only）？
- whisper.cpp 是否必须打包，还是只做云端路径 + SFSpeechRecognizer？
- 节奏映射文件是否默认加密？

**已知风险**：
- 极少数第三方录屏工具可能通过私有 API 绕过 ScreenCaptureKit exclude（需持续跟进）

---

**文档状态**：本规格将随开发过程持续演进。  
每当有重大技术决策落地，需同步更新本文件并打 Tag。

---

**下一步建议**（供团队参考）：
1. 先完成 **Section 3（macOS 窗口排除）** 的 PoC + 验证报告 —— 这是最高风险点
2. 完成 **Section 2.1 + 2.2** 的音频录制 + 双路径对齐最小可跑 Demo
3. 确定 Tauri 2.0 项目脚手架

需要我现在就把上面这个结构进一步展开成带具体接口定义、伪代码、文件目录建议的更详细版本吗？或者你想先聚焦哪一节？