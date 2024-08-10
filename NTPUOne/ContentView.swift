//
//  ContentView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import SwiftData
import SafariServices
import FirebaseCore
import FirebaseFirestore
import GoogleMobileAds
import AppTrackingTransparency
import MapKit
import Firebase

struct ContentView: View {
    
    @ObservedObject var webManager = WebManager()
    @ObservedObject var bikeManager = UbikeManager()
    @ObservedObject var weatherManager = WeatherManager()
    @StateObject private var orderManager = OrderManager()
    
    @ObservedObject var fManager = FManager()
    
    @State var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab){
            LinkView().tabItem {
                Image(systemName: "house")
                Text("main")
            }.tag(0)
            LifeView().tabItem{
                Image(systemName: "cup.and.saucer.fill")
                Text("life")
            }.tag(1)
            if #available(iOS 17.0, *) {
                TrafficView().tabItem {
                    Image(systemName: "bicycle")
                    Text("traffic")
                }.tag(2)
            } else {
                BackTrafficView().tabItem {
                    Image(systemName: "bicycle")
                    Text("traffic")
                }.tag(2)
            }
            AboutView().tabItem{
                Image(systemName: "info.circle")
                Text("about")
            }.tag(3)
        }
    }
}

#Preview {
    ContentView()
}

