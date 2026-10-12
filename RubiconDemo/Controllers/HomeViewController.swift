import Combine
import Rubicon
import SwiftUI
import UIKit

/// The home screen, named by `ScreenNamed` (screen view `home`, `name_source: annotation`). It hosts
/// the SwiftUI tabs as a child hosting controller, which the SDK skips, so one screen view per visit.
final class HomeViewController: UIViewController, ScreenNamed {
    static let screenName = "home"

    private let hosting = UIHostingController(rootView: RootView())
    private var subscriptions: Set<AnyCancellable> = []
    private let subtitle = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Theme.paper)
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

        let title = UILabel()
        title.text = "Rubicon"
        title.font = .boldSystemFont(ofSize: 17)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = UIColor(Theme.muted)
        let stack = UIStackView(arrangedSubviews: [title, subtitle])
        stack.axis = .vertical
        stack.alignment = .center
        navigationItem.titleView = stack
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(openSettings))

        let app = DemoApp.shared
        app.feed.$counts.combineLatest(app.person.$person)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] counts, person in
                self?.subtitle.text =
                    app.startupNote != nil
                    ? "SDK disabled"
                    : "\(counts.queued) queued · \(counts.sent) sent · \(counts.droppedTotal) dropped · \(person.userId ?? "anonymous")"
            }
            .store(in: &subscriptions)
    }

    @objc private func openSettings() {
        Navigator.shared.push(SettingsViewController())
    }
}
