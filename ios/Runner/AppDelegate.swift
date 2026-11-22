import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let cloudBackup = CloudBackupBridge()
  private let dailyReview = DailyReviewBridge()
  private let focusActivity = FocusActivityBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CloudBackupBridge")!
    let channel = FlutterMethodChannel(name: "ma.raqmain.najeez/icloud", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [cloudBackup] call, result in
      cloudBackup.handle(call, result: result)
    }
    let reviewChannel = FlutterMethodChannel(
      name: "ma.raqmain.najeez/daily_review", binaryMessenger: registrar.messenger())
    reviewChannel.setMethodCallHandler { [dailyReview] call, result in
      dailyReview.handle(call, result: result)
    }
    let focusChannel = FlutterMethodChannel(
      name: "ma.raqmain.najeez/focus_activity", binaryMessenger: registrar.messenger())
    focusChannel.setMethodCallHandler { [focusActivity] call, result in
      focusActivity.handle(call, result: result)
    }
  }
}
