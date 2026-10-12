import Foundation
import Rubicon

/// The instance before `start` has run; never seen by a screen in practice.
final class DisabledAnalytics: Analytics {
    func track(_ name: String, properties: [String: Any]) {}
    func screen(_ name: String, properties: [String: Any]) {}
    func identify(_ userId: String, traits: [String: Any]) {}
    func reset() {}
    func register(_ key: String, value: Any) {}
    func unregister(_ key: String) {}
    func flush() {}
    func optOut() {}
    func optIn() {}
    var isOptedOut: Bool { true }
    func clearLocalData() {}
    var deviceId: String { "" }
    func trackDeepLink(_ url: URL, referrer: String?) {}
    func trackDeepLink(_ activity: NSUserActivity) {}
}
