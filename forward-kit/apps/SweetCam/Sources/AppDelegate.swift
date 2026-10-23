// SweetCam app entry point. STATUS: real source, NOT compiled or run.
// Classic (non-scene) window setup so no scene manifest / storyboard is required for bring-up.

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions
                     launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = CameraViewController()
        w.makeKeyAndVisible()
        window = w
        return true
    }
}
