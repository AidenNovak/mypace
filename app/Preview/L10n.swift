//
//  L10n.swift
//  MyPace Preview
//
//  纯 Swift i18n —— 不依赖 .strings 文件，方便 swiftc 命令行编译。
//  支持 中文 / English / 日本語 三种语言 + 自动跟随系统。
//

import Foundation

// MARK: - 字符串 Key

enum L10nKey: String {
    // App
    case appName

    // Stage 状态
    case stageReady
    case stageRecording
    case stagePlaying
    case stageAligning

    // 主按钮文字
    case btnStartRecording
    case btnStopRecording
    case btnPlayRhythm
    case btnPause
    case btnAligning            // "对齐中"（不含 %）

    // Tooltip
    case tooltipPrevLine
    case tooltipNextLine
    case tooltipEditScript
    case tooltipSwitchScript
    case tooltipCaptureProtect
    case tooltipCaptureVisible
    case tooltipPreferences

    // Stack 中央引导文字
    case promptTapToStart            // "点 ● 开始录音"
    case promptSayItOut              // "说一段话，AI 帮你整理成带节奏的稿子"
    case promptRecordingNow          // "● 正在录音"
    case promptSpeakToMic            // "对着麦克风说就行"
    case promptThenTapStop           // "念完点 ■ 结束录音 即可"
    case promptAiWillProcess         // "AI 会把你的话整理成带节奏的稿件"
    case promptAligning              // "AI 正在整理你的录音…"

    // 底部 hint
    case hintReadyWithRhythm         // "空格 ▶ 播放    ⌘E 编辑    ⌘O 切换稿件"
    case hintReadyEmpty              // "提示：30 秒到 2 分钟最准 · 安静环境效果最好"
    case hintReadyWithScript         // "⌘E 编辑稿件    ⌘O 切换稿件    ⌘, 偏好设置"
    case hintRecording               // "Esc 取消录音"
    case hintAligning                // "通常 5–10 秒"
    case hintPlaying                 // "空格 暂停    ↑↓ 上下句    Esc 停止"

    // 菜单
    case menuAbout
    case menuPreferences
    case menuFile
    case menuNewScript
    case menuEditScript
    case menuSwitchScript
    case menuQuit
    case menuView
    case menuFontIncrease
    case menuFontDecrease
    case menuShowDataFolder

    // 偏好设置
    case prefsTitle
    case prefsLanguage
    case prefsLanguageAuto
    case prefsFontSize
    case prefsOpacity
    case prefsAccentColor
    case prefsAccentAmber
    case prefsAccentBlue
    case prefsAccentGreen
    case prefsAllowCapture
    case prefsAllowCaptureHint
    case prefsDone

    // 欢迎页
    case welcomeTitle
    case welcomeSubtitle
    case welcomeFeature1Title
    case welcomeFeature1Desc
    case welcomeFeature2Title
    case welcomeFeature2Desc
    case welcomeFeature3Title
    case welcomeFeature3Desc
    case welcomeStart

    // 通用对话框 / 提示
    case dialogCancel
    case dialogConfirm
    case dialogSave
    case dialogOK
    case dialogDelete
    case dialogTitle           // "标题"
    case dialogContent         // "内容（每行一句话）"
    case alertEmptyScript      // "稿件为空，无法播放"
    case alertMicDenied        // 麦克风权限被拒
    case alertRecordingFailed  // "录音失败"
    case alertAsrFailed        // "AI 整理失败"

    // 切换稿件
    case switchPickScript      // "选择一个稿件"
    case switchNoOtherScripts  // "没有其他稿件"
    case switchNewScript

    // 默认稿件标题
    case defaultScriptTitle    // "我的第一段录音"
    case untitledScript        // "未命名"

    // 编辑器窗口
    case editorWindowTitle
    case editorAllScripts
    case editorTitlePlaceholder
    case editorLines
    case editorChars
    case editorHasRhythm
    case editorNoRhythm
    case editorDeleteConfirm

    // About
    case aboutTitle
    case aboutTagline
    case aboutVersion
    case aboutCopyright
    case aboutPrivacy

    // Error messages
    case errorMicDenied
    case errorNoSpeech
    case errorRhythmMissing

