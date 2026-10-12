import Rubicon
import SwiftUI

/// Every setting of the SDK (Configuration 2), plus the demo's own. The SDK's configuration is a
/// value read once at `make`, so these are saved and applied when the app is opened again.
struct SettingsView: View {
    @State private var s = DemoApp.shared.settings
    @State private var immediate = DemoApp.shared.settings.immediateEvents.joined(separator: ", ")
    @State private var headers = DemoApp.shared.settings.headers.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    @State private var hosts = DemoApp.shared.settings.captureHosts.joined(separator: ", ")
    @State private var flushAt = String(DemoApp.shared.settings.flushAt)
    @State private var flushInterval = String(DemoApp.shared.settings.flushIntervalMs)
    @State private var sessionTimeout = String(DemoApp.shared.settings.sessionTimeoutMs)
    @State private var autocapture = DemoApp.shared.settings.autocaptureSet
    @State private var disabled = DemoApp.shared.settings.disabledFieldSet
    @State private var hookSet = DemoApp.shared.settings.hookSet
    @State private var consent = DemoApp.shared.settings.defaultConsent
    @State private var level = DemoApp.shared.settings.level

    var body: some View {
        Page {
            SectionCard("Apply", "The SDK reads its configuration once. Save, then quit the app and open it again; that also shows that the SDK keeps its state across a restart.") {
                if let note = DemoApp.shared.startupNote { Text(note).font(.caption).foregroundColor(Theme.danger) }
                Flow {
                    PrimaryButton("Save") { DemoApp.shared.save(collected(), quit: false) }
                    TonalButton("Save and quit") { DemoApp.shared.save(collected(), quit: true) }
                    OutlineButton("Defaults and quit") { DemoApp.shared.save(DemoSettings(), quit: true) }
                }
                CodeLine("xcrun simctl launch booted com.rubicon.demo")
            }
            SectionCard("Connection") {
                Field("API key", $s.apiKey, supporting: "A new key starts a new queue; the old one is dropped as api_key_changed")
                Field("Host", $s.host, supporting: "http:// works with a WARN; an invalid host gives the no-op instance")
                Field("Extra headers", $headers, supporting: "name=value, comma separated; the SDK's own headers cannot be replaced")
                SwitchRow("debug", $s.debug, "On: a developer's mistake traps the process (iOS Configuration 2). Off: a WARN on the Logs tab")
            }
            SectionCard("Logging") {
                ChoiceChips(options: LogLevel.allCases, selected: $level) { name($0) }
                SwitchRow("In-app logger", $s.inAppLogger, "Off: the SDK's unified-log sink, subsystem com.rubicon.analytics")
                SwitchRow("Send SDK Diagnostics", $s.sendDiagnostics, "Counts of drops and issues, at most hourly")
            }
            SectionCard("Flushing and sessions", "Queue 3, Session 4.") {
                Field("flush.at", $flushAt, supporting: "1 to 100; outside is clamped with a WARN")
                Flow { ForEach([1, 30, 100], id: \.self) { v in OutlineButton("at \(v)") { flushAt = String(v) } } }
                Field("flush.intervalMs", $flushInterval, supporting: "1000 to 600000")
                Flow { ForEach([1_000, 60_000, 600_000], id: \.self) { v in OutlineButton("every \(v / 1000) s") { flushInterval = String(v) } } }
                Field("flush.immediateEvents", $immediate, supporting: "Comma separated event names")
                Field("session.backgroundTimeoutMs", $sessionTimeout, supporting: "10000 to 7200000")
                Flow {
                    ForEach([10_000, 60_000, 300_000], id: \.self) { v in
                        OutlineButton("timeout \(v < 60_000 ? "\(v / 1000) s" : "\(v / 60_000) min")") { sessionTimeout = String(v) }
                    }
                }
            }
            SectionCard("Automatic capture", "autocapture.enabled (Lifecycle 6).") {
                MultiChips(options: Autocapture.allCases, selected: $autocapture) { name($0) }
                SwitchRow("Tab screens with screen()", $s.tabScreens, "The tabs send tab_<name>; the home controller's screen stays automatic")
            }
            SectionCard("Context fields switched off", "context.disabledFields: never read, never sent (Context 6).") {
                MultiChips(options: ContextField.allCases, selected: $disabled) { name($0) }
                OutlineButton("Child-directed checklist") { disabled.formUnion([.locale, .timezone, .networkType]) }
            }
            SectionCard("Consent", "Privacy 2 and 4.") {
                ChoiceChips(options: Consent.allCases, selected: $consent) { name($0) }
                SwitchRow("Store the user's choice", $s.persistConsent, "Off: the app owns consent and calls optIn or optOut at every launch")
            }
            SectionCard("beforeSend hooks", "Public API 4, iOS Public API 6.") {
                ForEach(HookPreset.allCases) { hook in
                    SwitchRow(hook.title, Binding(get: { hookSet.contains(hook) }, set: { on in if on { hookSet.insert(hook) } else { hookSet.remove(hook) } }), hook.description)
                }
            }
            SectionCard("Network observer", "RubiconNetworkObserver(analytics:hosts:maskPathIds:) on the app's own URLSession delegate.") {
                Field("API base", $s.apiBase, supporting: "The app's own calls; localhost is the fake server under another name")
                Field("Captured hosts", $hosts, supporting: "Exact names or *.domain.tld, comma separated")
                SwitchRow("Mask ids in paths", $s.maskPathIds)
            }
            SectionCard("This build") {
                KeyValueLine("app version", (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") + ")")
                KeyValueLine("bundle id", Bundle.main.bundleIdentifier ?? "")
                KeyValueLine("SDK version", RubiconAnalytics.version)
                Expect("Install a build with a higher CFBundleVersion over this one to see Application Updated.")
            }
        }
    }

    private func collected() -> DemoSettings {
        var next = s
        next.immediateEvents = immediate.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        next.headers = Dictionary(uniqueKeysWithValues: headers.split(separator: ",").compactMap { pair -> (String, String)? in
            let parts = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            return parts.count == 2 && !parts[0].isEmpty ? (parts[0], parts[1]) : nil
        })
        next.captureHosts = hosts.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        next.flushAt = Int(flushAt) ?? s.flushAt
        next.flushIntervalMs = Int64(flushInterval) ?? s.flushIntervalMs
        next.sessionTimeoutMs = Int64(sessionTimeout) ?? s.sessionTimeoutMs
        next.autocapture = Autocapture.allCases.filter { autocapture.contains($0) }.map(name)
        next.disabledFields = ContextField.allCases.filter { disabled.contains($0) }.map(name)
        next.hooks = HookPreset.allCases.filter { hookSet.contains($0) }.map(\.rawValue)
        next.defaultConsentName = name(consent)
        next.logLevel = name(level)
        return next
    }
}
