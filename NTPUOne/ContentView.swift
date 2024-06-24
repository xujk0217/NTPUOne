//
//  ContentView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    @ObservedObject var webManager = WebManager()
    @ObservedObject var bikeManager = UbikeManager()
    var trafficTitle = "UBike in ntpu"
    
    var body: some View {
        TabView{
            linkView.tabItem {
                Image(systemName: "house")
                Text("Home")
            }
            trafficView.tabItem {
                Image(systemName: "car")
                Text("traffic")
            }
            dietView.tabItem{
                Image(systemName: "fork.knife")
                Text("food")
            }
            timetableView.tabItem{
                Image(systemName: "list.clipboard")
                Text("timetable")
            }
            aboutView.tabItem{
                Image(systemName: "info.circle")
                Text("about")
            }
            
        }
    }
}

#Preview {
    ContentView()
}

//MARK: - sub page

private extension ContentView{
    var linkView: some View{
        NavigationView{
            List(webManager.webDatas, rowContent: { web in
                NavigationLink(destination: WebDetailView(url: web.url)) {
                    HStack {
                        //Text(String(wel.))
                        Text(web.title)
                    }
                }
            })
            .navigationTitle("NTPU links")
        }
        .onAppear(perform: {
            webManager.createData()
        })
    }
    
    var trafficView: some View{
        NavigationView{
            VStack {
                List {
                    Section {
                        ForEach(bikeManager.bikeDatas) { stop in
                            if isNTPU(sno: stop.sno) {
                                NavigationLink(destination: bikeView()){
                                    HStack{
                                        Text(stop.tot)
                                            .font(.title.bold())
                                        VStack{
                                            HStack {
                                                Text(stop.sna)
                                                Spacer()
                                            }
                                            HStack{
                                                Image(systemName: "bicycle")
                                                Text(stop.sbi)
                                                Spacer()
                                                Image(systemName: "baseball.diamond.bases")
                                                Text(stop.bemp)
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Ubike in NTPU")
                            Spacer()
                            NavigationLink(destination: MoreBikeView()) {
                                Text("more")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Traffic")
        }.onAppear(perform: {
            self.bikeManager.fetchData()
        })
    }
    
    func isNTPU(sno: String) -> Bool{
        for i in K.Bike.NTPUBikeNum{
            if i == sno{
                return true
            }
        }
        return false
    }
    
    var dietView: some View{
        NavigationView(content: {
            NavigationLink(destination: Text("Destination")) { Text("Navigate") }
        })
    }
    var timetableView: some View{
        NavigationView(content: {
            NavigationLink(destination: Text("Destination")) { Text("Navigate") }
        })
    }
    var aboutView: some View{
        NavigationView(content: {
            NavigationLink(destination: Text("Destination")) { Text("Navigate") }
        })
    }
    
}
