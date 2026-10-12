import Rubicon
import SwiftUI

enum Tab: String, CaseIterable {
    case events, identity, capture, server, logs

    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var icon: String {
        switch self {
        case .events: return "paperplane"
        case .identity: return "person"
        case .capture: return "hand.tap"
        case .server: return "cloud"
        case .logs: return "list.bullet"
        }
    }
}

/// The five tabs inside the home view controller, with the message banner. A single screen app
/// sends its tabs itself, with fixed names (iOS Lifecycle 2).
struct RootView: View {
    @ObservedObject private var messages = DemoApp.shared.messages
    @ObservedObject private var feed = DemoApp.shared.feed
    @ObservedObject private var person = DemoApp.shared.person
    @State private var tab = Tab.events

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                EventsView().tabItem { Label(Tab.events.label, systemImage: Tab.events.icon) }.tag(Tab.events)
                IdentityView().tabItem { Label(Tab.identity.label, systemImage: Tab.identity.icon) }.tag(Tab.identity)
                CaptureView().tabItem { Label(Tab.capture.label, systemImage: Tab.capture.icon) }.tag(Tab.capture)
                ServerView().tabItem { Label(Tab.server.label, systemImage: Tab.server.icon) }.tag(Tab.server)
                LogsView().tabItem { Label(Tab.logs.label, systemImage: Tab.logs.icon) }.tag(Tab.logs)
            }
            .tint(Theme.sky)
            if let text = messages.current {
                Text(text).font(.footnote).foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.ink.opacity(0.92)).cornerRadius(10).padding(.bottom, 60).padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: messages.current)
        .onChange(of: tab) { newTab in
            if DemoApp.shared.settings.tabScreens { DemoApp.shared.analytics.screen("tab_\(newTab.rawValue)") }
        }
        .onAppear {
            if DemoApp.shared.settings.tabScreens { DemoApp.shared.analytics.screen("tab_\(tab.rawValue)") }
        }
    }

    /// The counters for the navigation bar.
    var summary: String {
        "\(feed.counts.queued) queued · \(feed.counts.sent) sent · \(feed.counts.droppedTotal) dropped · \(person.person.userId ?? "anonymous")"
    }
}
