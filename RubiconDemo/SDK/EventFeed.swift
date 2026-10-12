import Foundation
import Rubicon

/// One line of the event feed.
struct FeedEntry: Identifiable {
    enum Kind: String, CaseIterable { case queued, sent, dropped }

    let id: Int
    let time: String
    let kind: Kind
    let title: String
    let detail: String
    let messageIds: [String]
}

struct FeedCounts {
    var queued = 0
    var sent = 0
    var dropped: [String: Int] = [:]
    var droppedTotal: Int { dropped.values.reduce(0, +) }
}

/// The SDK's `eventObserver` (Logging 4c, iOS Logging 2): what became of every event, for the Logs
/// tab. Called on the SDK's queues, so the closure only hops to the main thread and appends.
@MainActor
final class EventFeed: ObservableObject {
    @Published private(set) var entries: [FeedEntry] = []
    @Published private(set) var counts = FeedCounts()
    private var nextId = 0
    private static let maximum = 400

    nonisolated var observer: EventObserver {
        { update in
            Task { @MainActor in EventFeed.shared?.append(update) }
        }
    }

    // The one feed; the observer closure is `@Sendable` and cannot capture `self` strongly across isolation.
    nonisolated(unsafe) static var shared: EventFeed?

    init() { EventFeed.shared = self }

    private func append(_ update: EventUpdate) {
        nextId += 1
        let entry: FeedEntry
        switch update {
        case .queued(let event):
            counts.queued += 1
            entry = FeedEntry(id: nextId, time: Clock.now(), kind: .queued, title: Self.title(event), detail: Self.detail(event), messageIds: [event.messageId])
        case .sent(let ids):
            counts.sent += ids.count
            entry = FeedEntry(id: nextId, time: Clock.now(), kind: .sent, title: "\(ids.count) sent", detail: "the server accepted the batch", messageIds: ids)
        case .dropped(let ids, let reason):
            counts.dropped[name(reason), default: 0] += ids.count
            entry = FeedEntry(id: nextId, time: Clock.now(), kind: .dropped, title: "\(ids.count) dropped", detail: "reason: \(name(reason))", messageIds: ids)
        @unknown default:
            entry = FeedEntry(id: nextId, time: Clock.now(), kind: .queued, title: "unknown update", detail: "\(update)", messageIds: [])
        }
        entries.insert(entry, at: 0)
        if entries.count > Self.maximum { entries.removeLast(entries.count - Self.maximum) }
    }

    func clear() {
        entries = []
        counts = FeedCounts()
    }

    private static func title(_ event: any Event) -> String {
        switch event {
        case let track as TrackEvent: return track.name
        case let screen as ScreenEvent: return "screen \(screen.name)"
        case let identify as IdentifyEvent: return "identify \(identify.userId ?? "?")"
        default: return "event"
        }
    }

    private static func detail(_ event: any Event) -> String {
        let values: [String: PropertyValue]
        let source: EventSource
        let context: EventContext
        switch event {
        case let track as TrackEvent: (values, source, context) = (track.properties, track.source, track.context)
        case let screen as ScreenEvent: (values, source, context) = (screen.properties, screen.source, screen.context)
        case let identify as IdentifyEvent: (values, source, context) = (identify.traits, identify.source, identify.context)
        default: return ""
        }
        let session = context.session.map { "session …\($0.id.suffix(6))" } ?? "no session"
        let shown = values.sorted { $0.key < $1.key }.prefix(6).map { "\($0.key)=\(PropertyText.short($0.value))" }.joined(separator: ", ")
        let count = "\(values.count) \(values.count == 1 ? "property" : "properties")"
        return "\(name(source)) · \(session) · \(count)" + (shown.isEmpty ? "" : "\n\(shown)")
    }
}

/// `PropertyValue` as readable text.
enum PropertyText {
    static func text(_ value: PropertyValue) -> String {
        switch value {
        case .string(let s): return "\"\(s)\""
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .null: return "null"
        case .array(let items): return "[" + items.map(text).joined(separator: ", ") + "]"
        case .object(let fields): return "{" + fields.sorted { $0.key < $1.key }.map { "\($0.key): \(text($0.value))" }.joined(separator: ", ") + "}"
        @unknown default: return "?"
        }
    }

    static func short(_ value: PropertyValue) -> String {
        let full = text(value)
        return full.count > 40 ? String(full.prefix(40)) + "…" : full
    }
}

enum Clock {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func now() -> String { formatter.string(from: Date()) }
}
