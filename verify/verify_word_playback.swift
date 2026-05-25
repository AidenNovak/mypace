//
// verify_word_playback.swift
// 端到端验证字级跟读：用真火山 ASR 拿到字级时间戳，
// 模拟 playback 在不同时间点，输出 "当前字 + 前后字"
// 让我用眼睛看节奏跟读到底对不对。
//

import Foundation

let APP_ID = "3053469381"
let ACCESS_TOKEN = "YM7Ra64iSu90M8jawU_MMfTjTpiPrUi4"
let AUDIO_PATH = "/tmp/test_zh.wav"

struct Word { let text: String; let start: Double; let end: Double }

@main
struct WordPlayback {
    static func dbg(_ s: String) {
        FileHandle.standardError.write("DEBUG: \(s)\n".data(using: .utf8)!)
    }

    static func main() async throws {
        dbg("main start")
        dbg("audio path = \(AUDIO_PATH)")
        dbg("audio exists = \(FileManager.default.fileExists(atPath: AUDIO_PATH))")
        dbg("calling getWords()...")
        let words = try await getWords()
        dbg("✓ 拿到 \(words.count) 个字")
        if words.isEmpty {
            print("没拿到字"); return
        }

        // 2. 模拟 playback：每 50ms 取一个时间点，看当前是哪个字
        let totalDuration = (words.last?.end ?? 0) + 0.3
        print("─────────────────────────────────────────────")
        print("模拟 playback timeline (每 200ms 一帧):")
        print("─────────────────────────────────────────────")
        print("time     | 前2 前1  [当前]  后1 后2")
        print(String(repeating: "-", count: 60))

        var t: Double = 0
        while t <= totalDuration {
            let lineParts = renderFrame(words: words, t: t)
            let timeStr = String(format: "%6.2fs", t)
            print("\(timeStr) | \(lineParts)")
            t += 0.2
        }

        print("\n─────────────────────────────────────────────")
        print("✅ 如果上面每一帧的 [当前] 都跟着时间往后走，跟读就对齐了")
    }

    /// 渲染某个时间点的"前2 前1 [当前] 后1 后2"
    static func renderFrame(words: [Word], t: Double) -> String {
        // 找当前字
        var curIdx = -1
        for (i, w) in words.enumerated() {
            if t >= w.start && t < w.end { curIdx = i; break }
            if t >= w.end { curIdx = i }
        }
        if curIdx < 0 {
            return "（句间停顿）"
        }
        // 取前2 前1 [当前] 后1 后2
        let parts: [String] = (-2...2).map { offset in
            let idx = curIdx + offset
            if idx < 0 || idx >= words.count { return "·" }
            let txt = words[idx].text
            if offset == 0 { return "[\(txt)]" }
            return txt
        }
        return parts.joined(separator: " ")
    }

    static func getWords() async throws -> [Word] {
        dbg("getWords: read audio")
        let audio = try Data(contentsOf: URL(fileURLWithPath: AUDIO_PATH))
        dbg("getWords: audio = \(audio.count) bytes")
        let taskID = UUID().uuidString

        dbg("getWords: submitting...")
        let body: [String: Any] = [
            "user": ["uid": "spike"],
            "audio": ["format": "wav", "codec": "raw", "rate": 16000, "bits": 16, "channel": 1,
                      "data": audio.base64EncodedString()],
            "request": ["model_name": "bigmodel", "enable_punc": true, "enable_itn": true,
                        "show_utterances": true, "enable_words": true]
        ]
        var sub = URLRequest(url: URL(string: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit")!)
        sub.httpMethod = "POST"
        sub.setValue("application/json", forHTTPHeaderField: "Content-Type")
        sub.setValue(APP_ID, forHTTPHeaderField: "X-Api-App-Key")
        sub.setValue(ACCESS_TOKEN, forHTTPHeaderField: "X-Api-Access-Key")
        sub.setValue("volc.bigasr.auc", forHTTPHeaderField: "X-Api-Resource-Id")
        sub.setValue(taskID, forHTTPHeaderField: "X-Api-Request-Id")
        sub.setValue("submit", forHTTPHeaderField: "X-Api-Sequence")
        sub.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (sd, sr) = try await URLSession.shared.data(for: sub)
        let sh = sr as! HTTPURLResponse
        dbg("submit response: \(sh.statusCode), api status=\(sh.value(forHTTPHeaderField: "X-Api-Status-Code") ?? "?")")
        _ = sd

        // poll
        dbg("polling...")
        for i in 1...60 {
            try await Task.sleep(for: .seconds(1))
            dbg("  poll #\(i)")
            var q = URLRequest(url: URL(string: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query")!)
            q.httpMethod = "POST"
            q.setValue("application/json", forHTTPHeaderField: "Content-Type")
            q.setValue(APP_ID, forHTTPHeaderField: "X-Api-App-Key")
            q.setValue(ACCESS_TOKEN, forHTTPHeaderField: "X-Api-Access-Key")
            q.setValue("volc.bigasr.auc", forHTTPHeaderField: "X-Api-Resource-Id")
            q.setValue(taskID, forHTTPHeaderField: "X-Api-Request-Id")
            q.httpBody = try JSONSerialization.data(withJSONObject: [:] as [String: Any])
            let (data, response) = try await URLSession.shared.data(for: q)
            let http = response as! HTTPURLResponse
            let status = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
            if status == "20000001" || status == "20000002" { continue }
            if status != "20000000" { exit(1) }

            // parse all words from all utterances
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let result = json["result"] as! [String: Any]
            let utterances = result["utterances"] as! [[String: Any]]
            var words: [Word] = []
            for u in utterances {
                if let ws = u["words"] as? [[String: Any]] {
                    for w in ws {
                        words.append(Word(
                            text: w["text"] as? String ?? "",
                            start: Double(w["start_time"] as? Int ?? 0) / 1000,
                            end: Double(w["end_time"] as? Int ?? 0) / 1000
                        ))
                    }
                }
            }
            return words
        }
        exit(2)
    }
}
