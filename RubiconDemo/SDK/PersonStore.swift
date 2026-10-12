import Foundation

/// What the app told the SDK about the user; the SDK has no getter for these (Public API 8).
@MainActor
final class PersonStore: ObservableObject {
    struct Person: Codable, Equatable {
        var userId: String?
        var superProperties: [String: String] = [:]
    }

    @Published private(set) var person: Person

    private static let key = "demo_person"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key), let saved = try? JSONDecoder().decode(Person.self, from: data) {
            person = saved
        } else {
            person = Person()
        }
    }

    func identified(_ userId: String) {
        update { current in
            if let old = current.userId, old != userId { current = Person(userId: userId) } else { current.userId = userId }
        }
    }

    func registered(_ key: String, _ value: Any) { update { $0.superProperties[key] = String(describing: value) } }
    func unregistered(_ key: String) { update { $0.superProperties[key] = nil } }
    func cleared() { update { $0 = Person() } }

    private func update(_ change: (inout Person) -> Void) {
        change(&person)
        if let data = try? JSONEncoder().encode(person) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}
