import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle URL schemes for authentication flows (iOS 9+)
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    // Log URL for debugging
    print("Received URL in AppDelegate: \(url.absoluteString)")
    
    // Let Flutter handle the URL
    return super.application(app, open: url, options: options)
  }
  
  // For older iOS versions (rarely used nowadays)
  override func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
    // Log URL for debugging
    print("Received URL in AppDelegate (legacy): \(url.absoluteString)")
    
    // Let Flutter handle the URL
    return super.application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
  }
  
  // For universal links
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    // Check if this is a universal link
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
      print("Received universal link: \(url.absoluteString)")
    }
    
    // Let Flutter handle the activity
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}
