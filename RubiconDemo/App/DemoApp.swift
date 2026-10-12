import Foundation
import Rubicon
import UIKit

/// The one instance and everything the screens share: the saved settings, the event feed and the
/// SDK log, what the app told the SDK about the person, the app's own HTTP client and the fake
/// backend's client. Created in `AppDelegate`, read on the main thread.
@MainActor
final class DemoApp {
    static let shared = DemoApp()

    private(set) var settings = DemoSettings()
    private(set) var analytics: any Analytics = DisabledAnalytics()
    private(set) var api: ApiCalls!
    private(set) var backend: FakeBackend!
    let feed = EventFeed()
    let sdkLog = SdkLog()
    let person = PersonStore()
    let messages = Messages()

    /// Set when the SDK gave the no-op instance for the saved configuration (a blank key, an invalid host).
    private(set) var startupNote: String?
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        settings = DemoSettings.load()
        analytics = RubiconAnalytics.make(configuration: settings.configuration(observer: feed.observer, logger: sdkLog.logger))
        if analytics.isOptedOut && analytics.deviceId.isEmpty && settings.defaultConsent == .granted {
            startupNote = "The SDK refused the saved configuration and runs as a no-op (empty deviceId): check the API key and the host."
        }
        api = ApiCalls(analytics: analytics, hosts: settings.captureHosts, maskPathIds: settings.maskPathIds,
                       apiBase: settings.apiBase, sdkHost: settings.host)
        backend = FakeBackend(base: settings.host)
    }

    /// The app does nothing with its links: the SDK captures what Privacy 5b allows.
    func openedURL(_ context: UIOpenURLContext) {
        analytics.trackDeepLink(context.url, referrer: context.options.sourceApplication)
        let shown = context.url.path.isEmpty ? context.url.absoluteString : context.url.path
        messages.show("Deep link received: \(shown)")
        sdkLog.note("deep link received, path \(context.url.path), referrer \(context.options.sourceApplication ?? "none")")
    }

    func continued(_ activity: NSUserActivity) {
        analytics.trackDeepLink(activity)
        messages.show("User activity received: \(activity.activityType)")
        sdkLog.note("user activity received, type \(activity.activityType)")
    }

    /// Saves `next` for the next launch; the SDK reads its configuration once, so the app must be
    /// reopened. `quit` ends the process at once, for a demo only.
    func save(_ next: DemoSettings, quit: Bool) {
        DemoSettings.save(next)
        settings = next
        if quit {
            // Not for a shipping app. The simulator relaunches it with `xcrun simctl launch booted com.rubicon.demo`.
            exit(0)
        }
        messages.show("Saved. Quit the app and open it again to apply.")
    }
}

/// A short message at the bottom of the screen, the counterpart of the Android snackbar.
@MainActor
final class Messages: ObservableObject {
    @Published private(set) var current: String?
    private var hideTask: Task<Void, Never>?

    func show(_ text: String) {
        current = text
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if !Task.isCancelled { self?.current = nil }
        }
    }
}

/// Runs a call to the SDK and reports what was done. With `debug` on the SDK traps on a developer's
/// mistake (the process ends); with it off the mistake is a WARN on the Logs tab.
enum Calls {
    @MainActor
    static func run(_ label: String, _ block: () -> Void) {
        block()
        DemoApp.shared.messages.show(label)
    }

    @MainActor
    static func show(_ text: String) {
        DemoApp.shared.messages.show(text)
    }
}
