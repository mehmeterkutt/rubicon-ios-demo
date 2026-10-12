import Rubicon
import SwiftUI
import UIKit
import UserNotifications

struct CaptureView: View {
    private var app: DemoApp { DemoApp.shared }
    private var analytics: any Analytics { DemoApp.shared.analytics }
    @State private var results: [ApiCall: String] = [:]

    var body: some View {
        Page {
            SectionCard("Automatic capture", "What the SDK captures by itself (Lifecycle 6); change it in Settings.") {
                Flow {
                    ForEach(Autocapture.allCases, id: \.self) { type in
                        StatusPill(name(type), app.settings.autocaptureSet.contains(type) ? Theme.success : Theme.danger)
                    }
                }
            }
            screens
            deepLinks
            lifecycle
            network
        }
    }

    private var screens: some View {
        SectionCard("Screens", "iOS Lifecycle 1 and 2: one screen view per view controller shown; the tabs send their own with screen() (Settings).") {
            Flow {
                PrimaryButton("ScreenNamed controller") { Navigator.shared.push(ProductViewController()) }
                TonalButton("Class-named controller") { Navigator.shared.push(SettingsViewController()) }
                TonalButton("Plain controller") { Navigator.shared.push(LegacyLink()) }
                TonalButton("SwiftUI page") {
                    Navigator.shared.pushHosted(
                        title: "SwiftUI",
                        Page {
                            SectionCard("A UIHostingController", "Pushed directly, without a UIKit parent: the SDK sends no screen view for it (iOS Lifecycle 2).") {
                                PrimaryButton("Send screen(\"swiftui_page\") myself") {
                                    Calls.run("Sent screen swiftui_page") { DemoApp.shared.analytics.screen("swiftui_page") }
                                }
                            }
                        })
                }
                OutlineButton("System alert") {
                    let alert = UIAlertController(title: "A system alert", message: "No screen view for this.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    Navigator.shared.present(alert)
                }
                OutlineButton("Permission dialog") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
                        Task { @MainActor in Calls.show(granted ? "Granted: home did not appear again" : "Denied: home did not appear again") }
                    }
                }
            }
            Expect("product_detail (ScreenNamed), Settings (class), LegacyLink (class), nothing for the SwiftUI page; back here: home again.")
            Expect("An alert or a permission dialog over this screen: no second home. Rotate the device: no new screen view either.")
        }
    }

    private var deepLinks: some View {
        SectionCard("Deep links", "Privacy 5b, iOS Lifecycle 3: scheme, host, path, utm_* and the referrer only. .deepLinks is off by default in the SDK, on in this demo.") {
            Flow {
                PrimaryButton("Campaign link") { open("rubicon://open/promo?utm_source=newsletter&utm_campaign=fall&token=secret#top") }
                TonalButton("Token in path") { open("rubicon://open/reset-password/abc123?utm_medium=email") }
                TonalButton("Legacy host") { open("rubicon://legacy/offer?utm_content=banner") }
                TonalButton("Universal link (simulated)") {
                    let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
                    activity.webpageURL = URL(string: "https://www.example.com/landing?utm_source=web&session=private")
                    activity.referrerURL = URL(string: "https://news.example.org/story")
                    Calls.run("trackDeepLink(userActivity)") { analytics.trackDeepLink(activity) }
                }
            }
            Expect("The scheme links go out through UIApplication.open and come back through the scene delegate's openURLContexts, as from another app. Never token, never #top.")
            Expect("Token in path: the mask hook turns it into /reset-password/:token. Universal link: the referrer is the linking page's host.")
            Text("From a terminal, with the app closed (cold start); iOS asks \"Open in Rubicon?\" for a link from another process:").font(.caption).foregroundColor(Theme.muted)
            CodeLine("xcrun simctl openurl booted \"rubicon://open/promo?utm_source=terminal&secret=1\"")
        }
    }

    private func open(_ text: String) {
        guard let url = URL(string: text) else { return }
        UIApplication.shared.open(url) { ok in if !ok { Calls.show("The system refused the link") } }
    }

    private var lifecycle: some View {
        SectionCard("Lifecycle, sessions and the process", "Lifecycle 1, 2 and 4; Session 3 to 6; iOS Session 1. Session timeout: \(app.settings.sessionTimeoutMs / 1000) s.") {
            Expect("Home: Application Backgrounded and an upload inside the background task. Back: Application Opened (from_background true), same session within the timeout; after it: Session Ended (backdated) and a new session.")
            Expect("First launch: Application Installed. A build with a higher CFBundleVersion over it: Application Updated with the previous version.")
            Flow {
                OutlineButton("Track, then kill") {
                    analytics.track("Before Kill", properties: ["note": "stored, then the process dies"])
                    kill(getpid(), SIGKILL)
                }
                OutlineButton("300 events, kill at once") {
                    for i in 0..<300 { analytics.track("Killed While Writing", properties: ["index": i]) }
                    kill(getpid(), SIGKILL)
                }
                OutlineButton("Quit (exit 0)") { exit(0) }
            }
            Expect("After a kill, open the app again: everything stored arrives once; events still in memory at the kill are lost (Queue 1).")
            Text("Offline and online: airplane mode on a device. On the simulator stop the fake server instead (a connect failure, with backoff).").font(.caption).foregroundColor(Theme.muted)
            CodeLine("xcrun simctl terminate booted com.rubicon.demo\nxcrun simctl launch booted com.rubicon.demo")
        }
    }

    private var network: some View {
        SectionCard("HTTP calls", "iOS Lifecycle 5: the app's own URLSession with a delegate that forwards to RubiconNetworkObserver; Network Request events appear on the Logs and Server tabs.") {
            KeyValueLine("API base", app.settings.apiBase)
            KeyValueLine("captured hosts", app.settings.captureHosts.isEmpty ? "none" : app.settings.captureHosts.joined(separator: ", "))
            KeyValueLine("mask path ids", app.settings.maskPathIds ? "true" : "false")
            Text("The API calls go to localhost, another name for the fake server, because the SDK's own host (127.0.0.1) is never captured.").font(.caption).foregroundColor(Theme.muted)
            ForEach(ApiCall.allCases) { call in
                VStack(alignment: .leading, spacing: 2) {
                    OutlineButton(call.title) {
                        results[call] = "running…"
                        Task {
                            let result = await app.api.run(call)
                            await MainActor.run { results[call] = result }
                        }
                    }
                    Expect(call.expectation)
                    if let result = results[call] { Text(result).font(.caption2).foregroundColor(Theme.sky) }
                }
            }
        }
    }
}
