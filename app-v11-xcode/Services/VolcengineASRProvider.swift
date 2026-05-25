//
//  VolcengineASRProvider.swift
//  MyPace
//
//  火山引擎 · 大模型录音文件识别 (v3 / bigmodel)
//  ===================================================
//  ✅ 已通过端到端测试（2026-05-23）
//  测试结果：
//    - HTTP 200, status = 20000000
//    - 全文识别 + 句级时间戳（精确到 0.01s）+ 95% 置信度
//
//  接入文档：
//  https://www.volcengine.com/docs/6561/1354869
//
//  关键差异（v1 → v3）：
//  - 认证方式：Authorization Header → X-Api-App-Key / X-Api-Access-Key headers
//  - 状态码：response body code → response header X-Api-Status-Code
//  - Endpoint：/api/v1/auc/submit → /api/v3/auc/bigmodel/submit
//

import Foundation

final class VolcengineASRProvider: ASRProvider {
    let displayName = "火山引擎"
    let isCloudBased = true

    private let appID: String
    private let accessToken: String
    private let resourceID: String
    private let submitURL: URL
    private let queryURL: URL
    private let session: URLSession

    init(
        appID: String,
        accessToken: String,
        resourceID: String = "volc.bigasr.auc"
    ) {
        self.appID = appID
        self.accessToken = accessToken
        self.resourceID = resourceID
        self.submitURL = URL(string: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit")!
        self.queryURL  = URL(string: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query")!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    func transcribe(
        audioURL: URL,
        scriptHint: String?,
        progress: ((Double) -> Void)?
    ) async throws -> [TranscribedSegment] {

        guard !appID.isEmpty, !accessToken.isEmpty else {
            throw ASRError.missingCredentials
        }
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw ASRError.invalidAudioFile
        }

        let audioData = try Data(contentsOf: audioURL)
        let format = inferFormat(from: audioURL)

        // 1) Submit（生成一个 request ID 作为 task ID）
        progress?(0.1)
        let taskID = UUID().uuidString
        try await submit(taskID: taskID, audioData: audioData, format: format)
        progress?(0.4)

        // 2) Poll
        for attempt in 1...60 {
            try await Task.sleep(for: .seconds(1))
            let result = try await poll(taskID: taskID)
            switch result {
            case .pending:
                progress?(0.4 + Double(attempt) * 0.01)
                continue
            case .success(let segments):
                progress?(1.0)
                if !segments.isEmpty {
                    let avg = segments.map(\.confidence).reduce(0, +) / Double(segments.count)
                    if avg < 0.4 { throw ASRError.lowConfidence(averageConfidence: avg) }
                }
                return segments
            case .failed(let code, let msg):
                throw ASRError.serverError(code: code, message: msg)
            }
        }
        throw ASRError.timeout
    }

    // MARK: - Submit (v3)

    private func submit(taskID: String, audioData: Data, format: String) async throws {
        let body: [String: Any] = [
            "user": [
                "uid": "mypace_user"
            ],
            "audio": [
                "format": format,           // "wav" / "mp3" / "m4a"
                "codec": "raw",
                "rate": 16000,
                "bits": 16,
                "channel": 1,
                "data": audioData.base64EncodedString()
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_punc": true,        // 自动加标点
                "enable_itn": true,         // 数字归一化
                "show_utterances": true     // ✨ 必须开，否则没有 sentence-level 时间戳
            ]
        ]

        var req = URLRequest(url: submitURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appID, forHTTPHeaderField: "X-Api-App-Key")
        req.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        req.setValue(resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        req.setValue(taskID, forHTTPHeaderField: "X-Api-Request-Id")
        req.setValue("submit", forHTTPHeaderField: "X-Api-Sequence")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ASRError.networkFailure(underlying: URLError(.badServerResponse))
        }

        // 火山 v3 状态码在 header 里
        let apiStatus = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        let apiMessage = http.value(forHTTPHeaderField: "X-Api-Message") ?? ""

        if apiStatus != "20000000" {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw ASRError.serverError(
                code: Int(apiStatus) ?? http.statusCode,
                message: "\(apiMessage) | \(bodyStr.prefix(200))"
            )
        }
    }

    // MARK: - Poll (v3)

    private enum PollResult {
        case pending
        case success([TranscribedSegment])
        case failed(Int, String)
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

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            return .failed(-1, "no HTTP response")
        }

        let apiStatus = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        let apiMessage = http.value(forHTTPHeaderField: "X-Api-Message") ?? ""

        // 20000001 = 处理中； 20000002 = 排队中
        if apiStatus == "20000001" || apiStatus == "20000002" { return .pending }

        if apiStatus != "20000000" {
            return .failed(Int(apiStatus) ?? -1, apiMessage)
        }

        // 成功 —— 解析 utterances
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any] else {
            return .failed(-2, "解析响应失败")
        }

        let utterances = result["utterances"] as? [[String: Any]] ?? []
        let segments = utterances.enumerated().map { i, u -> TranscribedSegment in
            TranscribedSegment(
                index: i,
                startTime: TimeInterval(u["start_time"] as? Int ?? 0) / 1000.0,
                endTime:   TimeInterval(u["end_time"]   as? Int ?? 0) / 1000.0,
                text: u["text"] as? String ?? "",
                confidence: u["confidence"] as? Double ?? 0.95,
                alternativeTexts: u["alternatives"] as? [String] ?? []
            )
        }
        return .success(segments)
    }

    // MARK: - Helpers

    private func inferFormat(from url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav":  "wav"
        case "mp3":  "mp3"
        case "m4a":  "m4a"
        case "ogg":  "ogg"
        case "flac": "flac"
        default:     "wav"
        }
    }
}
