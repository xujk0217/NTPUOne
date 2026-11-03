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
import FirebaseRemoteConfig
import GoogleMobileAds
import AppTrackingTransparency
import UserNotifications
import Network
import WidgetKit
import FirebaseAppCheck
import GoogleSignIn
import StoreKit

/// Public switches are readable by every app; Firestore rules enforce administrator-only writes.
@MainActor
final class GlobalFeatureSettings: ObservableObject {
    static let shared = GlobalFeatureSettings()
    @Published private(set) var adsEnabled = true
    @Published private(set) var aiEnabled = true
    @Published private(set) var available = false
    @Published private(set) var saving = false
    @Published var error: String?
    private var listener: ListenerRegistration?
    func start() {
        guard listener == nil, FirebaseApp.app() != nil else { return }
        listener = Firestore.firestore().collection("appSettings").document("features").addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error { self.error = error.localizedDescription; self.available = false; return }
                guard let snapshot else { return }
                let data = snapshot.data() ?? [:]
                self.adsEnabled = data["adsEnabled"] as? Bool ?? true
                self.aiEnabled = data["aiEnabled"] as? Bool ?? true
                self.available = !snapshot.metadata.isFromCache
                if self.available { self.error = nil }
            }
        }
    }
    func save(key: String, value: Bool) {
        guard ["adsEnabled", "aiEnabled"].contains(key), available, !saving else { return }
        saving = true; error = nil
        Firestore.firestore().collection("appSettings").document("features").setData([key: value], merge: true) { [weak self] error in
            DispatchQueue.main.async { self?.saving = false; self?.error = error?.localizedDescription }
        }
    }
}

enum RemoteConfigFeature {
    case community
    case restaurant
    case courseSearch

    var maintenanceTitle: String {
        switch self {
        case .community: return "交流區維護中"
        case .restaurant: return "餐廳功能維護中"
        case .courseSearch: return "課程搜尋維護中"
        }
    }
}

