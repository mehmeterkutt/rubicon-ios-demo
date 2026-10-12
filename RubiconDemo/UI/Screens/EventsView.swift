import Foundation
import Rubicon
import SwiftUI

private enum Tier { case gold, silver }

private enum PropertyType: String, CaseIterable { case text, int, int64, double, bool, null, date, list, map }

private struct PropertyRow: Identifiable {
    let id = UUID()
    var key: String
    var type: PropertyType
    var value: String

    var anyValue: Any {
        switch type {
        case .text: return value
        case .int: return Int(value.trimmingCharacters(in: .whitespaces)) ?? 0
        case .int64: return Int64(value.trimmingCharacters(in: .whitespaces)) ?? 0
        case .double: return Double(value.trimmingCharacters(in: .whitespaces)) ?? 0
        case .bool: return value.trimmingCharacters(in: .whitespaces).lowercased() == "true"
        case .null: return NSNull()
        case .date: return Date()
        case .list: return value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        case .map:
            var map: [String: Any] = [:]
            for pair in value.split(separator: ",") {
                let parts = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 { map[parts[0]] = parts[1] }
            }
            return map
        }
    }
}

struct EventsView: View {
    private var analytics: any Analytics { DemoApp.shared.analytics }
    private var settings: DemoSettings { DemoApp.shared.settings }

    var body: some View {
        Page {
            quick
            builder
            valueTypes
            validation
            volume
            hooks
        }
    }

    private var quick: some View {
        SectionCard("Quick events", "Watch them on the Logs tab (queued, then sent) and on the Server tab (as received).") {
            Flow {
                PrimaryButton("Track") { Calls.run("Tracked Button Clicked") { analytics.track("Button Clicked", properties: ["button": "quick"]) } }
                TonalButton("Screen") { Calls.run("Sent screen manual_screen") { analytics.screen("manual_screen", properties: ["origin": "events_tab"]) } }
                TonalButton("Purchase") {
                    Calls.run("Tracked Purchase Completed") {
                        analytics.track("Purchase Completed", properties: ["amount": 9.99, "currency": "USD", "items": 2])
                    }
                }
                OutlineButton("Flush") { Calls.run("Flush requested") { analytics.flush() } }
            }
            Expect(
                settings.immediateEvents.contains("Purchase Completed")
                    ? "Purchase Completed is an immediate event: it is uploaded as soon as it is stored."
                    : "Immediate events: \(settings.immediateEvents.isEmpty ? "none" : settings.immediateEvents.joined(separator: ", ")) (Settings).")
        }
    }

    @State private var name = "Feature Used"
    @State private var rows: [PropertyRow] = [
        PropertyRow(key: "feature", type: .text, value: "search"),
        PropertyRow(key: "count", type: .int, value: "3"),
        PropertyRow(key: "premium", type: .bool, value: "true"),
    ]

