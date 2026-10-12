import Foundation

/// A received event, as the fake server stored it.
struct ServerEvent: Identifiable {
    let index: Int
    let json: [String: Any]

    var id: Int { index }
    var label: String { (json["event"] as? String) ?? (json["name"] as? String) ?? (json["type"] as? String) ?? "?" }
    var type: String { json["type"] as? String ?? "" }
    var source: String { json["source"] as? String ?? "" }
    var pretty: String { FakeBackend.pretty(json) }
    var propertiesLine: String {
        guard let properties = json["properties"] as? [String: Any] ?? json["traits"] as? [String: Any] else { return "" }
        let text = FakeBackend.compact(properties)
        return text.count > 120 ? String(text.prefix(120)) + "…" : text
    }
}

/// Talks to the fake backend's control endpoints (`fake-server/server.py`), separately from the
/// SDK: the SDK's own requests are what is being tested. A plain session without a delegate, so the
/// observer never sees these calls either.
final class FakeBackend {
    struct Response {
        let code: Int
        let body: String
    }

    struct Unreachable: Error, CustomStringConvertible {
        let description: String
    }

    private let base: String
    private let session: URLSession

    init(base: String) {
        self.base = base.hasSuffix("/") ? String(base.dropLast()) : base
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        session = URLSession(configuration: configuration)
    }

    func control(_ query: String = "") async throws -> Response { try await call("GET", "/control\(query)") }
    func reset() async throws -> Response { try await call("GET", "/control/reset") }
    func remoteConfig(key: String) async throws -> Response { try await call("GET", "/control/config?key=\(key)") }
    func saveRemoteConfig(key: String, json: [String: Any]) async throws -> Response {
        try await call("POST", "/control/config?key=\(key)", body: try JSONSerialization.data(withJSONObject: json))
    }
    func deleteRemoteConfig(key: String) async throws -> Response { try await call("DELETE", "/control/config?key=\(key)") }
    func clearEvents() async throws -> Response { try await call("GET", "/events/clear") }

    func events() async throws -> [ServerEvent] {
        let response = try await call("GET", "/events")
        guard let array = try JSONSerialization.jsonObject(with: Data(response.body.utf8)) as? [[String: Any]] else { return [] }
        return array.compactMap { item in
            guard let index = item["index"] as? Int, let event = item["event"] as? [String: Any] else { return nil }
            return ServerEvent(index: index, json: event)
        }
    }

    func requests() async throws -> [[String: Any]] {
        let response = try await call("GET", "/requests")
        return (try JSONSerialization.jsonObject(with: Data(response.body.utf8)) as? [[String: Any]]) ?? []
    }

    private func call(_ method: String, _ path: String, body: Data? = nil) async throws -> Response {
        guard let url = URL(string: base + path) else { throw Unreachable(description: "bad URL \(base + path)") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let (data, response) = try await session.data(for: request)
            return Response(code: (response as? HTTPURLResponse)?.statusCode ?? 0, body: String(decoding: data, as: UTF8.self))
        } catch {
            throw Unreachable(description: "\((error as NSError).domain) \((error as NSError).code)")
        }
    }

    static func pretty(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else {
            return "\(object)"
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func compact(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else {
            return "\(object)"
        }
        return String(decoding: data, as: UTF8.self)
    }
}
