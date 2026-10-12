import Foundation
import Rubicon

/// Ready-made `beforeSend` hooks that show each rule of Public API 4 and iOS Public API 6. They run
/// in this order.
enum HookPreset: String, CaseIterable, Identifiable {
    case maskEmail
    case dropDebugEvents
    case maskResetToken
    case tagAppEvents
    case trapOnHookTest
    case renameAppOpened

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maskEmail: return "Mask email values"
        case .dropDebugEvents: return "Drop \"Debug Event\""
        case .maskResetToken: return "Mask deep link tokens"
        case .tagAppEvents: return "Tag app events"
        case .trapOnHookTest: return "Trap on \"Hook Test\""
        case .renameAppOpened: return "Rename Application Opened"
        }
    }

    var description: String {
        switch self {
        case .maskEmail:
            return "Any event: an email property or trait keeps its key, its value becomes \"***\". Allowed for automatic events too."
        case .dropDebugEvents:
            return "Returns nil for the app's \"Debug Event\": dropped and counted as before_send."
        case .maskResetToken:
            return "Deep Link Opened: /reset-password/<token> becomes /reset-password/:token (Privacy 5b)."
        case .tagAppEvents:
            return "Adds hooked=true to the app's track and screen events (an app event may change freely)."
        case .trapOnHookTest:
            return "Traps for the event \"Hook Test\": on iOS a hook cannot throw, so the process ends on purpose (iOS Public API 6)."
        case .renameAppOpened:
            return "Breaks the rule for automatic events: they are dropped with HOOK_VIOLATION; with debug on, a developer error."
        }
    }

    static func hooks(_ selected: Set<HookPreset>) -> [BeforeSend] {
        allCases.filter { selected.contains($0) }.map { $0.hook }
    }

    private var hook: BeforeSend {
        switch self {
        case .maskEmail:
            return { event in
                if var track = event as? TrackEvent, track.properties["email"] != nil {
                    track.properties["email"] = .string("***")
                    return track
                }
                if var screen = event as? ScreenEvent, screen.properties["email"] != nil {
                    screen.properties["email"] = .string("***")
                    return screen
                }
                if var identify = event as? IdentifyEvent, identify.traits["email"] != nil {
                    identify.traits["email"] = .string("***")
                    return identify
                }
                return event
            }
        case .dropDebugEvents:
            return { event in
                if let track = event as? TrackEvent, track.source == .app, track.name == "Debug Event" { return nil }
                return event
            }
        case .maskResetToken:
            return { event in
                guard var track = event as? TrackEvent, track.name == "Deep Link Opened",
                    case .string(let path)? = track.properties["path"]
                else { return event }
                track.properties["path"] = .string(
                    path.replacingOccurrences(of: #"/reset-password/[^/]+"#, with: "/reset-password/:token", options: .regularExpression))
                return track
            }
        case .tagAppEvents:
            return { event in
                guard event.source == .app else { return event }
                if var track = event as? TrackEvent {
                    track.properties["hooked"] = .bool(true)
                    return track
                }
                if var screen = event as? ScreenEvent {
                    screen.properties["hooked"] = .bool(true)
                    return screen
                }
                return event
            }
        case .trapOnHookTest:
            return { event in
                if let track = event as? TrackEvent, track.name == "Hook Test" { fatalError("A hook trapped on purpose") }
                return event
            }
        case .renameAppOpened:
            return { event in
                if var track = event as? TrackEvent, track.name == "Application Opened" {
                    track.name = "App Opened"
                    return track
                }
                return event
            }
        }
    }
}
