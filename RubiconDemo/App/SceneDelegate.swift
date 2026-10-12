import UIKit

/// Builds the window for the one scene and forwards the links the app receives to the SDK.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let navigation = UINavigationController(rootViewController: HomeViewController())
        navigation.navigationBar.prefersLargeTitles = false
        Navigator.shared.navigation = navigation
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigation
        window.tintColor = UIColor(Theme.sky)
        window.makeKeyAndVisible()
        self.window = window
        // A link that launched the app (cold start) arrives here, not in openURLContexts.
        for context in connectionOptions.urlContexts { DemoApp.shared.openedURL(context) }
        for activity in connectionOptions.userActivities { DemoApp.shared.continued(activity) }
    }

    /// A URL scheme link (`rubicon://...`) while the app runs or from the background.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts { DemoApp.shared.openedURL(context) }
    }

    /// A universal link, as an `NSUserActivity` of type `NSUserActivityTypeBrowsingWeb`.
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        DemoApp.shared.continued(userActivity)
    }
}
