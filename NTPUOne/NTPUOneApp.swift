//
//  NTPUOneApp.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import BackgroundTasks
import CoreData
import FirebaseAnalytics
import FirebaseCore
import Firebase
import FirebaseInAppMessagingInternal
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import GoogleMobileAds
import AppTrackingTransparency
import UserNotifications
import Network
import WidgetKit
import FirebaseAppCheck
import GoogleSignIn
import StoreKit


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, InAppMessagingDisplayDelegate, MessagingDelegate {
    var window: UIWindow?
    private static var communityNotificationRefreshTaskIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "com.xujk.NTPUOne").communityNotificationRefresh"
    }
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "CourseModel")
        
        // 使用App Group共享路径
        let appGroupIdentifier = "group.NTPUOne.NextCourseWidget"
        if let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("shared.sqlite") {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.xujk.NTPUOne")
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("✅ Persistent store loaded at: \(storeDescription.url?.path ?? "unknown")")
            }
        })
        return container
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        AppCheck.setAppCheckProviderFactory(MyAppCheckProviderFactory())
        
        
        FirebaseApp.configure()
        
        AppCheck.appCheck().token(forcingRefresh: true) { token, error in
            if token != nil {
                print("✅ AppCheck token refreshed")
            } else if let error = error {
                print("❌ AppCheck failed: \(error.localizedDescription)")
            } else {
                print("❌ AppCheck failed: Unknown error")
            }
        }
        
        AppCheck.appCheck().token(forcingRefresh: true) { tokenResult, error in
            if tokenResult?.token != nil {
                print("✅ App Check token available")
            } else if let error = error {
                print("❌ Failed to get App Check token: \(error.localizedDescription)")
            }
        }

        
        MonitorNetworkConnection()
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = ["2d1480604504fd42fec5872ffe17cb9f"]
        startGoogleMobileAdsAfterTrackingAuthorization()
        WidgetCenter.shared.reloadAllTimelines()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        if K.Community.notificationsEnabled {
            Self.registerCommunityNotificationRefreshTask()
            Self.scheduleCommunityNotificationRefresh()
            Messaging.messaging().token { token, error in
                if let error {
                    print("❌ FCM token fetch failed: \(error.localizedDescription)")
                } else if let token {
                    Self.persistCommunityFCMToken(token)
                }
            }
        }

        return true
    }

    /// 只有使用者完成 ATT 選擇後才初始化廣告 SDK，讓 IDFA 的使用符合 Apple 規範。
    private func startGoogleMobileAdsAfterTrackingAuthorization() {
        let startAds = {
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        }

        guard #available(iOS 14.5, *) else {
            startAds()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
                startAds()
                return
            }
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async { startAds() }
            }
        }
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }

        if Auth.auth().canHandle(url) {
            return true
        }

        return false
    }
            
    // 当应用程序处于前台时收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        guard K.Community.notificationsEnabled else { return }
        Messaging.messaging().token { token, error in
            if let error {
                print("❌ FCM token refresh after APNs registration failed: \(error.localizedDescription)")
            } else if let token {
                Self.persistCommunityFCMToken(token)
            }
        }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard K.Community.notificationsEnabled, let fcmToken else { return }
        Self.persistCommunityFCMToken(fcmToken)
    }

    static func requestCommunityNotificationRegistration() {
        guard K.Community.notificationsEnabled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("❌ Community notification permission failed: \(error.localizedDescription)")
                return
            }

            guard granted else {
                print("⚠️ Community notification permission denied")
                return
            }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
                Messaging.messaging().token { token, error in
                    if let error {
                        print("❌ FCM token fetch after permission failed: \(error.localizedDescription)")
                    } else if let token {
                        persistCommunityFCMToken(token)
                    }
                }
            }
        }
    }

    static func scheduleCommunityNotificationRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: communityNotificationRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ Community notification refresh schedule failed: \(error.localizedDescription)")
        }
    }

    private static func registerCommunityNotificationRefreshTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: communityNotificationRefreshTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleCommunityNotificationRefreshTask(refreshTask)
        }
    }

    private static func handleCommunityNotificationRefreshTask(_ task: BGAppRefreshTask) {
        scheduleCommunityNotificationRefresh()

        var didComplete = false
        task.expirationHandler = {
            DispatchQueue.main.async {
                guard !didComplete else { return }
                didComplete = true
                task.setTaskCompleted(success: false)
            }
        }

        CommunityNotificationFallbackService.shared.refresh(source: "background") { success in
            guard !didComplete else { return }
            didComplete = true
            task.setTaskCompleted(success: success)
        }
    }

    private static func persistCommunityFCMToken(_ token: String) {
        guard K.Community.notificationsEnabled else { return }
        let defaults = UserDefaults.standard
        let key = "commentDeviceId"
        let deviceId: String
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            deviceId = existing
        } else {
            let generated = UUID().uuidString
            defaults.set(generated, forKey: key)
            deviceId = generated
        }

        let deviceSecret = ensureCommunityDeviceSecret()
        var payload: [String: Any] = [
            "deviceId": deviceId,
            "deviceSecret": deviceSecret,
            "fcmToken": token,
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let user = Auth.auth().currentUser {
            payload["ownerUid"] = user.uid
            payload["ownerEmail"] = user.email ?? ""
        }

        Firestore.firestore().collection("communityDeviceTokens").document(deviceSecret).setData(payload, merge: true) { error in
            if let error {
                print("❌ Failed to save community FCM token: \(error.localizedDescription)")
            }
        }
    }

    private static func ensureCommunityDeviceSecret() -> String {
        let defaults = UserDefaults.standard
        let key = "communityDeviceSecret"
        if let existing = defaults.string(forKey: key), !existing.isEmpty { return existing }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: key)
        return generated
    }


    func saveContext () {
        let context = PersistenceController.shared.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func MonitorNetworkConnection() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "Monitor")
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print("We're connected!")
            } else {
                print("No connection.")
            }
            print(path.isExpensive)
        }
        monitor.start(queue: queue)
    }
}