    // Mic status dialog
    case micStatusTitle
    case micStatusDenied
    case micStatusNotAsked
    case micStatusRequestPerm
    case micStatusOpenSettings
    case micStatusClose

    // Delete script
    case deleteScriptConfirm
    case deleteScriptInfo

    // 偏好设置 - Tab
    case prefsTabVisual
    case prefsTabASR
    case prefsTabData

    // 偏好设置 - ASR
    case prefsAsrSectionTitle
    case prefsAsrCurrentSource
    case prefsAsrSourceCustom
    case prefsAsrSourceShandian
    case prefsAsrSourceBundled
    case prefsAsrReady
    case prefsAsrNotConfigured
    case prefsAsrCustomTitle
    case prefsAsrCustomHint
    case prefsAsrSave

    // 偏好设置 - Data
    case prefsDataPath
    case prefsOpenDataFolder
    case prefsScriptStats
    case prefsScriptsTotal
    case prefsScriptsRhythm
    case prefsRecordings
    case prefsOpenRecordings
    case prefsOpenLog
}

// MARK: - Language

enum Language: String, CaseIterable {
    case auto
    case zh
    case en
    case ja

    var displayName: String {
        switch self {
        case .auto: return "Auto / 自动 / 自動"
        case .zh: return "简体中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}

// MARK: - L10n 单例

@MainActor
final class L10n {

    static let shared = L10n()

    static let languageChangedNotification = Notification.Name("L10nLanguageChanged")

    private init() {}

    /// 用户在 Preferences 中选的语言 —— 直接读 UserSettings
    var language: Language {
        get { UserSettings.shared.language }
        set {
            UserSettings.shared.language = newValue
            NotificationCenter.default.post(name: Self.languageChangedNotification, object: nil)
        }
    }

    /// 最终生效的语言 —— auto 时跟随系统首选
    var resolvedLanguage: Language {
        if language != .auto { return language }
        guard let pref = Locale.preferredLanguages.first?.lowercased() else { return .zh }
        if pref.hasPrefix("ja") { return .ja }
        if pref.hasPrefix("en") { return .en }
        if pref.hasPrefix("zh") { return .zh }
        // 其他语言默认 en（更通用）
        return .en
    }

    func t(_ key: L10nKey) -> String {
        let lang = resolvedLanguage
        return Self.table[lang]?[key]
            ?? Self.table[.en]?[key]
            ?? "[\(key.rawValue)]"
    }

    /// 带参数的本地化（如 "对齐中 \(pct)%"）
    func t(_ key: L10nKey, _ args: CVarArg...) -> String {
        let pattern = t(key)
        return String(format: pattern, arguments: args)
    }

    // MARK: - 字典

    private static let table: [Language: [L10nKey: String]] = [
        .zh: [
            .appName: "MyPace",

            .stageReady: "READY",
            .stageRecording: "RECORDING",
            .stagePlaying: "PLAYING",
            .stageAligning: "ALIGNING",

            .btnStartRecording: "开始录音",
            .btnStopRecording: "结束录音",
            .btnPlayRhythm: "按节奏播放",
            .btnPause: "暂停",
            .btnAligning: "对齐中 %d%%",

            .tooltipPrevLine: "上一句  ↑",
            .tooltipNextLine: "下一句  ↓",
            .tooltipEditScript: "编辑稿件  ⌘E",
            .tooltipSwitchScript: "切换稿件  ⌘O",
            .tooltipCaptureProtect: "录屏保护：已隐藏",
            .tooltipCaptureVisible: "录屏保护：可被录制",
            .tooltipPreferences: "偏好设置  ⌘,",

            .promptTapToStart: "点 ● 开始录音",
            .promptSayItOut: "说一段话,AI 帮你整理成带节奏的稿子",
            .promptRecordingNow: "● 正在录音",
            .promptSpeakToMic: "对着麦克风说就行",
            .promptThenTapStop: "念完点 ■ 结束录音 即可",
            .promptAiWillProcess: "AI 会把你的话整理成带节奏的稿件",
            .promptAligning: "AI 正在整理你的录音…",

            .hintReadyWithRhythm: "空格 ▶ 播放    ⌘E 编辑    ⌘O 切换稿件",
            .hintReadyEmpty: "提示:30 秒到 2 分钟最准 · 安静环境效果最好",
            .hintReadyWithScript: "⌘E 编辑稿件    ⌘O 切换稿件    ⌘, 偏好设置",
            .hintRecording: "Esc 取消录音",
            .hintAligning: "通常 5–10 秒",
            .hintPlaying: "空格 暂停    ↑↓ 上下句    Esc 停止",

            .menuAbout: "关于 %@",
            .menuPreferences: "偏好设置…",
            .menuFile: "脚本",
            .menuNewScript: "新建稿件",
            .menuEditScript: "编辑稿件",
            .menuSwitchScript: "切换稿件",
            .menuQuit: "退出 %@",
            .menuView: "节奏",
            .menuFontIncrease: "增大字号",
            .menuFontDecrease: "减小字号",
            .menuShowDataFolder: "在 Finder 中显示数据目录",

            .prefsTitle: "偏好设置",
            .prefsLanguage: "语言",
            .prefsLanguageAuto: "自动 (跟随系统)",
            .prefsFontSize: "字号",
            .prefsOpacity: "透明度",
            .prefsAccentColor: "高亮颜色",
            .prefsAccentAmber: "蓝紫",
            .prefsAccentBlue: "天蓝",
            .prefsAccentGreen: "玫瑰",
            .prefsAllowCapture: "允许被屏幕录制看到",
            .prefsAllowCaptureHint: "默认关闭——你录视频时这个窗口不会出现在画面里",
            .prefsDone: "完成",

            .welcomeTitle: "欢迎使用 MyPace",
            .welcomeSubtitle: "为视频创作者打造的隐形提词器",
            .welcomeFeature1Title: "录屏看不到",
            .welcomeFeature1Desc: "ScreenCaptureKit 排除——录视频时这个窗口不会出现在画面里",
            .welcomeFeature2Title: "口述先行",
            .welcomeFeature2Desc: "先说一段话,AI 自动整理成带节奏的稿件,跟着你的节奏滚动",
            .welcomeFeature3Title: "完全私密",
                    .welcomeFeature3Desc: "稿件和录音都只存在你 mac 的本地目录,永远不会上云",
            .welcomeStart: "开始使用",

            .dialogCancel: "取消",
            .dialogConfirm: "确认",
            .dialogSave: "保存",
            .dialogOK: "好的",
            .dialogDelete: "删除",
            .dialogTitle: "标题",
            .dialogContent: "内容(每行一句话)",
            .alertEmptyScript: "稿件为空,无法播放",
            .alertMicDenied: "麦克风访问被拒。请在 系统设置 → 隐私与安全性 → 麦克风 中开启 MyPace。",
            .alertRecordingFailed: "录音失败",
            .alertAsrFailed: "AI 整理失败",

            .switchPickScript: "选择一个稿件",
            .switchNoOtherScripts: "没有其他稿件",
            .switchNewScript: "新建",

            .defaultScriptTitle: "我的第一段录音",
            .untitledScript: "未命名",

            .editorWindowTitle: "编辑稿件",
            .editorAllScripts: "全部稿件",
            .editorTitlePlaceholder: "稿件标题",
            .editorLines: "行",
            .editorChars: "字",
            .editorHasRhythm: "有节奏",
            .editorNoRhythm: "未生成节奏",
            .editorDeleteConfirm: "确认删除这个稿件？",

            .aboutTitle: "MyPace · Preview",
            .aboutTagline: "为视频创作者打造的隐形提词器",
            .aboutVersion: "版本",
            .aboutCopyright: "© 2026 MyPace Team",
            .aboutPrivacy: "所有数据仅存储在本地，永远不会上传",

            .errorMicDenied: "麦克风权限被拒绝。\n\n请到 系统设置 → 隐私与安全 → 麦克风 → 勾选「MyPace Preview」，然后重启 app。",
            .errorNoSpeech: "识别失败：录音里没有检测到语音。\n请检查麦克风是否离嘴近一点，或者重试。",
            .errorRhythmMissing: "当前稿件还没有节奏映射。先录一次音生成节奏。",

            .micStatusTitle: "麦克风权限状态：%@",
            .micStatusDenied: "如果显示「已拒绝」，需要去：\n系统设置 → 隐私与安全 → 麦克风 → 勾选「MyPace Preview」。",
            .micStatusNotAsked: "如果显示「未询问」，点下面「请求权限」会弹原生申请框。",
            .micStatusRequestPerm: "请求权限",
            .micStatusOpenSettings: "打开系统设置",
            .micStatusClose: "关闭",

            .deleteScriptConfirm: "确认删除？",
            .deleteScriptInfo: "「%@」将被永久删除。",

            .prefsTabVisual: "外观",
            .prefsTabASR: "语音识别",
            .prefsTabData: "数据管理",

            .prefsAsrSectionTitle: "语音识别（ASR）配置",
            .prefsAsrCurrentSource: "当前凭证来源",
            .prefsAsrSourceCustom: "自定义",
            .prefsAsrSourceShandian: "闪电说",
            .prefsAsrSourceBundled: "内置",
            .prefsAsrReady: "已就绪",
            .prefsAsrNotConfigured: "未配置",
            .prefsAsrCustomTitle: "自定义火山引擎凭证",
            .prefsAsrCustomHint: "填入你自己的火山引擎语音识别 App ID 和 Access Token。留空则使用内置凭证或闪电说配置。",
            .prefsAsrSave: "保存凭证",

            .prefsDataPath: "数据存储路径",
            .prefsOpenDataFolder: "在 Finder 中打开",
            .prefsScriptStats: "稿件统计",
            .prefsScriptsTotal: "个稿件",
            .prefsScriptsRhythm: "个有节奏",
            .prefsRecordings: "录音文件",
            .prefsOpenRecordings: "打开录音目录",
            .prefsOpenLog: "打开日志文件",
        ],

        .en: [
            .appName: "MyPace",

            .stageReady: "READY",
            .stageRecording: "RECORDING",
            .stagePlaying: "PLAYING",
            .stageAligning: "ALIGNING",

            .btnStartRecording: "Start Recording",
            .btnStopRecording: "Stop Recording",
            .btnPlayRhythm: "Play by Rhythm",
            .btnPause: "Pause",
            .btnAligning: "Aligning %d%%",

            .tooltipPrevLine: "Previous line  ↑",
            .tooltipNextLine: "Next line  ↓",
            .tooltipEditScript: "Edit script  ⌘E",
            .tooltipSwitchScript: "Switch script  ⌘O",
            .tooltipCaptureProtect: "Capture protect: hidden",
            .tooltipCaptureVisible: "Capture protect: visible",
            .tooltipPreferences: "Preferences  ⌘,",

            .promptTapToStart: "Tap ● to start recording",
            .promptSayItOut: "Say it out loud — AI will turn it into a rhythm-aware script",
            .promptRecordingNow: "● Recording",
            .promptSpeakToMic: "Just speak into the mic",
            .promptThenTapStop: "When done, tap ■ Stop Recording",
            .promptAiWillProcess: "AI will turn your speech into a rhythm-aware script",
            .promptAligning: "AI is processing your recording…",

            .hintReadyWithRhythm: "Space ▶ Play    ⌘E Edit    ⌘O Switch script",
            .hintReadyEmpty: "Tip: 30s to 2min works best · quiet environment recommended",
            .hintReadyWithScript: "⌘E Edit script    ⌘O Switch script    ⌘, Preferences",
            .hintRecording: "Esc to cancel",
            .hintAligning: "Usually 5–10 seconds",
            .hintPlaying: "Space pause    ↑↓ prev/next    Esc stop",

            .menuAbout: "About %@",
            .menuPreferences: "Preferences…",
            .menuFile: "Script",
            .menuNewScript: "New Script",
            .menuEditScript: "Edit Script",
            .menuSwitchScript: "Switch Script",
            .menuQuit: "Quit %@",
            .menuView: "Rhythm",
            .menuFontIncrease: "Bigger Font",
            .menuFontDecrease: "Smaller Font",
            .menuShowDataFolder: "Show Data Folder in Finder",

            .prefsTitle: "Preferences",
            .prefsLanguage: "Language",
            .prefsLanguageAuto: "Auto (Follow System)",
            .prefsFontSize: "Font Size",
            .prefsOpacity: "Opacity",
            .prefsAccentColor: "Accent Color",
            .prefsAccentAmber: "Violet",
            .prefsAccentBlue: "Blue",
            .prefsAccentGreen: "Rose",
            .prefsAllowCapture: "Allow screen recording to see this window",
            .prefsAllowCaptureHint: "Off by default — this window stays invisible to your screen recording",
            .prefsDone: "Done",

            .welcomeTitle: "Welcome to MyPace",
            .welcomeSubtitle: "An invisible teleprompter built for video creators",
            .welcomeFeature1Title: "Hidden from screen capture",
            .welcomeFeature1Desc: "ScreenCaptureKit excludes this window — it won't appear in your recordings",
            .welcomeFeature2Title: "Speak first, script later",
            .welcomeFeature2Desc: "Just talk — AI turns it into a rhythm-aware script that follows your pace",
            .welcomeFeature3Title: "Fully private",
                    .welcomeFeature3Desc: "Scripts and recordings stay only on your mac. Never uploaded.",
            .welcomeStart: "Get Started",

            .dialogCancel: "Cancel",
            .dialogConfirm: "Confirm",
            .dialogSave: "Save",
            .dialogOK: "OK",
            .dialogDelete: "Delete",
            .dialogTitle: "Title",
            .dialogContent: "Content (one sentence per line)",
            .alertEmptyScript: "Script is empty — nothing to play",
            .alertMicDenied: "Microphone access denied. Open System Settings → Privacy & Security → Microphone, and enable MyPace.",
            .alertRecordingFailed: "Recording failed",
            .alertAsrFailed: "AI processing failed",

            .switchPickScript: "Pick a script",
            .switchNoOtherScripts: "No other scripts",
            .switchNewScript: "New",

            .defaultScriptTitle: "My first recording",
            .untitledScript: "Untitled",

            .editorWindowTitle: "Edit Script",
            .editorAllScripts: "All Scripts",
            .editorTitlePlaceholder: "Script title",
            .editorLines: "lines",
            .editorChars: "chars",
            .editorHasRhythm: "Has rhythm",
            .editorNoRhythm: "No rhythm yet",
            .editorDeleteConfirm: "Delete this script?",

            .aboutTitle: "MyPace · Preview",
            .aboutTagline: "An invisible teleprompter for video creators",
            .aboutVersion: "Version",
            .aboutCopyright: "© 2026 MyPace Team",
            .aboutPrivacy: "All data stays on your Mac. Never uploaded.",

            .errorMicDenied: "Microphone access denied.\n\nGo to System Settings → Privacy & Security → Microphone → enable MyPace Preview, then restart.",
            .errorNoSpeech: "No speech detected in recording.\nTry moving closer to the mic, or record again.",
            .errorRhythmMissing: "No rhythm map yet. Record first to generate one.",

            .micStatusTitle: "Microphone permission: %@",
            .micStatusDenied: "If denied, go to:\nSystem Settings → Privacy & Security → Microphone → enable MyPace Preview.",
            .micStatusNotAsked: "If not asked yet, tap Request Permission below.",
            .micStatusRequestPerm: "Request Permission",
            .micStatusOpenSettings: "Open System Settings",
            .micStatusClose: "Close",

            .deleteScriptConfirm: "Delete?",
            .deleteScriptInfo: "「%@」will be permanently deleted.",

            .prefsTabVisual: "Appearance",
            .prefsTabASR: "Speech Recognition",
            .prefsTabData: "Data",

            .prefsAsrSectionTitle: "Speech Recognition (ASR) Settings",
            .prefsAsrCurrentSource: "Current credential source",
            .prefsAsrSourceCustom: "Custom",
            .prefsAsrSourceShandian: "Shandianshuo",
            .prefsAsrSourceBundled: "Bundled",
            .prefsAsrReady: "Ready",
            .prefsAsrNotConfigured: "Not configured",
            .prefsAsrCustomTitle: "Custom Volcengine Credentials",
            .prefsAsrCustomHint: "Enter your own Volcengine ASR App ID and Access Token. Leave empty to use bundled credentials or Shandianshuo config.",
            .prefsAsrSave: "Save Credentials",

            .prefsDataPath: "Data Storage Path",
            .prefsOpenDataFolder: "Open in Finder",
            .prefsScriptStats: "Script Statistics",
            .prefsScriptsTotal: "scripts",
            .prefsScriptsRhythm: "with rhythm",
            .prefsRecordings: "Recordings",
            .prefsOpenRecordings: "Open Recordings Folder",
            .prefsOpenLog: "Open Log File",
        ],

        .ja: [
            .appName: "MyPace",

            .stageReady: "READY",
            .stageRecording: "RECORDING",
            .stagePlaying: "PLAYING",
            .stageAligning: "ALIGNING",

            .btnStartRecording: "録音開始",
            .btnStopRecording: "録音終了",
            .btnPlayRhythm: "リズムで再生",
            .btnPause: "一時停止",
            .btnAligning: "整列中 %d%%",

            .tooltipPrevLine: "前の文  ↑",
            .tooltipNextLine: "次の文  ↓",
            .tooltipEditScript: "原稿を編集  ⌘E",
            .tooltipSwitchScript: "原稿を切替  ⌘O",
            .tooltipCaptureProtect: "録画保護：非表示",
            .tooltipCaptureVisible: "録画保護：表示中",
            .tooltipPreferences: "環境設定  ⌘,",

            .promptTapToStart: "● を押して録音開始",
            .promptSayItOut: "話してみてください。AI がリズム付き原稿にまとめます",
            .promptRecordingNow: "● 録音中",
            .promptSpeakToMic: "マイクに向かって話すだけ",
            .promptThenTapStop: "終わったら ■ 録音終了 を押す",
            .promptAiWillProcess: "AI が話した内容をリズム付き原稿にまとめます",
            .promptAligning: "AI が録音を処理中…",

            .hintReadyWithRhythm: "Space ▶ 再生    ⌘E 編集    ⌘O 原稿切替",
            .hintReadyEmpty: "ヒント:30 秒〜2 分が最適 · 静かな環境推奨",
            .hintReadyWithScript: "⌘E 原稿を編集    ⌘O 原稿を切替    ⌘, 環境設定",
            .hintRecording: "Esc でキャンセル",
            .hintAligning: "通常 5〜10 秒",
            .hintPlaying: "Space 一時停止    ↑↓ 前後の文    Esc 停止",

            .menuAbout: "%@ について",
            .menuPreferences: "環境設定…",
            .menuFile: "原稿",
            .menuNewScript: "新規原稿",
            .menuEditScript: "原稿を編集",
            .menuSwitchScript: "原稿を切替",
            .menuQuit: "%@ を終了",
            .menuView: "リズム",
            .menuFontIncrease: "文字を大きく",
            .menuFontDecrease: "文字を小さく",
            .menuShowDataFolder: "Finder でデータフォルダを表示",

            .prefsTitle: "環境設定",
            .prefsLanguage: "言語",
            .prefsLanguageAuto: "自動 (システムに従う)",
            .prefsFontSize: "文字サイズ",
            .prefsOpacity: "透明度",
            .prefsAccentColor: "アクセントカラー",
            .prefsAccentAmber: "バイオレット",
            .prefsAccentBlue: "ブルー",
            .prefsAccentGreen: "ローズ",
            .prefsAllowCapture: "画面録画にこのウィンドウを写す",
            .prefsAllowCaptureHint: "既定オフ — このウィンドウは録画に映りません",
            .prefsDone: "完了",

            .welcomeTitle: "MyPace へようこそ",
            .welcomeSubtitle: "動画クリエイターのための見えないテレプロンプター",
            .welcomeFeature1Title: "画面録画に映らない",
            .welcomeFeature1Desc: "ScreenCaptureKit で除外 — このウィンドウは録画に写りません",
            .welcomeFeature2Title: "話してから原稿",
            .welcomeFeature2Desc: "まず話す。AI がリズム付き原稿にまとめてペースに合わせてスクロール",
            .welcomeFeature3Title: "完全プライベート",
                    .welcomeFeature3Desc: "原稿も録音もあなたの mac のローカルのみに保存、クラウドには上がりません",
            .welcomeStart: "はじめる",

            .dialogCancel: "キャンセル",
            .dialogConfirm: "確認",
            .dialogSave: "保存",
            .dialogOK: "OK",
            .dialogDelete: "削除",
            .dialogTitle: "タイトル",
            .dialogContent: "内容 (1 行 1 文)",
            .alertEmptyScript: "原稿が空です — 再生できません",
            .alertMicDenied: "マイクへのアクセスが拒否されました。システム設定 → プライバシーとセキュリティ → マイク で MyPace を有効にしてください。",
            .alertRecordingFailed: "録音に失敗しました",
            .alertAsrFailed: "AI 処理に失敗しました",

            .switchPickScript: "原稿を選択",
            .switchNoOtherScripts: "他の原稿はありません",
            .switchNewScript: "新規",

            .defaultScriptTitle: "最初の録音",
            .untitledScript: "無題",

            .editorWindowTitle: "原稿を編集",
            .editorAllScripts: "全原稿",
            .editorTitlePlaceholder: "原稿タイトル",
            .editorLines: "行",
            .editorChars: "文字",
            .editorHasRhythm: "リズムあり",
            .editorNoRhythm: "リズム未生成",
            .editorDeleteConfirm: "この原稿を削除しますか？",

            .aboutTitle: "MyPace · Preview",
            .aboutTagline: "動画クリエイターのための見えないテレプロンプター",
            .aboutVersion: "バージョン",
            .aboutCopyright: "© 2026 MyPace Team",
            .aboutPrivacy: "全データはローカルのみに保存。クラウドには上がりません。",

            .errorMicDenied: "マイクへのアクセスが拒否されました。\n\nシステム設定 → プライバシーとセキュリティ → マイク で MyPace Preview を有効にして再起動してください。",
            .errorNoSpeech: "録音に音声が検出されませんでした。\nマイクに近づいて再度お試しください。",
            .errorRhythmMissing: "リズムマップがまだありません。先に録音してリズムを生成してください。",

            .micStatusTitle: "マイク権限状態：%@",
            .micStatusDenied: "拒否されている場合：\nシステム設定 → プライバシーとセキュリティ → マイク で MyPace Preview を有効にしてください。",
            .micStatusNotAsked: "未確認の場合、下の「権限を要求」を押してください。",
            .micStatusRequestPerm: "権限を要求",
            .micStatusOpenSettings: "システム設定を開く",
            .micStatusClose: "閉じる",

            .deleteScriptConfirm: "削除しますか？",
            .deleteScriptInfo: "「%@」は完全に削除されます。",

            .prefsTabVisual: "外観",
            .prefsTabASR: "音声認識",
            .prefsTabData: "データ",

            .prefsAsrSectionTitle: "音声認識（ASR）設定",
            .prefsAsrCurrentSource: "現在の認証情報ソース",
            .prefsAsrSourceCustom: "カスタム",
            .prefsAsrSourceShandian: "シャンディエンシュオ",
            .prefsAsrSourceBundled: "内蔵",
            .prefsAsrReady: "準備完了",
            .prefsAsrNotConfigured: "未設定",
            .prefsAsrCustomTitle: "カスタム Volcengine 認証情報",
            .prefsAsrCustomHint: "独自の Volcengine ASR App ID と Access Token を入力。空欄の場合は内蔵認証情報を使用。",
            .prefsAsrSave: "認証情報を保存",

            .prefsDataPath: "データ保存パス",
            .prefsOpenDataFolder: "Finder で開く",
            .prefsScriptStats: "原稿統計",
            .prefsScriptsTotal: "件の原稿",
            .prefsScriptsRhythm: "件リズム付き",
            .prefsRecordings: "録音ファイル",
            .prefsOpenRecordings: "録音フォルダを開く",
            .prefsOpenLog: "ログファイルを開く",
        ],
    ]
}

// MARK: - 便捷全局函数

@MainActor
func L(_ key: L10nKey) -> String {
    L10n.shared.t(key)
}

@MainActor
func L(_ key: L10nKey, _ args: CVarArg...) -> String {
    L10n.shared.t(key, args)
}
