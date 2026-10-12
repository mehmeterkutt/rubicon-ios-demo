import Rubicon
import SwiftUI
import UIKit

/// Named by `ScreenNamed`: the screen view is `product_detail`, `name_source: annotation`.
final class ProductViewController: UIViewController, ScreenNamed {
    static let screenName = "product_detail"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Product"
        view.backgroundColor = UIColor(Theme.paper)
        embed(
            Page {
                SectionCard("product_detail", "A view controller with ScreenNamed(\"product_detail\").") {
                    PrimaryButton("Track Product Viewed") {
                        Calls.run("Tracked Product Viewed") {
                            DemoApp.shared.analytics.track("Product Viewed", properties: ["sku": "A1", "price": 19.9])
                        }
                    }
                    Expect("Rotate the device: no second screen view. Go back: home is sent again.")
                }
            })
    }
}

/// Named by its class: `Settings`, `name_source: class`. Hosts the SwiftUI settings page.
final class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = UIColor(Theme.paper)
        embed(SettingsView())
    }
}

/// A plain view controller without the `ViewController` suffix in its name: the screen view is `LegacyLink`.
final class LegacyLink: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Legacy"
        view.backgroundColor = UIColor(Theme.paper)
        embed(
            Page {
                SectionCard("LegacyLink", "A plain UIViewController subclass; the SDK names it after its class.") {
                    Expect("The screen view is LegacyLink (name_source class). Go back: home again.")
                }
            })
    }
}

extension UIViewController {
    /// Hosts a SwiftUI view as a child; the hosting controller itself produces no screen view.
    func embed<Content: View>(_ content: Content) {
        let hosting = UIHostingController(rootView: content)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
    }
}
