import Rubicon
import SwiftUI

struct IdentityView: View {
    @ObservedObject private var store = DemoApp.shared.person
    @State private var deviceId = ""
    @State private var optedOut = false
    @State private var userId = "user-42"
    @State private var traits = "plan=pro, email=ada@example.com"
    @State private var key = "plan"
    @State private var value = "pro"
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var analytics: any Analytics { DemoApp.shared.analytics }
    private var settings: DemoSettings { DemoApp.shared.settings }

    var body: some View {
        Page {
            SectionCard("This installation", "deviceId is read-only; it changes only with clearLocalData (iOS Identity 1, Privacy 3).") {
                KeyValueLine("user (as told to the SDK)", store.person.userId ?? "anonymous")
                CodeLine(deviceId.isEmpty ? "SDK disabled" : deviceId)
            }
            SectionCard("Identify", "Identity 3 and 4: traits are sent once, with the identify event, and never stored.") {
                Field("User id", $userId)
                Field("Traits", $traits, supporting: "key=value, comma separated")
                Flow {
                    PrimaryButton("Identify") {
                        Calls.run("identify(\(userId))") {
                            analytics.identify(userId, traits: parse(traits))
                            store.identified(userId)
                        }
                    }
                    TonalButton("Without traits") {
                        Calls.run("identify(\(userId)) without traits") {
                            analytics.identify(userId)
                            store.identified(userId)
                        }
                    }
                    OutlineButton("Reset") {
                        Calls.run("reset()") {
                            analytics.reset()
                            store.cleared()
                        }
                    }
                    OutlineButton("Blank id") { Calls.run("identify with a blank id") { analytics.identify("  ") } }
                }
                Expect("Same id again without traits: nothing. Another id while identified: Session Ended for the old user, a new person, no warning.")
                Expect("Reset: the user, super properties and session go; deviceId stays; no event.")
            }
            SectionCard("Super properties", "Context 5: merged into every later event; the event's own key wins. Stored with the person.") {
                HStack {
                    Field("Key", $key)
                    Field("Value", $value)
                }
                Flow {
                    PrimaryButton("Register") {
                        Calls.run("register(\(key))") {
                            analytics.register(key, value: value)
                            store.registered(key, value)
                        }
                    }
                    TonalButton("Register null") {
                        Calls.run("register(\(key), NSNull)") {
                            analytics.register(key, value: NSNull())
                            store.registered(key, "null")
                        }
                    }
                    OutlineButton("Unregister") {
                        Calls.run("unregister(\(key))") {
                            analytics.unregister(key)
                            store.unregistered(key)
                        }
                    }
                }
                if store.person.superProperties.isEmpty {
                    Expect("None registered.")
                } else {
                    ForEach(store.person.superProperties.sorted { $0.key < $1.key }, id: \.key) { KeyValueLine($0.key, $0.value) }
                }
            }
            SectionCard("Privacy", "Privacy 1 to 4.") {
                Flow {
                    StatusPill(optedOut ? "not sending" : "sending", optedOut ? Theme.warning : Theme.success)
                    StatusPill("default consent \(settings.defaultConsentName)", settings.defaultConsent == .pending ? Theme.warning : Theme.success)
                    if !settings.persistConsent { StatusPill("choice not stored", Theme.danger) }
                }
                Flow {
                    PrimaryButton("Opt in") { Calls.run("optIn()") { analytics.optIn() } }
                    TonalButton("Opt out") { Calls.run("optOut()") { analytics.optOut() } }
                    OutlineButton("Clear local data") {
                        Calls.run("clearLocalData()") {
                            analytics.clearLocalData()
                            store.cleared()
                        }
                    }
                    OutlineButton("Forget me") {
                        let old = analytics.deviceId
                        Calls.run("Forgotten; erase \(old) on the server") {
                            analytics.optOut()
                            analytics.clearLocalData()
                            store.cleared()
                        }
                    }
                }
                Expect("Opt out: nothing new of any kind, the open session ends silently, queued events are still sent. Opt in: resumes, no event.")
                Expect("While pending (Settings): events are stored, not sent; opt in sends them, opt out deletes them.")
                Expect("Clear local data: deletes queued events and the person, renews deviceId, keeps the consent choice.")
            }
        }
        .onReceive(timer) { _ in
            deviceId = analytics.deviceId
            optedOut = analytics.isOptedOut
        }
    }

    private func parse(_ text: String) -> [String: Any] {
        var result: [String: Any] = [:]
        for pair in text.split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[0].isEmpty else { continue }
            if let i = Int(parts[1]) { result[parts[0]] = i } else if let d = Double(parts[1]) { result[parts[0]] = d } else if parts[1] == "true" || parts[1] == "false" { result[parts[0]] = parts[1] == "true" } else { result[parts[0]] = parts[1] }
        }
        return result
    }
}