    private var builder: some View {
        SectionCard("Build an event", "Any name and typed properties; date is now, list is comma separated, map is k=v pairs.") {
            Field("Name", $name)
            ForEach($rows) { $row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("Key", text: $row.key).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                        if row.type != .null && row.type != .date {
                            TextField("Value", text: $row.value).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                        }
                        Button { rows.removeAll { $0.id == row.id } } label: { Image(systemName: "xmark.circle") }
                    }
                    ChoiceChips(options: PropertyType.allCases, selected: $row.type) { $0.rawValue }
                }
            }
            Button("Add property") { rows.append(PropertyRow(key: "key\(rows.count + 1)", type: .text, value: "")) }.font(.subheadline)
            Flow {
                PrimaryButton("Send as track") { Calls.run("Tracked \(name)") { analytics.track(name, properties: properties()) } }
                TonalButton("Send as screen") { Calls.run("Sent screen \(name)") { analytics.screen(name, properties: properties()) } }
            }
        }
    }

    private func properties() -> [String: Any] {
        var result: [String: Any] = [:]
        for row in rows { result[row.key] = row.anyValue }
        return result
    }

    private var valueTypes: some View {
        SectionCard("Every value type", "iOS Serialization 2: what the SDK accepts and how it converts it.") {
            PrimaryButton("Track every allowed type") {
                Calls.run("Tracked All Types") {
                    analytics.track(
                        "All Types",
                        properties: [
                            "string": "text",
                            "int": 42,
                            "int64": Int64(9_007_199_254_740_993),
                            "float": Float(1.1),
                            "double": 2.5,
                            "decimal": Decimal(string: "12.75") ?? 0,
                            "bool": true,
                            "null": NSNull(),
                            "nsnumber_bool": NSNumber(value: true),
                            "nsnumber_int": NSNumber(value: 1),
                            "character": Character("x"),
                            "date": Date(timeIntervalSince1970: 0),
                            "url": URL(string: "https://example.com/a?b=1")!,
                            "enum": Tier.gold,
                            "list": ["a", 1, NSNull(), [true]],
                            "set": Set(["x", "y"]),
                            "map": ["level1": ["level2": ["level3": "deepest allowed"]]],
                            "unicode": "ğüşİıöç 日本 😀",
                        ])
                }
            }
            Expect("Float 1.1 and Decimal through their decimal text, Character as text, Date as 1970-01-01T00:00:00.000Z, URL as its string, enum as gold, the set as a list; NSNumber(true) stays a boolean and NSNumber(1) a number.")
        }
    }

    private var validation: some View {
        SectionCard("Validation", "Each one breaks a rule. With debug off (Settings): a WARN and the bad part dropped (Logs tab). With debug on: the SDK traps.") {
            caseButton("Unsupported value types", "A struct, Data, a closure, NaN, infinity: each drops its own key; kept stays") {
                struct Opaque {}
                let values: [String: Any] = [
                    "struct": Opaque(), "data": Data([1, 2, 3]), "closure": { () -> Void in }, "nan": Double.nan,
                    "infinity": Double.infinity, "kept": "this one stays",
                ]
                analytics.track("Bad Values", properties: values)
            }
            caseButton("Bad keys", "A blank key and a nested dictionary with a number as key") {
                analytics.track("Bad Keys", properties: [" ": 1, "nested": [1: "x", "ok": 2] as [AnyHashable: Any], "kept": true])
            }
            caseButton("Nesting deeper than 3", "Three dictionaries inside a property are allowed; the fourth is dropped, so c arrives empty") {
                analytics.track("Too Deep", properties: ["a": ["b": ["c": ["d": ["e": "too deep"]]]]])
            }
            caseButton("A string over 1024 characters", "Cut at 1024 on a character, WARN, never a trap") {
                analytics.track("Long Text", properties: ["text": String(repeating: "é", count: 1500)])
            }
            caseButton("300 properties", "Over 256: the rest is dropped, super properties first") {
                var many: [String: Any] = [:]
                for i in 1...300 { many["p\(i)"] = i }
                analytics.track("Many Properties", properties: many)
            }
            caseButton("A name of 256 characters", "Dropped, never trimmed (INVALID_EVENT_NAME)") { analytics.track(String(repeating: "N", count: 256)) }
            caseButton("A blank name", "Dropped (INVALID_EVENT_NAME)") { analytics.track("   ") }
            caseButton("An event over 32 KB", "Stored as one line over 32 KB: dropped as oversize") {
                var huge: [String: Any] = [:]
                for i in 1...40 { huge["chunk\(i)"] = String(repeating: "x", count: 1000) }
                analytics.track("Huge Event", properties: huge)
            }
            caseButton("An unpaired surrogate", "An NSString with a lone surrogate is bridged with U+FFFD") {
                let lone = NSString(characters: [0x61, 0xD800, 0x62], length: 3) as String
                analytics.track("Broken Text", properties: ["text": lone])
            }
            caseButton("Change a mutable value after track", "The SDK copies on the calling thread: the server sees before") {
                let list = NSMutableArray(array: ["before"])
                analytics.track("Copied Value", properties: ["list": list])
                list.add("after")
            }
        }
    }

    private func caseButton(_ title: String, _ expectation: String, _ block: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            OutlineButton(title) { Calls.run(title) { block() } }
            Expect(expectation)
        }
    }

    private var volume: some View {
        SectionCard("Volume and threads", "Queue 1, 3 and 5. Set the server to 503 first to see the queue fill up.") {
            Flow {
                OutlineButton("Checkout funnel") {
                    Calls.run("Funnel tracked") {
                        for (i, step) in ["Product Viewed", "Add To Cart", "Checkout Started", "Payment Submitted", "Order Completed"].enumerated() {
                            analytics.track(step, properties: ["step": i + 1, "order_id": "ord-1001"])
                        }
                    }
                }
                OutlineButton("Burst 50") { Calls.run("50 events") { for i in 0..<50 { analytics.track("Burst Event", properties: ["index": i]) } } }
                OutlineButton("1200 events") { Calls.run("1200 events") { for i in 0..<1200 { analytics.track("Queue Filler", properties: ["index": i]) } } }
                OutlineButton("8 threads × 200") {
                    Calls.run("8 threads started") {
                        let analytics = self.analytics
                        for t in 0..<8 {
                            Thread { for i in 0..<200 { analytics.track("Thread Event", properties: ["thread": t, "index": i]) } }.start()
                        }
                    }
                }
            }
            Expect("1200 at once can overflow the write channel (backpressure); 1200 waiting events exceed the queue of 1000 (queue_full, down to 900).")
            Expect("Per thread, events keep their order: check the index on the Server tab.")
        }
    }

    private var hooks: some View {
        let active = settings.hookSet
        return SectionCard("beforeSend hooks", "Active: \(active.isEmpty ? "none" : HookPreset.allCases.filter { active.contains($0) }.map(\.title).joined(separator: ", ")) (Settings).") {
            Flow {
                OutlineButton("Debug Event") { Calls.run("Tracked Debug Event") { analytics.track("Debug Event", properties: ["note": "should be dropped"]) } }
                OutlineButton("Hook Test") { Calls.run("Tracked Hook Test") { analytics.track("Hook Test") } }
                OutlineButton("Event with email") {
                    Calls.run("Tracked Signed Up") { analytics.track("Signed Up", properties: ["email": "ada@example.com", "plan": "pro"]) }
                }
            }
            Expect(
                [
                    active.contains(.dropDebugEvents) ? "Debug Event: dropped as before_send." : "Debug Event: sent (its hook is off).",
                    active.contains(.trapOnHookTest) ? "Hook Test: the hook traps and the app ends." : "Hook Test: sent (turn on \"Trap on Hook Test\" in Settings to see the trap).",
                    active.contains(.maskEmail) ? "Email: the value arrives as ***." : "Email: sent as is (its hook is off).",
                ].joined(separator: " "))
        }
    }
}
