//
//  NTPUOneApp.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import CoreData
import FirebaseAnalytics
import FirebaseCore
import Firebase
import FirebaseInAppMessagingInternal
import GoogleMobileAds
import UserNotifications
import Network
import WidgetKit
import FirebaseAppCheck
import StoreKit


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, InAppMessagingDisplayDelegate {
    var window: UIWindow?
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "CourseModel")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        AppCheck.setAppCheckProviderFactory(MyAppCheckProviderFactory())
        
        
        FirebaseApp.configure()
        
        AppCheck.appCheck().token(forcingRefresh: true) { token, error in
            if let token = token {
                print("✅ AppCheck token: \(token.token)")
            } else if let error = error {
                print("❌ AppCheck failed: \(error.localizedDescription)")
            } else {
                print("❌ AppCheck failed: Unknown error")
            }
        }
        
        AppCheck.appCheck().token(forcingRefresh: true) { tokenResult, error in
            if let token = tokenResult?.token {
                print("✅ App Check token: \(token)")
            } else if let error = error {
                print("❌ Failed to get App Check token: \(error.localizedDescription)")
            }
        }

        
        MonitorNetworkConnection()
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = ["2d1480604504fd42fec5872ffe17cb9f"]
        // Request notification authorization and set the delegate
        requestNotificationAuthorization()
        WidgetCenter.shared.reloadAllTimelines()
        UNUserNotificationCenter.current().delegate = self
                
        return true
    }
            
    // 当应用程序处于前台时收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
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
    private func requestNotificationAuthorization() {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("Notification permission granted.")
                } else {
                    print("Notification permission denied.")
                }
                if let error = error {
                    print("Error requesting notification authorization: \(error.localizedDescription)")
                }
            }
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
        
        let storeDescription = NSPersistentStoreDescription(url: storeURL!)
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
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        incrementLaunchCount()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(CourseData(context: persistenceController.container.viewContext))
                .environmentObject(adFree)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                adFree.refresh()   // 回到前景時刷新到期狀態
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
