import Rubicon
import SwiftUI

struct ServerView: View {
    private var app: DemoApp { DemoApp.shared }
    private var backend: FakeBackend { DemoApp.shared.backend }

    var body: some View {
        Page {
            ConnectionCard()
            ResponsesCard()
            RemoteConfigCard()
            ReceivedEventsCard()
            RequestsCard()
        }
    }
}

@MainActor
private func attempt(_ block: () async throws -> Void) async {
    do { try await block() } catch {
        Calls.show("Fake server unreachable: \(error). Is python3 fake-server/server.py running?")
    }
}

private struct ConnectionCard: View {
    @State private var state: String?
    @State private var reachable = false

    var body: some View {
        SectionCard("Fake server", "fake-server/server.py on the Mac; the SDK sends to the same host.") {
            Flow {
                StatusPill(reachable ? "reachable" : "unreachable", reachable ? Theme.success : Theme.danger)
                Text(DemoApp.shared.settings.host).font(.caption.monospaced())
            }
            if let state { Text(state).font(.caption.monospaced()) }
            OutlineButton("Check again") { Task { await check() } }
        }
        .task { await check() }
    }

    private func check() async {
        do {
            let response = try await DemoApp.shared.backend.control()
            state = response.body.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "  ", with: " ")
            reachable = true
        } catch {
            state = "\(error)"
            reachable = false
        }
    }
}

private struct ResponsesCard: View {
    @State private var status = 200
    @State private var retryAfter = ""
    @State private var delayMs = "0"
    @State private var mode = "normal"

    var body: some View {
        SectionCard("Batch responses", "How the server answers the SDK's uploads, to see Retry 1 to 5 at work.") {
            ChoiceChips(options: [200, 400, 401, 403, 404, 408, 413, 422, 429, 500, 501, 503], selected: $status) { String($0) }
            Field("Retry-After (seconds)", $retryAfter, supporting: "Empty for none; used with 429 and 503")
            Field("Delay (ms)", $delayMs, supporting: "Over 20 000 the SDK times out")
            ChoiceChips(options: ["normal", "redirect", "drop"], selected: $mode) { $0 }
            Flow {
                PrimaryButton("Apply") {
                    Task {
                        await attempt {
                            _ = try await DemoApp.shared.backend.control("?status=\(status)&retry_after=\(retryAfter)&delay_ms=\(Int(delayMs) ?? 0)&mode=\(mode)")
                            Calls.show("The server now answers \(status) (\(mode))")
                        }
                    }
                }
                OutlineButton("Reset to 200") {
                    Task {
                        await attempt {
                            _ = try await DemoApp.shared.backend.reset()
                            status = 200
                            retryAfter = ""
                            delayMs = "0"
                            mode = "normal"
                            Calls.show("The server answers 200 again")
                        }
                    }
                }
            }
            Expect("5xx, 408, timeouts and drop: kept, backoff 2 s, 10 s, 30 s… 429, or 503 with Retry-After: pause as asked. 400, 422: deleted as rejected.")
            Expect("401, 403, 404, 413, 501, redirect: kept, paused for an hour, one ERROR. A restart or a new flush does not end a pause.")
        }
    }
}

private struct RemoteConfigCard: View {
    @State private var enabled = true
    @State private var off: Set<Autocapture> = []
    @State private var flushAt = ""
    @State private var flushInterval = ""
    @State private var sampleRate = ""
    @State private var diagnosticsRate = ""
    @State private var current = "…"

    private var apiKey: String { DemoApp.shared.settings.apiKey }

    var body: some View {
        SectionCard("Remote configuration", "GET /v1/config for \(apiKey) (Configuration 1). It only restricts; saved values apply at the next launch.") {
            SwitchRow("enabled", $enabled, "Off is the kill switch: collection and upload stop at once, in the running process")
            Text("autocapture_off").font(.subheadline)
            MultiChips(options: Autocapture.allCases, selected: $off) { wire($0) }
            Expect("network_requests stops at once; the others from the next launch.")
            Field("flush_at", $flushAt, supporting: "1 to 100, never below the app's value")
            Field("flush_interval_ms", $flushInterval, supporting: "1000 to 600000, never below the app's value")
            Field("sample_rate", $sampleRate, supporting: "0 to 1, by deviceId")
            Field("diagnostics_sample_rate", $diagnosticsRate, supporting: "0 to 1")
            Flow {
                PrimaryButton("Save") {
                    var json: [String: Any] = ["enabled": enabled]
                    if !off.isEmpty { json["autocapture_off"] = Autocapture.allCases.filter { off.contains($0) }.map(wire) }
                    if let v = Int(flushAt) { json["flush_at"] = v }
                    if let v = Int(flushInterval) { json["flush_interval_ms"] = v }
                    if let v = Double(sampleRate) { json["sample_rate"] = v }
                    if let v = Double(diagnosticsRate) { json["diagnostics_sample_rate"] = v }
                    Task {
                        await attempt {
                            _ = try await DemoApp.shared.backend.saveRemoteConfig(key: apiKey, json: json)
                            await refresh()
                            Calls.show("Saved on the server; the SDK reads it at the next launch")
                        }
                    }
                }
                TonalButton("Kill switch") {
                    Task {
                        await attempt {
                            _ = try await DemoApp.shared.backend.saveRemoteConfig(key: apiKey, json: ["enabled": false])
                            await refresh()
                            Calls.show("Kill switch saved; reopen the app to let the SDK read it")
                        }
                    }
                }
                OutlineButton("Delete") {
                    Task {
                        await attempt {
                            _ = try await DemoApp.shared.backend.deleteRemoteConfig(key: apiKey)
                            await refresh()
                            Calls.show("Deleted: /v1/config answers 404")
                        }
                    }
                }
            }
            CodeLine(current)
        }
        .task { await refresh() }
    }

