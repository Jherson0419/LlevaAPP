import Flutter
import FirebaseCore
import FirebaseMessaging
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase primero (lee GoogleService-Info.plist).
    FirebaseApp.configure()

    GMSServices.provideAPIKey(Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String ?? "")

    // FlutterAppDelegate ya es UNUserNotificationCenterDelegate y reenvía los
    // eventos a los plugins (firebase_messaging, flutter_local_notifications).
    UNUserNotificationCenter.current().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Con FirebaseAppDelegateProxyEnabled = false (Info.plist) el token APNs
  // se pasa a mano a Firebase.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
