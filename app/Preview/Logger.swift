//
//  Logger.swift
//  MyPace Preview
//
//  日志写到 ~/Library/Logs/MyPacePreview.log
//  方便用户和我快速诊断问题
//

import Foundation
import os

@MainActor
final class MyPaceLogger {

    static let shared = MyPaceLogger()

    private let logFileURL: URL
    private let dateFormatter: ISO8601DateFormatter
    private let osLogger = os.Logger(subsystem: "ai.mypace.preview", category: "default")
    private let queue = DispatchQueue(label: "ai.mypace.logger", qos: .utility)

    private init() {
        let fm = FileManager.default
        let logsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.logFileURL = logsDir.appendingPathComponent("MyPacePreview.log")

        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 启动时附加一行分隔符
        log(.info, "=========== Session start · v\(Self.appVersion) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString) ===========")
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var logPath: String { shared.logFileURL.path }

    enum Level: String {
        case debug = "DEBUG"
        case info  = "INFO "
        case warn  = "WARN "
        case error = "ERROR"
    }

    func log(_ level: Level, _ message: String, file: String = #file, line: Int = #line) {
        let ts = dateFormatter.string(from: .now)
        let basename = (file as NSString).lastPathComponent
        let line = "[\(ts)] \(level.rawValue) \(basename):\(line) \(message)\n"

        // 同时写文件 + Console.app
        switch level {
        case .debug: osLogger.debug("\(message, privacy: .public)")
        case .info:  osLogger.info("\(message, privacy: .public)")
        case .warn:  osLogger.warning("\(message, privacy: .public)")
        case .error: osLogger.error("\(message, privacy: .public)")
        }

        let url = logFileURL
        queue.async {
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: url.path) {
                    if let handle = try? FileHandle(forWritingTo: url) {
                        defer { try? handle.close() }
                        _ = try? handle.seekToEnd()
                        try? handle.write(contentsOf: data)
                    }
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }
}

/// 顶级便捷函数
@MainActor func logDebug(_ msg: String, file: String = #file, line: Int = #line) {
    MyPaceLogger.shared.log(.debug, msg, file: file, line: line)
}
@MainActor func logInfo(_ msg: String, file: String = #file, line: Int = #line) {
    MyPaceLogger.shared.log(.info, msg, file: file, line: line)
}
@MainActor func logWarn(_ msg: String, file: String = #file, line: Int = #line) {
    MyPaceLogger.shared.log(.warn, msg, file: file, line: line)
}
@MainActor func logError(_ msg: String, file: String = #file, line: Int = #line) {
    MyPaceLogger.shared.log(.error, msg, file: file, line: line)
}
