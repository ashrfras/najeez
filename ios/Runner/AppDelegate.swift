import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let cloudBackup = CloudBackupBridge()

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
  }
}