/// 集中管理 Remote Config 的預設值、初次抓取與 realtime 更新。
/// 所有開關僅控制 SwiftUI 顯示，不會變更 Firestore 規則或資料。
final class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()

    private enum Key {
        static let maintenanceEnabled = "maintenance_enabled"
        static let maintenanceTitle = "maintenance_title"
        static let maintenanceMessage = "maintenance_message"
        static let communityEnabled = "community_enabled"
        static let communityDisabledMessage = "community_disabled_message"
        static let restaurantEnabled = "restaurant_enabled"
        static let restaurantDisabledMessage = "restaurant_disabled_message"
        static let courseSearchEnabled = "course_search_enabled"
        static let courseSearchDisabledMessage = "course_search_disabled_message"
    }

    private let defaultValues: [String: NSObject] = [
        Key.maintenanceEnabled: false as NSNumber,
        Key.maintenanceTitle: "系統維護中" as NSString,
        Key.maintenanceMessage: "目前正在進行系統維護，請稍後再試。" as NSString,
        Key.communityEnabled: true as NSNumber,
        Key.communityDisabledMessage: "交流區目前暫時維護中，請稍後再試。" as NSString,
        Key.restaurantEnabled: true as NSNumber,
        Key.restaurantDisabledMessage: "餐廳功能目前暫時維護中，請稍後再試。" as NSString,
        Key.courseSearchEnabled: true as NSNumber,
        Key.courseSearchDisabledMessage: "課程搜尋目前暫時維護中，請稍後再試。" as NSString
    ]

    private var remoteConfig: RemoteConfig?
    private var updateRegistration: ConfigUpdateListenerRegistration?
    private var hasStarted = false

    @Published private(set) var maintenanceEnabled = false
    @Published private(set) var maintenanceTitle = "系統維護中"
    @Published private(set) var maintenanceMessage = "目前正在進行系統維護，請稍後再試。"
    @Published private(set) var communityEnabled = true
    @Published private(set) var communityDisabledMessage = "交流區目前暫時維護中，請稍後再試。"
    @Published private(set) var restaurantEnabled = true
    @Published private(set) var restaurantDisabledMessage = "餐廳功能目前暫時維護中，請稍後再試。"
    @Published private(set) var courseSearchEnabled = true
    @Published private(set) var courseSearchDisabledMessage = "課程搜尋目前暫時維護中，請稍後再試。"

    private init() {}

    func start() {
        guard !hasStarted, FirebaseApp.app() != nil else { return }
        hasStarted = true

        let remoteConfig = RemoteConfig.remoteConfig()
        remoteConfig.setDefaults(defaultValues)

        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 12 * 60 * 60
        #endif
        remoteConfig.configSettings = settings
        self.remoteConfig = remoteConfig

        applyActiveValues()
        remoteConfig.fetchAndActivate { [weak self] _, error in
            if let error {
                print("Remote Config fetch failed: \(error.localizedDescription)")
                return
            }
            self?.applyActiveValues()
        }

        updateRegistration = remoteConfig.addOnConfigUpdateListener { [weak self] _, error in
            if let error {
                print("Remote Config realtime update failed: \(error.localizedDescription)")
                return
            }

            remoteConfig.activate { _, activationError in
                if let activationError {
                    print("Remote Config activation failed: \(activationError.localizedDescription)")
                    return
                }
                self?.applyActiveValues()
            }
        }
    }

    deinit {
        updateRegistration?.remove()
    }

    func isEnabled(_ feature: RemoteConfigFeature) -> Bool {
        switch feature {
        case .community: return communityEnabled
        case .restaurant: return restaurantEnabled
        case .courseSearch: return courseSearchEnabled
        }
    }

    func disabledMessage(for feature: RemoteConfigFeature) -> String {
        switch feature {
        case .community: return communityDisabledMessage
        case .restaurant: return restaurantDisabledMessage
        case .courseSearch: return courseSearchDisabledMessage
        }
    }

    private func applyActiveValues() {
        guard let remoteConfig else { return }

        let values = (
            remoteConfig.configValue(forKey: Key.maintenanceEnabled).boolValue,
            remoteConfig.configValue(forKey: Key.maintenanceTitle).stringValue ?? "系統維護中",
            remoteConfig.configValue(forKey: Key.maintenanceMessage).stringValue ?? "目前正在進行系統維護，請稍後再試。",
            remoteConfig.configValue(forKey: Key.communityEnabled).boolValue,
            remoteConfig.configValue(forKey: Key.communityDisabledMessage).stringValue ?? "交流區目前暫時維護中，請稍後再試。",
            remoteConfig.configValue(forKey: Key.restaurantEnabled).boolValue,
            remoteConfig.configValue(forKey: Key.restaurantDisabledMessage).stringValue ?? "餐廳功能目前暫時維護中，請稍後再試。",
            remoteConfig.configValue(forKey: Key.courseSearchEnabled).boolValue,
            remoteConfig.configValue(forKey: Key.courseSearchDisabledMessage).stringValue ?? "課程搜尋目前暫時維護中，請稍後再試。"
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.maintenanceEnabled = values.0
            self.maintenanceTitle = values.1
            self.maintenanceMessage = values.2
            self.communityEnabled = values.3
            self.communityDisabledMessage = values.4
            self.restaurantEnabled = values.5
            self.restaurantDisabledMessage = values.6
            self.courseSearchEnabled = values.7
            self.courseSearchDisabledMessage = values.8
        }
    }
}

