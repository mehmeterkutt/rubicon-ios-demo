import Rubicon
import SwiftUI

struct LogsView: View {
    @ObservedObject private var feed = DemoApp.shared.feed
    @ObservedObject private var log = DemoApp.shared.sdkLog
    @State private var tab = 0
    @State private var kind: FeedEntry.Kind?
    @State private var level: LogLevel = .debug

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                StatTile(label: "queued", value: String(feed.counts.queued))
                StatTile(label: "sent", value: String(feed.counts.sent), color: Theme.success)
                StatTile(label: "dropped", value: String(feed.counts.droppedTotal), color: Theme.danger)
            }
            if !feed.counts.dropped.isEmpty {
                Flow {
                    ForEach(feed.counts.dropped.sorted { $0.key < $1.key }, id: \.key) { StatusPill("\($0.key) \($0.value)", Theme.danger) }
                }
            }
            Picker("", selection: $tab) {
                Text("Event updates").tag(0)
                Text("SDK log").tag(1)
            }
            .pickerStyle(.segmented)
            if tab == 0 {
                HStack {
                    kindChips
                    Spacer()
                    Button("Clear") { feed.clear() }.font(.caption)
                }
                let shown = feed.entries.filter { kind == nil || $0.kind == kind }
                if shown.isEmpty { Expect("Nothing yet: send an event from the Events tab. These come from logging.eventObserver.") }
                List(shown) { entry in FeedRow(entry: entry) }.listStyle(.plain)
            } else {
                HStack {
                    ChoiceChips(options: [LogLevel.debug, .info, .warn, .error], selected: $level) { name($0) + "+" }
                    Spacer()
                    Button("Clear") { log.clear() }.font(.caption)
                }
                let shown = log.lines.filter { $0.level.rank >= level.rank }
                if !DemoApp.shared.settings.inAppLogger {
                    Expect("The in-app logger is off (Settings): the SDK logs to the unified log only, subsystem com.rubicon.analytics.")
                }
                if shown.isEmpty { Expect("No lines at this level. The SDK logs at \(DemoApp.shared.settings.logLevel) and above (Settings).") }
                List(shown) { line in LogRow(line: line) }.listStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .background(Theme.paper)
    }

    private var kindChips: some View {
        Flow {
            chip("all", kind == nil) { kind = nil }
            ForEach(FeedEntry.Kind.allCases, id: \.self) { k in chip(k.rawValue, kind == k) { kind = k } }
        }
    }

    private func chip(_ label: String, _ selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6) }
            .background(selected ? Theme.sky : Theme.skyContainer).foregroundColor(selected ? .white : Theme.ink).cornerRadius(8)
    }
}

private struct FeedRow: View {
    let entry: FeedEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                StatusPill(entry.kind.rawValue, color)
                Text(entry.title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.time).font(.caption2.monospaced()).foregroundColor(Theme.muted)
            }
            Text(entry.detail).font(.caption).foregroundColor(Theme.muted)
            if let first = entry.messageIds.first {
                Text(entry.messageIds.count > 1 ? "\(first) +\(entry.messageIds.count - 1)" : first).font(.caption2.monospaced()).foregroundColor(Theme.muted)
            }
        }
        .padding(.vertical, 2)
    }

    private var color: Color {
        switch entry.kind {
        case .queued: return Theme.sky
        case .sent: return Theme.success
        case .dropped: return Theme.danger
        }
    }
}

private struct LogRow: View {
    let line: LogLine

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                StatusPill(name(line.level), color)
                Text(line.time).font(.caption2.monospaced()).foregroundColor(Theme.muted)
            }
            Text(line.message).font(.caption)
            if let error = line.error { Text(error).font(.caption2.monospaced()).foregroundColor(Theme.danger) }
        }
        .padding(.vertical, 2)
    }

    private var color: Color {
        switch line.level {
        case .debug: return Theme.muted
        case .info: return Theme.sky
        case .warn: return Theme.warning
        case .error: return Theme.danger
        case .off: return Theme.muted
        @unknown default: return Theme.muted
        }
    }
}
