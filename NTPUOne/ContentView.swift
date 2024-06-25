//
//  ContentView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import SwiftData
import SafariServices

struct ContentView: View {
    
    @ObservedObject var webManager = WebManager()
    @ObservedObject var bikeManager = UbikeManager()
    
    @State private var urlString: String? = nil
    @State private var showWebView = false
    @State private var showSafariView = false
    
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
    var linkView: some View {
        NavigationView {
            List {
                ForEach(webManager.websArray) { webs in
                    Section(header: Text(webs.title), footer: footerText(for: webs.id)) {
                        if webs.id != 3 {
                            ForEach(webs.webs) { web in
                                if web.url == "https://past-exam.ntpu.cc" || web.url == "https://cof.ntpu.edu.tw/student_new.htm" {
                                    Button(action: {
                                        handleURL(web.url)
                                    }) {
                                        HStack {
                                            Image(systemName: web.image)
                                            Text(web.title)
                                        }
                                    }
                                } else {
                                    NavigationLink(destination: WebDetailView(url: web.url)) {
                                        HStack {
                                            Image(systemName: web.image)
                                            Text(web.title)
                                        }
                                    }
                                }
                            }
                        } else {
                            DisclosureGroup("系網們") {
                                ForEach(webs.webs) { web in
                                    NavigationLink(destination: WebDetailView(url: web.url)) {
                                        HStack {
                                            Image(systemName: web.image)
                                            Text(web.title)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("NTPU Links")
            .onAppear(perform: {
                webManager.createData()
            })
            .sheet(isPresented: $showWebView) {
                if let urlString = urlString {
                    WebDetailView(url: urlString)
                }
            }
            .sheet(isPresented: $showSafariView) {
                
            }
        }
    }
    
    func handleURL(_ urlString: String) {
        self.urlString = urlString
        if urlString == "https://past-exam.ntpu.cc" {
            // Open in external browser
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } else {
            // Open in SafariViewController
            if let url = URL(string: urlString) {
                if let topViewController = UIApplication.shared.windows.first?.rootViewController {
                    let safariVC = SFSafariViewController(url: url)
                    topViewController.present(safariVC, animated: true, completion: nil)
                }
            }
        }
    }
    
    func footerText(for id: Int) -> some View {
        Group {
            if id == 2 {
                Text("選課請以電腦選課，因為我找不到網址")
            } else if id == 3 {
                Text("不動和應外的系網不符合 HTTPS 協定，無法進入，請從院網進入")
            }
        }
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
