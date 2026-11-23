import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let cloudBackup = CloudBackupBridge()
  private let reviewer = QwenReviewBridge()
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
    let reviewChannel = FlutterMethodChannel(name: "ma.raqmain.najeez/qwen", binaryMessenger: registrar.messenger())
    reviewChannel.setMethodCallHandler { [reviewer] call, result in reviewer.handle(call, result: result) }
    FlutterEventChannel(name: "ma.raqmain.najeez/qwen/state", binaryMessenger: registrar.messenger())
      .setStreamHandler(reviewer)
    let focusChannel = FlutterMethodChannel(
      name: "ma.raqmain.najeez/focus_activity", binaryMessenger: registrar.messenger())
    focusChannel.setMethodCallHandler { [focusActivity] call, result in
      focusActivity.handle(call, result: result)
    }
  }
}
