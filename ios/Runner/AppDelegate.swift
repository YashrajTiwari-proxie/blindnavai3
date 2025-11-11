import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let channelName = "ios_hardware_button_channel"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)

    // Example: listen for volume buttons
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(forName: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"), object: nil, queue: nil) { notification in
        channel.invokeMethod("keyPressed", arguments: 24) // 24 = volume up
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
