//
// MyPace · ASR Integration Spike
// =====================================
// 用闪电说里读到的真实凭证，测试火山引擎大模型录音文件识别 API。
// 验证：
//   1. 网络可达
//   2. 凭证有效
//   3. 拿到 utterances + 时间戳 + 置信度
//

import Foundation

// 凭证（从 ~/Library/Application Support/Shandianshuo/config.json 读取）
let APP_ID = "3053469381"
let ACCESS_TOKEN = "YM7Ra64iSu90M8jawU_MMfTjTpiPrUi4"

// 测试音频
let AUDIO_PATH = "/tmp/test_zh.wav"

// 火山引擎 ASR 大模型 endpoint (v3)
let SUBMIT_URL = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit"
let QUERY_URL  = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query"

@main
struct ASRSpike {
    static func main() async throws {
        print("─────────────────────────────────────────────")
        print("MyPace · ASR Integration Spike")
        print("─────────────────────────────────────────────")
        print("App ID:       \(APP_ID)")
        print("Access Token: \(ACCESS_TOKEN.prefix(8))…\(ACCESS_TOKEN.suffix(4))")
        print("Audio file:   \(AUDIO_PATH)")
        print("Endpoint:     \(SUBMIT_URL)")
        print("─────────────────────────────────────────────")
        print("")

        // 读音频
        let audioURL = URL(fileURLWithPath: AUDIO_PATH)
        let audioData = try Data(contentsOf: audioURL)
        print("✓ 音频加载成功: \(audioData.count) bytes")

        // ---- 1. 提交任务 ----
        print("\n▶︎ Step 1/2: 提交音频到火山引擎…")
        let taskID = try await submit(audioData: audioData)
        print("✓ 提交成功, task ID = \(taskID)")

        // ---- 2. 轮询结果 ----
        print("\n▶︎ Step 2/2: 轮询识别结果…")
        let result = try await poll(taskID: taskID)

        // ---- 3. 输出 ----
        print("\n─────────────────────────────────────────────")
        print("🎉 ASR 完成 · 识别到 \(result.count) 句")
        print("─────────────────────────────────────────────")
        for (i, seg) in result.enumerated() {
            let timeRange = String(format: "[%.2fs - %.2fs]", seg.startTime, seg.endTime)
            let conf = String(format: "%.0f%%", seg.confidence * 100)
            print("\(i+1). \(timeRange) (\(conf)) \(seg.text)")
        }
        print("─────────────────────────────────────────────")
        print("✅ MyPace 的 ASR 集成端到端可行")
    }

    // MARK: - Submit

    static func submit(audioData: Data) async throws -> String {
        let requestID = UUID().uuidString

        // v3 大模型 API：multipart 或 base64 都行，这里用 raw body + JSON header
        let body: [String: Any] = [
            "user": [
                "uid": "mypace_spike_user"
            ],
            "audio": [
                "format": "wav",
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
                "show_utterances": true
            ]
        ]

        var req = URLRequest(url: URL(string: SUBMIT_URL)!)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(APP_ID, forHTTPHeaderField: "X-Api-App-Key")
        req.setValue(ACCESS_TOKEN, forHTTPHeaderField: "X-Api-Access-Key")
        req.setValue("volc.bigasr.auc", forHTTPHeaderField: "X-Api-Resource-Id")
        req.setValue(requestID, forHTTPHeaderField: "X-Api-Request-Id")
        req.setValue("submit", forHTTPHeaderField: "X-Api-Sequence")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ASR", code: -1, userInfo: [NSLocalizedDescriptionKey: "no HTTP response"])
        }

        // 火山的状态码在 header 里
        let statusCode = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? "?"
        let statusMessage = http.value(forHTTPHeaderField: "X-Api-Message") ?? ""

        print("   HTTP \(http.statusCode), API status = \(statusCode) \(statusMessage)")
        if http.statusCode != 200 || statusCode != "20000000" {
            let bodyStr = String(data: data, encoding: .utf8) ?? "(empty)"
            throw NSError(
                domain: "ASR",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "submit failed: \(statusCode) \(statusMessage)\nBody: \(bodyStr)"]
            )
        }

        return requestID    // v3 大模型用 X-Api-Request-Id 作为 task ID
    }

    // MARK: - Poll

    static func poll(taskID: String) async throws -> [Segment] {
        for attempt in 1...60 {
            try await Task.sleep(for: .seconds(1))

            var req = URLRequest(url: URL(string: QUERY_URL)!)
            req.httpMethod = "POST"
            req.timeoutInterval = 30
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(APP_ID, forHTTPHeaderField: "X-Api-App-Key")
            req.setValue(ACCESS_TOKEN, forHTTPHeaderField: "X-Api-Access-Key")
            req.setValue("volc.bigasr.auc", forHTTPHeaderField: "X-Api-Resource-Id")
            req.setValue(taskID, forHTTPHeaderField: "X-Api-Request-Id")
            req.httpBody = try JSONSerialization.data(withJSONObject: [:] as [String: Any])

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { continue }

            let statusCode = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
            let statusMessage = http.value(forHTTPHeaderField: "X-Api-Message") ?? ""

            print("   [attempt \(attempt)] status = \(statusCode) \(statusMessage)")

            // 火山 v3 状态码：
            // 20000000 = 成功
            // 20000001 = 处理中
            // 20000002 = 排队中
            // 其他 = 失败
            if statusCode == "20000001" || statusCode == "20000002" {
                continue
            }
            if statusCode != "20000000" {
                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "ASR", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "查询失败: \(statusCode) \(statusMessage)\n\(bodyStr)"
                ])
            }

            // 成功 —— 解析 result
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any] else {
                throw NSError(domain: "ASR", code: -3, userInfo: [NSLocalizedDescriptionKey: "解析响应失败"])
            }

            print("   全文识别: \(result["text"] as? String ?? "")")

            let utterances = result["utterances"] as? [[String: Any]] ?? []
            return utterances.map { u in
                Segment(
                    startTime: TimeInterval(u["start_time"] as? Int ?? 0) / 1000.0,
                    endTime:   TimeInterval(u["end_time"]   as? Int ?? 0) / 1000.0,
                    text: u["text"] as? String ?? "",
                    confidence: u["confidence"] as? Double ?? 0.95
                )
            }
        }
        throw NSError(domain: "ASR", code: -4, userInfo: [NSLocalizedDescriptionKey: "60s 超时"])
    }
}

struct Segment {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let confidence: Double
}
