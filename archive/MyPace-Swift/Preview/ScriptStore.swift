//
//  ScriptStore.swift
//  MyPace Preview v0.2
//
//  脚本持久化 —— JSON 存到 ~/Library/Application Support/MyPacePreview/scripts/
//  比 SwiftData 简单 100 倍，零依赖。
//

import Foundation

@MainActor
final class ScriptStore {

    static let shared = ScriptStore()

    private(set) var scripts: [Script] = []

    private let baseDir: URL
    private let scriptsDir: URL
    private let recordingsDir: URL

    private init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil, create: true)
        baseDir = appSupport.appendingPathComponent("MyPacePreview", isDirectory: true)
        scriptsDir = baseDir.appendingPathComponent("scripts", isDirectory: true)
        recordingsDir = baseDir.appendingPathComponent("Recordings", isDirectory: true)

        try? fm.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        load()
        seedIfEmpty()
    }

    // MARK: - 公共 API

    @MainActor static var dataDirectoryPath: String { shared.baseDir.path }
    @MainActor static var recordingsDirectoryURL: URL { shared.recordingsDir }
    @MainActor static var dataDirectoryURL: URL { shared.baseDir }

    func recordingURL(for filename: String) -> URL {
        recordingsDir.appendingPathComponent(filename)
    }

    func newRecordingURL() -> URL {
        let name = "\(UUID().uuidString).caf"
        return recordingURL(for: name)
    }

    func save(_ script: Script) {
        var s = script
        s.updatedAt = .now

        if let idx = scripts.firstIndex(where: { $0.id == s.id }) {
            scripts[idx] = s
        } else {
            scripts.insert(s, at: 0)
        }
        persist(s)
    }

    func delete(_ script: Script) {
        scripts.removeAll { $0.id == script.id }
        let url = scriptsDir.appendingPathComponent("\(script.id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 私有

    private func load() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: scriptsDir,
                                                    includingPropertiesForKeys: nil) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        scripts = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Script.self, from: data)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist(_ script: Script) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(script) else { return }
        let url = scriptsDir.appendingPathComponent("\(script.id.uuidString).json")
        try? data.write(to: url)
    }

    private func seedIfEmpty() {
        if scripts.isEmpty {
            // 首次启动一个空稿件，让用户能立刻按"开始录音"
            save(Script(title: L(.defaultScriptTitle)))
        }
    }
}