    /// The wire name of an autocapture type: snake_case, as the remote configuration spells it.
    private func wire(_ type: Autocapture) -> String {
        var out = ""
        for ch in name(type) {
            if ch.isUppercase { out += "_" + ch.lowercased() } else { out.append(ch) }
        }
        return out
    }

    private func refresh() async {
        await attempt {
            let response = try await DemoApp.shared.backend.remoteConfig(key: apiKey)
            guard response.code == 200, let json = try JSONSerialization.jsonObject(with: Data(response.body.utf8)) as? [String: Any] else {
                current = "none (the server answers 404)"
                enabled = true
                off = []
                flushAt = ""
                flushInterval = ""
                sampleRate = ""
                diagnosticsRate = ""
                return
            }
            current = FakeBackend.pretty(json)
            enabled = json["enabled"] as? Bool ?? true
            let names = json["autocapture_off"] as? [String] ?? []
            off = Set(Autocapture.allCases.filter { names.contains(wire($0)) })
            flushAt = (json["flush_at"] as? Int).map(String.init) ?? ""
            flushInterval = (json["flush_interval_ms"] as? Int).map(String.init) ?? ""
            sampleRate = (json["sample_rate"] as? Double).map { String($0) } ?? ""
            diagnosticsRate = (json["diagnostics_sample_rate"] as? Double).map { String($0) } ?? ""
        }
    }
}

private struct ReceivedEventsCard: View {
    @State private var events: [ServerEvent] = []
    @State private var open: Int?

    var body: some View {
        SectionCard("Received events", "What the server stored, newest first, exactly as the SDK sent it. Tap one for its JSON.") {
            Flow {
                PrimaryButton("Refresh") { Task { await refresh() } }
                OutlineButton("Clear") {
                    Task {
                        await attempt {
                            _ = try await DemoApp.shared.backend.clearEvents()
                            events = []
                        }
                    }
                }
            }
            KeyValueLine("events", String(events.count))
            ForEach(events.prefix(150)) { event in
                Divider()
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        StatusPill(event.source, event.source == "auto" ? Theme.teal : Theme.sky)
                        Text(event.label).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("#\(event.index)").font(.caption2).foregroundColor(Theme.muted)
                    }
                    Text(event.type + " · " + event.propertiesLine).font(.caption).foregroundColor(Theme.muted)
                    if open == event.index { CodeLine(event.pretty) }
                }
                .contentShape(Rectangle())
                .onTapGesture { open = open == event.index ? nil : event.index }
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        await attempt { events = try await DemoApp.shared.backend.events().reversed() }
    }
}

private struct RequestsCard: View {
    @State private var requests: [[String: Any]] = []

    var body: some View {
        SectionCard("Requests", "The server's view of each request: status, size, gzip and the headers the SDK sets (HTTP 2, 5).") {
            PrimaryButton("Load the last requests") { Task { await attempt { requests = try await DemoApp.shared.backend.requests() } } }
            ForEach(Array(requests.prefix(60).enumerated()), id: \.offset) { _, r in
                Divider()
                Text("\(r["time"] as? String ?? "")  \(r["method"] as? String ?? "") \(r["path"] as? String ?? "")  →  \(String(describing: r["status"] ?? ""))")
                    .font(.caption.monospaced())
                Text(
                    [
                        (r["note"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        "gzip=\(r["gzip"] as? Bool ?? false), \(r["bytes"] as? Int ?? 0) bytes",
                        r["user_agent"] as? String,
                        (r["if_none_match"] as? String).map { "If-None-Match \($0)" },
                    ].compactMap { $0 }.joined(separator: "\n")
                )
                .font(.caption2).foregroundColor(Theme.muted)
            }
        }
    }
}
