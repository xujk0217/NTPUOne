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
import FirebaseInAppMessagingInternal

class AppDelegate: NSObject, UIApplicationDelegate, InAppMessagingDisplayDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
      Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
    return true
  }
}

@main
struct NTPUOneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
