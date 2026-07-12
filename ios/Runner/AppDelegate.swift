import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let nonBackupStorageChannel =
    "app.aoki.yuki.vagina/non_backup_storage"
  private var storageChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return false
    }
    storageChannel = FlutterMethodChannel(
      name: Self.nonBackupStorageChannel,
      binaryMessenger: controller.binaryMessenger
    )
    storageChannel?.setMethodCallHandler { call, result in
      guard call.method == "getNonBackupStorageRoot" else {
        result(FlutterMethodNotImplemented)
        return
      }

      do {
        result(try Self.prepareNonBackupStorageRoot().path)
      } catch {
        result(
          FlutterError(
            code: "non_backup_storage_unavailable",
            message: "Could not prepare non-backup application storage.",
            details: error.localizedDescription
          )
        )
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private static func prepareNonBackupStorageRoot() throws -> URL {
    let applicationSupport = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let root = applicationSupport.appendingPathComponent(
      "VAGINANonBackup",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true
    )

    var excludedFromBackup = URLResourceValues()
    excludedFromBackup.isExcludedFromBackup = true
    var mutableRoot = root
    try mutableRoot.setResourceValues(excludedFromBackup)
    return mutableRoot
  }
}
