import Foundation
import Rubicon

/// Everything the demo can set on the SDK, plus its own. The SDK's configuration is a value read
/// once at `make`, so these are saved and applied at the next launch (Settings > Save).
struct DemoSettings: Codable, Equatable {
    var apiKey = "rk_demo"
    var host = "http://127.0.0.1:8080"
    /// Off by default: with it on, a developer's mistake traps the process (iOS Configuration 2).
    var debug = false
    var logLevel = "debug"
    /// Send the SDK's log lines to the Logs tab as well; off uses the SDK's unified-log sink.
    var inAppLogger = true
    var sendDiagnostics = true
    var flushAt = 30
    var flushIntervalMs: Int64 = 60_000
    var immediateEvents: [String] = ["Purchase Completed"]
    var sessionTimeoutMs: Int64 = 300_000
    var autocapture: [String] = Autocapture.allCases.map(name)
    var disabledFields: [String] = []
    var defaultConsentName = "granted"
    var persistConsent = true
    var headers: [String: String] = ["X-Demo-Client": "rubicon-demo"]
    var hooks: [String] = [HookPreset.maskEmail, .dropDebugEvents, .maskResetToken].map(\.rawValue)
    /// The app's own HTTP calls: another name for the fake backend, see the README.
    var apiBase = "http://localhost:8080"
    var captureHosts: [String] = ["localhost"]
    var maskPathIds = true
    /// Each tab sends `screen("tab_<name>")`; the home view controller's own screen view stays automatic.
    var tabScreens = true

    // MARK: - Typed views of the stored names

    var level: LogLevel { LogLevel.allCases.first { name($0) == logLevel } ?? .debug }
    var defaultConsent: Consent { Consent.allCases.first { name($0) == defaultConsentName } ?? .granted }
    var autocaptureSet: Set<Autocapture> { Set(Autocapture.allCases.filter { autocapture.contains(name($0)) }) }
    var disabledFieldSet: Set<ContextField> { Set(ContextField.allCases.filter { disabledFields.contains(name($0)) }) }
    var hookSet: Set<HookPreset> { Set(hooks.compactMap(HookPreset.init(rawValue:))) }

    func configuration(observer: @escaping EventObserver, logger: @escaping RubiconLogger) -> AnalyticsConfiguration {
        var c = AnalyticsConfiguration(apiKey: apiKey)
        c.host = host
        c.debug = debug
        c.beforeSend = HookPreset.hooks(hookSet)
        c.flush.at = flushAt
        c.flush.intervalMs = flushIntervalMs
        c.flush.immediateEvents = Set(immediateEvents)
        c.session.backgroundTimeoutMs = sessionTimeoutMs
        c.autocapture.enabled = autocaptureSet
        c.context.disabledFields = disabledFieldSet
        c.privacy.defaultConsent = defaultConsent
        c.privacy.persistConsent = persistConsent
        c.logging.level = level
        c.logging.sendDiagnostics = sendDiagnostics
        c.logging.eventObserver = observer
        if inAppLogger { c.logging.logger = logger }
        c.network.headers = headers
        return c
    }

    // MARK: - Storage

    private static let key = "demo_settings"

    static func load() -> DemoSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(DemoSettings.self, from: data)
        else { return DemoSettings() }
        return settings
    }

    static func save(_ settings: DemoSettings) {
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: key) }
        // The process may end right after.
        UserDefaults.standard.synchronize()
    }
}

/// The stored name of an SDK enum case: its Swift case name.
func name<E>(_ value: E) -> String { String(describing: value) }
