import Foundation
import os

/// Logs to the unified log (subsystem `me.chichou.rec`) and to `~/Library/Logs/Rec/rec.log`,
/// so a failed recording can be diagnosed after the fact.
enum Log {
    private static let logger = Logger(subsystem: "me.chichou.rec", category: "recording")
    private static let queue = DispatchQueue(label: "rec.log")

    static let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Rec", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("rec.log")
    }()

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        append("INFO  \(message)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        append("ERROR \(message)")
    }

    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        return "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
    }

    private static func append(_ line: String) {
        let stamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime, .withFractionalSeconds])
        let data = Data("\(stamp) \(line)\n".utf8)
        queue.async {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}
