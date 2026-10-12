import Foundation
import os
import Rubicon

struct LogLine: Identifiable {
    let id: Int
    let time: String
    let level: LogLevel
    let message: String
    let error: String?
}

/// The SDK's `logging.logger` (iOS Logging 1): every line goes to the Logs tab and to the unified
/// log under the demo's own subsystem, so Console.app shows both the SDK's default sink (when the
/// in-app logger is off) and this one.
@MainActor
final class SdkLog: ObservableObject {
    @Published private(set) var lines: [LogLine] = []
    private var nextId = 0
    private static let maximum = 600
    private static let console = Logger(subsystem: "com.rubicon.demo", category: "sdk")

    nonisolated(unsafe) static var shared: SdkLog?

    init() { SdkLog.shared = self }

    nonisolated var logger: RubiconLogger {
        { level, message, error in
            let errorText = error.map { ($0 as NSError).domain + " " + String(($0 as NSError).code) }
            switch level {
            case .debug: Self.console.debug("\(message, privacy: .public)")
            case .info: Self.console.info("\(message, privacy: .public)")
            case .warn: Self.console.notice("\(message, privacy: .public)")
            case .error: Self.console.error("\(message, privacy: .public)")
            case .off: return
            @unknown default: return
            }
            Task { @MainActor in SdkLog.shared?.append(level: level, message: message, error: errorText) }
        }
    }

    /// A line from the demo itself, marked as such.
    func note(_ message: String) { append(level: .info, message: "[demo] \(message)", error: nil) }

    private func append(level: LogLevel, message: String, error: String?) {
        nextId += 1
        lines.insert(LogLine(id: nextId, time: Clock.now(), level: level, message: message, error: error), at: 0)
        if lines.count > Self.maximum { lines.removeLast(lines.count - Self.maximum) }
    }

    func clear() { lines = [] }
}

extension LogLevel {
    /// The order for the Logs tab's filter: debug, info, warn, error.
    var rank: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warn: return 2
        case .error: return 3
        case .off: return 4
        @unknown default: return 4
        }
    }
}