class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    // This is where you decide which provider to use.
    // App Attest is the recommended provider for real devices.
    // For simulators, App Attest is not available, so you'd use a debug provider.
      
    #if targetEnvironment(simulator)
      // Use AppCheckDebugProvider for simulators
      // IMPORTANT: Remember to register your debug device in the Firebase console
      // under App Check -> Debug tokens.
      print("App Check: Using AppCheckDebugProvider for simulator.")
      return AppCheckDebugProvider(app: app)
    #else
      // Use AppAttestProvider for real devices
      print("App Check: Using AppAttestProvider for real device.")
      return AppAttestProvider(app: app)
    #endif
  }
}

//struct PersistenceController {
//    static let shared = PersistenceController()
//
//    let container: NSPersistentCloudKitContainer
//
//    init() {
//        container = NSPersistentCloudKitContainer(name: "CourseModel")
//        // 使用 App Group 的 URL 配置 Core Data 存储
//        let appGroupIdentifier = "group.NTPUOne.NextCourseWidget"
//        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("shared.sqlite")
//        
//        // 配置 Persistent Store Description
//        let storeDescription = NSPersistentStoreDescription(url: storeURL!)
//        container.persistentStoreDescriptions = [storeDescription]
//        
//        container.loadPersistentStores { _, error in
//            if let error = error as NSError? {
//                fatalError("Unresolved error \(error), \(error.userInfo)")
//            }
//        }
//        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
//    }
//}

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init() {
        container = NSPersistentCloudKitContainer(name: "CourseModel")
        
        let appGroupIdentifier = "group.NTPUOne.NextCourseWidget"
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("shared.sqlite")
        
        let storeDescription = storeURL.map(NSPersistentStoreDescription.init(url:)) ?? NSPersistentStoreDescription()
        storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.xujk.NTPUOne")

        container.persistentStoreDescriptions = [storeDescription]

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

@main
struct NTPUOneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let persistenceController = PersistenceController.shared
    @StateObject private var adFree = AdFreeService.shared
    @StateObject private var courseData: CourseData
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        self._courseData = StateObject(wrappedValue: CourseData(context: PersistenceController.shared.container.viewContext))
        incrementLaunchCount()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(courseData)
                .environmentObject(adFree)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                adFree.refresh()   // 回到前景時刷新到期狀態
                WidgetCenter.shared.reloadAllTimelines()  // 刷新所有 Widget
                courseData.refreshNextCourseLiveActivity()
                if K.Community.notificationsEnabled {
                    CommunityNotificationFallbackService.shared.refresh(source: "foreground")
                }
            } else if phase == .background {
                if K.Community.notificationsEnabled {
                    AppDelegate.scheduleCommunityNotificationRefresh()
                }
            }
        }
    }
    
    func incrementLaunchCount() {
        let defaults = UserDefaults.standard
        let launchCountKey = "appLaunchCount"
        var count = defaults.integer(forKey: launchCountKey)
        count += 1
        defaults.set(count, forKey: launchCountKey)

        print("App 已開啟 \(count) 次")

        if count >= 3 && Bool.random() {
            requestAppReview()
        }
    }

    func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
