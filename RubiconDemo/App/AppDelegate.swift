import UIKit

/// Creates the SDK the way an app should: once, during launch, on the main thread, from the saved
/// settings. The window belongs to the scene delegate (the scene lifecycle is mandatory for apps
/// built with the iOS 27 SDK).
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        DemoApp.shared.start()
        return true
    }
}
