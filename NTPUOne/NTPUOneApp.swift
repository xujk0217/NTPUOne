//
//  NTPUOneApp.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import SwiftData
import FirebaseAnalytics
import FirebaseCore
import Firebase
import FirebaseInAppMessagingInternal
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate, InAppMessagingDisplayDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        MonitorNetworkConnection()
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = ["2d1480604504fd42fec5872ffe17cb9f"]
        return true
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

@main
struct NTPUOneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            if #available(iOS 17.0, *) {
                ContentView()
            } else {
                // Fallback on earlier versions
                FallbackView()
            }
        }
    }
}
