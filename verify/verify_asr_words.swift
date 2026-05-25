//
// verify_asr_words.swift
// 测火山引擎是否能返回**字级**时间戳（per-word/per-character timestamps）
// 把完整的 JSON 响应打印出来，看 utterances/words 结构
//

import Foundation

let APP_ID = "3053469381"
let ACCESS_TOKEN = "YM7Ra64iSu90M8jawU_MMfTjTpiPrUi4"
let AUDIO_PATH = "/tmp/test_zh.wav"

let SUBMIT_URL = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit"
let QUERY_URL  = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query"

@main
struct ASRWordSpike {
    static func main() async throws {
        let audioURL = URL(fileURLWithPath: AUDIO_PATH)
        guard FileManager.default.fileExists(atPath: AUDIO_PATH) else {
            print("先用 say 生成测试音频:")
            print("  say -o /tmp/test_zh.aiff -v Tingting '很多人以为定价是个数学题，其实它更像一场心理游戏。你卖的不是产品本身，而是它在客户心里值多少。'")
            print("  afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/test_zh.aiff /tmp/test_zh.wav")
            exit(1)
        }
        let audioData = try Data(contentsOf: audioURL)
        let taskID = UUID().uuidString

        print("▶︎ 提交音频…")
        try await submit(taskID: taskID, audio: audioData)

        print("▶︎ 等待结果…")
        var raw: [String: Any] = [:]
        for i in 1...60 {
            try await Task.sleep(for: .seconds(1))
            let (status, json) = try await query(taskID: taskID)
            print("  [\(i)] status=\(status)")
            if status == "20000001" || status == "20000002" { continue }
            if status == "20000000" {
                raw = json
                break
            }
            print("失败: \(status)")
            exit(2)
        }

        // 打印完整 JSON 结构
        print("\n─────────────────────────────────────────────")
        print("完整 JSON 响应：")
        print("─────────────────────────────────────────────")
        if let data = try? JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }

        // 重点分析：是否有 word-level / char-level 时间戳
        print("\n─────────────────────────────────────────────")
        print("时间戳粒度分析：")
        print("─────────────────────────────────────────────")
        if let result = raw["result"] as? [String: Any],
           let utterances = result["utterances"] as? [[String: Any]] {
            for (i, u) in utterances.enumerated() {
                print("Utterance \(i+1):")
                print("  text:       \(u["text"] ?? "")")
                print("  start_time: \(u["start_time"] ?? "") ms")
                print("  end_time:   \(u["end_time"] ?? "") ms")
                if let words = u["words"] as? [[String: Any]] {
                    print("  ✨ words (字级时间戳)：\(words.count) 个")
                    for w in words.prefix(10) {
                        print("    \(w["text"] ?? "?") : \(w["start_time"] ?? "?")ms - \(w["end_time"] ?? "?")ms")
                    }
                }
            }
        }
    }

    static func submit(taskID: String, audio: Data) async throws {
        let body: [String: Any] = [
            "user": ["uid": "spike"],
            "audio": [
                "format": "wav", "codec": "raw",
                "rate": 16000, "bits": 16, "channel": 1,
                "data": audio.base64EncodedString()
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_punc": true,
                "enable_itn": true,
                "show_utterances": true,
                // 关键尝试：开启字级时间戳
                "enable_words": true,
                "show_words": true,
                "enable_word_time_offset": true
            ]
        ]
        var req = URLRequest(url: URL(string: SUBMIT_URL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(APP_ID, forHTTPHeaderField: "X-Api-App-Key")
        req.setValue(ACCESS_TOKEN, forHTTPHeaderField: "X-Api-Access-Key")
        req.setValue("volc.bigasr.auc", forHTTPHeaderField: "X-Api-Resource-Id")
        req.setValue(taskID, forHTTPHeaderField: "X-Api-Request-Id")
        req.setValue("submit", forHTTPHeaderField: "X-Api-Sequence")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let http = response as! HTTPURLResponse
        let s = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        if s != "20000000" {
            print("submit failed: \(s) \(http.value(forHTTPHeaderField: "X-Api-Message") ?? "")")
            print(String(data: data, encoding: .utf8) ?? "")
            exit(3)
        }
    }

    static func query(taskID: String) async throws -> (String, [String: Any]) {
        var req = URLRequest(url: URL(string: QUERY_URL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(APP_ID, forHTTPHeaderField: "X-Api-App-Key")
        req.setValue(ACCESS_TOKEN, forHTTPHeaderField: "X-Api-Access-Key")
        req.setValue("volc.bigasr.auc", forHTTPHeaderField: "X-Api-Resource-Id")
        req.setValue(taskID, forHTTPHeaderField: "X-Api-Request-Id")
        req.httpBody = try JSONSerialization.data(withJSONObject: [:] as [String: Any])

        let (data, response) = try await URLSession.shared.data(for: req)
        let http = response as! HTTPURLResponse
        let status = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return (status, json)
    }
}
