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
    @StateObject private var memoManager: MemoManager
    
    @State var selectedTab = 0
    
    init() {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        self._memoManager = StateObject(wrappedValue: MemoManager(context: context))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LinkView(courseData: courseData, memoManager: memoManager).tabItem {
                Image(systemName: "house")
                Text("Main")
            }.tag(0)
            
            TimeTableView(memoManager: memoManager).tabItem {
                Image(systemName: "list.bullet.clipboard")
                Text("Timetable")
            }.tag(1)
            
            TodayView(memoManager: memoManager, courseData: courseData).tabItem {
                Image(systemName: "note.text")
                Text("Memo")
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