struct MaintenanceView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text(title)
                .font(.title2.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct FeatureMaintenanceView: View {
    let title: String
    let message: String

    var body: some View {
        MaintenanceView(title: title, message: message)
    }
}

struct RemoteConfigFeatureGate<Content: View>: View {
    @EnvironmentObject private var remoteConfigManager: RemoteConfigManager
    private let feature: RemoteConfigFeature
    private let content: Content

    init(feature: RemoteConfigFeature, @ViewBuilder content: () -> Content) {
        self.feature = feature
        self.content = content()
    }

    var body: some View {
        if remoteConfigManager.isEnabled(feature) {
            content
        } else {
            FeatureMaintenanceView(
                title: feature.maintenanceTitle,
                message: remoteConfigManager.disabledMessage(for: feature)
            )
        }
    }
}


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, InAppMessagingDisplayDelegate, MessagingDelegate {
    var window: UIWindow?
    private var adminAuthHandle: AuthStateDidChangeListenerHandle?
    private static var communityNotificationRefreshTaskIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "com.xujk.NTPUOne").communityNotificationRefresh"
    }
    
    var persistentContainer: NSPersistentCloudKitContainer {
        CoreDataManager.shared.persistentContainer
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        AppCheck.setAppCheckProviderFactory(MyAppCheckProviderFactory())
        
        
        FirebaseApp.configure()
        adminAuthHandle = Auth.auth().addStateDidChangeListener { _, user in
            DispatchQueue.main.async { AdminLocalSecurity.reconcileSession(user: user) }
        }
        RemoteConfigManager.shared.start()
        GlobalFeatureSettings.shared.start()
        
        AppCheck.appCheck().token(forcingRefresh: true) { token, error in
            if token != nil {
                print("✅ AppCheck token refreshed")
            } else if let error = error {
                print("❌ AppCheck failed: \(error.localizedDescription)")
            } else {
                print("❌ AppCheck failed: Unknown error")
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


    func saveContext() {
        CoreDataManager.shared.saveContext()
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

/// Compatibility wrapper for existing callers; the App now has a single store owner.
class PersistenceController {
    static let shared = PersistenceController()
    var container: NSPersistentCloudKitContainer { CoreDataManager.shared.persistentContainer }
}

@main
struct NTPUOneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let persistenceController = PersistenceController.shared
    @StateObject private var adFree = AdFreeService.shared
    @StateObject private var persistence = CoreDataManager.shared
    @State private var reloadToken = UUID()
    @StateObject private var remoteConfigManager = RemoteConfigManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        AdminLocalSecurity.migrateLegacySession()
        incrementLaunchCount()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = persistence.loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                        Text("資料暫時無法開啟").font(.headline)
                        Text(error).font(.subheadline).multilineTextAlignment(.center)
                        Button("重新嘗試") { persistence.retryLoading() }.buttonStyle(.borderedProminent)
                    }.padding()
                } else if !persistence.isReady {
                    ProgressView("正在載入資料…")
                } else if remoteConfigManager.maintenanceEnabled {
                    MaintenanceView(
                        title: remoteConfigManager.maintenanceTitle,
                        message: remoteConfigManager.maintenanceMessage
                    )
                } else {
                    LoadedAppContent()
                        .id(reloadToken)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(adFree)
                }
            }
            .environmentObject(remoteConfigManager)
            .alert("資料尚未儲存", isPresented: Binding(
                get: { persistence.operationError != nil },
                set: { if !$0 { persistence.operationError = nil } }
            )) {
                Button("再試一次") {
                    if persistence.saveContext() { reloadToken = UUID() }
                }
                Button("稍後再試", role: .cancel) { }
            } message: {
                Text(persistence.operationError ?? "")
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                NextCourseLiveActivityManager.shared.setApplicationActive(true)
                adFree.refresh()   // 回到前景時刷新到期狀態
                WidgetCenter.shared.reloadAllTimelines()  // 刷新所有 Widget
                if K.Community.notificationsEnabled {
                    CommunityNotificationFallbackService.shared.refresh(source: "foreground")
                }
            } else {
                NextCourseLiveActivityManager.shared.setApplicationActive(false)
            }

            if phase == .background {
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


/// Created only after the persistent store loads, including after a successful retry.
private struct LoadedAppContent: View {
    @StateObject private var courseData = CourseData(context: CoreDataManager.shared.persistentContainer.viewContext)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ContentView()
            .environmentObject(courseData)
            .onChange(of: scenePhase) { phase in
                if phase == .active { courseData.refreshNextCourseLiveActivity() }
            }
    }
}
