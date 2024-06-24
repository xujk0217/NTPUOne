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
            lifeView.tabItem{
                Image(systemName: "cup.and.saucer.fill")
                Text("life")
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
    
    //MARK: - home view
    
    var linkView: some View{
        NavigationView{
            List(webManager.websArray, rowContent: { webs in
                Section{
                    ForEach(webs.webs){ web in
                        NavigationLink(destination: WebDetailView(url: web.url)) {
                            HStack {
                                Text(web.title)
                            }
                        }
                    }
                } header: {
                    Text(webs.title)
                } footer: {
                    if webs.id == 2{
                        Text("選課請以電腦選課，因為我找不到網址")
                    }
                }
            })
            .navigationTitle("NTPU links")
        }
        .onAppear(perform: {
            webManager.createData()
        })
    }
    
    //MARK: - traffic

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
    
    //MARK: - life view

    var lifeView: some View{
        NavigationView(content: {
            NavigationLink(destination: Text("Destination")) { Text("food and weather") }
        })
    }
    
    //MARK: - timetable

    var timetableView: some View{
        NavigationView(content: {
            NavigationLink(destination: Text("Destination")) { Text("timetable") }
        })
    }
    
    //MARK: - about

    var aboutView: some View{
        NavigationView(content: {
            NavigationLink(destination: Text("Destination")) { Text("feedback and intro") }
        })
    }
    
}
