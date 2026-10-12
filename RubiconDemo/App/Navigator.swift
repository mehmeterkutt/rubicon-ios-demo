import SwiftUI
import UIKit

/// The UIKit navigation stack behind the SwiftUI tabs: the screens the SDK names automatically are
/// view controllers (iOS Lifecycle 1, 2), so the SwiftUI buttons push them through here.
@MainActor
final class Navigator {
    static let shared = Navigator()
    weak var navigation: UINavigationController?

    func push(_ controller: UIViewController) {
        navigation?.pushViewController(controller, animated: true)
    }

    /// A SwiftUI page pushed as a plain `UIHostingController`: the SDK sends no screen view for it.
    func pushHosted<Content: View>(title: String, _ content: Content) {
        let controller = UIHostingController(rootView: content)
        controller.title = title
        push(controller)
    }

    func present(_ controller: UIViewController) {
        navigation?.present(controller, animated: true)
    }
}
