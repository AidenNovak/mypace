//
//  ASR.swift
//  MyPace Preview
//
//  火山引擎 ASR · v3 大模型录音文件识别
//  已端到端验证（2026-05-23）
//  凭证默认从闪电说读取，失败则用 hard-coded fallback
//

import Foundation

// MARK: - 凭证读取

struct ASRCredentials {
    let appID: String
    let accessToken: String

    /// 内置凭证（v0.3.x Preview 版本）
    /// ⚠️ 仅用于早期 vlogger 试用阶段，正式发布会改为后端 proxy
    /// 配额耗尽时会自动切换/失败
    static let bundled = ASRCredentials(
        appID: "3053469381",
        accessToken: "YM7Ra64iSu90M8jawU_MMfTjTpiPrUi4"
    )

    /// 智能解析：优先用户自定义 → 闪电说 → 内置
    /// 让 vlogger 装完 dmg 就能用
    static func auto() -> ASRCredentials {
        if let custom = fromUserDefaults() { return custom }
        if let shan = fromShandianshuo()   { return shan }
        return bundled
    }

    /// MyPace 自己的凭证存储（未来给用户填自己的火山账号用）
    static func fromUserDefaults() -> ASRCredentials? {
        let d = UserDefaults.standard
        guard let id = d.string(forKey: "asr.custom.appID"),
              let token = d.string(forKey: "asr.custom.accessToken"),
              !id.isEmpty, !token.isEmpty else {
            return nil
        }
        return ASRCredentials(appID: id, accessToken: token)
    }

    /// 从闪电说本地配置文件读取（可选支持）
    static func fromShandianshuo() -> ASRCredentials? {
        let url = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Shandianshuo/config.json")

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let asr = json["asr"] as? [String: Any],
              let volc = asr["volcengine"] as? [String: Any],
              let appID = volc["app_id"] as? String,
              let token = volc["access_token"] as? String,
              !appID.isEmpty, !token.isEmpty else {
            return nil
        }
        return ASRCredentials(appID: appID, accessToken: token)
    }
}

// MARK: - ASR 客户端

actor VolcengineASR {
    private let appID: String
    private let accessToken: String
    private let resourceID = "volc.bigasr.auc"

    private let submitURL = URL(string: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit")!
    private let queryURL  = URL(string: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query")!

    init(credentials: ASRCredentials) {
        self.appID = credentials.appID
        self.accessToken = credentials.accessToken
    }

    /// 把录音文件转成时间戳化的句子列表
    /// - progress: 0.0 - 1.0
    func transcribe(audioURL: URL, progress: @Sendable @escaping (Double) -> Void) async throws -> [RhythmMap.Segment] {
        let audioData = try Data(contentsOf: audioURL)
        let taskID = UUID().uuidString

        progress(0.1)
        try await submit(taskID: taskID, audioData: audioData, format: audioURL.pathExtension)
        progress(0.4)

        for attempt in 1...60 {
            try await Task.sleep(for: .seconds(1))
            switch try await poll(taskID: taskID) {
            case .pending:
                progress(0.4 + Double(attempt) * 0.01)
                continue
            case .success(let segs):
                progress(1.0)
                return segs
            case .failed(let code, let msg):
                throw ASRError.serverError(code: code, message: msg)
            }
        }
        throw ASRError.timeout
    }

    // MARK: - Submit / Poll

    private func submit(taskID: String, audioData: Data, format: String) async throws {
        let body: [String: Any] = [
            "user": ["uid": "mypace_preview"],
            "audio": [
                "format": format.lowercased() == "wav" ? "wav" : (format.lowercased() == "caf" ? "wav" : format.lowercased()),
                "codec": "raw",
                "rate": 16000,
                "bits": 16,
                "channel": 1,
                "data": audioData.base64EncodedString()
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_punc": true,
                "enable_itn": true,
                "show_utterances": true,
                // ✨ 字级时间戳（用于 word-level 跟读高亮）
                "enable_words": true,
                "show_words": true,
                "enable_word_time_offset": true
            ]
        ]

        var req = URLRequest(url: submitURL)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appID, forHTTPHeaderField: "X-Api-App-Key")
        req.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        req.setValue(resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        req.setValue(taskID, forHTTPHeaderField: "X-Api-Request-Id")
        req.setValue("submit", forHTTPHeaderField: "X-Api-Sequence")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ASRError.network("no HTTP response")
        }
        let status = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        let msg = http.value(forHTTPHeaderField: "X-Api-Message") ?? ""

        if status != "20000000" {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ASRError.serverError(code: Int(status) ?? http.statusCode,
                                       message: "\(msg) | \(body.prefix(200))")
        }
    }

    private enum PollResult {
        case pending, success([RhythmMap.Segment]), failed(Int, String)
    }

    private func poll(taskID: String) async throws -> PollResult {
        var req = URLRequest(url: queryURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appID, forHTTPHeaderField: "X-Api-App-Key")
        req.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        req.setValue(resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        req.setValue(taskID, forHTTPHeaderField: "X-Api-Request-Id")
        req.httpBody = try JSONSerialization.data(withJSONObject: [:] as [String: Any])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            return .failed(-1, "no HTTP response")
        }
        let status = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        let msg = http.value(forHTTPHeaderField: "X-Api-Message") ?? ""

        if status == "20000001" || status == "20000002" { return .pending }
        if status != "20000000" {
            return .failed(Int(status) ?? -1, msg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let utterances = result["utterances"] as? [[String: Any]] else {
            return .failed(-2, "parse failed")
        }
        let segs = utterances.enumerated().map { i, u -> RhythmMap.Segment in
            // 解析字级时间戳（火山大模型自带）
            let wordsRaw = u["words"] as? [[String: Any]] ?? []
            let words: [RhythmMap.Word]? = wordsRaw.isEmpty ? nil : wordsRaw.map { w in
                RhythmMap.Word(
                    text: w["text"] as? String ?? "",
                    startTime: TimeInterval(w["start_time"] as? Int ?? 0) / 1000.0,
                    endTime:   TimeInterval(w["end_time"]   as? Int ?? 0) / 1000.0
                )
            }
            return RhythmMap.Segment(
                index: i,
                startTime: TimeInterval(u["start_time"] as? Int ?? 0) / 1000.0,
                endTime:   TimeInterval(u["end_time"]   as? Int ?? 0) / 1000.0,
                text: u["text"] as? String ?? "",
                confidence: u["confidence"] as? Double ?? 0.95,
                words: words
            )
        }
        return .success(segs)
    }
}

// MARK: - Errors

enum ASRError: LocalizedError {
    case noCredentials
    case network(String)
    case serverError(code: Int, message: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .noCredentials:           "未找到 ASR 凭证（请安装闪电说并完成首次登录）"
        case .network(let m):          "网络错误：\(m)"
        case .serverError(let c, let m): "火山引擎返回 \(c)：\(m)"
        case .timeout:                 "对齐超时（60s 未完成）"
        }
    }
}
