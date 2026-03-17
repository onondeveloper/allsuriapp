import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // FirebaseAppDelegateProxyEnabled=false 시 필수: APNs 토큰을 Firebase에 전달
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }

  /// 앱이 포그라운드로 돌아올 때 앱 아이콘 배지 제거
  override func applicationDidBecomeActive(_ application: UIApplication) {
    application.applicationIconBadgeNumber = 0
  }
}
