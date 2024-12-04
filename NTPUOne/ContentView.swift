//
//  ContentView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var courseData: CourseData
    
    @ObservedObject var webManager = WebManager()
    @ObservedObject var bikeManager = UbikeManager()
    @ObservedObject var weatherManager = WeatherManager()
    @StateObject private var orderManager = OrderManager()
    @ObservedObject var fManager = FManager()
    
    @State var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LinkView(courseData: courseData).tabItem {
                Image(systemName: "house")
                Text("Main")
            }.tag(0)
            
            TimeTableView().tabItem {
                Image(systemName: "list.bullet.clipboard")
                Text("Timetable")
            }.tag(1)
            
            LifeView().tabItem {
                Image(systemName: "cup.and.saucer.fill")
                Text("Life")
            }.tag(2)
            AboutView().tabItem {
                Image(systemName: "info.circle")
                Text("About")
            }.tag(3)
        }
    }
}

#Preview {
    ContentView()
}
