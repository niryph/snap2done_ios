import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // This is necessary macOS platform code
  // It manages the application lifecycle for your Flutter app on macOS
  // Do NOT convert this to Dart
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
