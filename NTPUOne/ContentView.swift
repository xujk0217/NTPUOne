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

struct ContentView: View {
    
    @ObservedObject var webManager = WebManager()
    @ObservedObject var bikeManager = UbikeManager()
    @ObservedObject var weatherManager = WeatherManager()
    @StateObject private var orderManager = OrderManager()
    
    @ObservedObject var fManager = FManager()
    
    @State private var urlString: String? = nil
    @State private var showWebView = false
    @State private var showSafariView = false
    
    @State private var isExpanded = false
    
    @State private var selectDemo = 0
    
    //DemoView
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    @State var startIndex = 0
    @State var startIndexE = 0
    @State var startIndexP = 0
    @State var startIndexO = 0
    
    var trafficTitle = "UBike in ntpu"
    
    @State var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab){
            linkView.tabItem {
                Image(systemName: "house")
                Text("main")
            }.tag(0)
            lifeView.tabItem{
                Image(systemName: "cup.and.saucer.fill")
                Text("life")
            }.tag(1)
            if #available(iOS 17.0, *) {
                trafficView().tabItem {
                    Image(systemName: "bicycle")
                    Text("traffic")
                }.tag(2)
            } else {
                // Fallback on earlier versions
                noMapTrafficView().tabItem {
                    Image(systemName: "bicycle")
                    Text("traffic")
                }.tag(2)
            }
            aboutView.tabItem{
                Image(systemName: "info.circle")
                Text("about")
            }.tag(3)
        }
    }
}

#Preview {
    ContentView()
}

extension String {
    
    func substring(from: Int, length: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: length)
        return String(self[start..<end])
    }
    func substring(from: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        return String(self[start...])
    }
}

//MARK: - sub page

private extension ContentView{
    
    //MARK: - home view
    var linkView: some View {
        NavigationStack {
            VStack {
                List {
                    orderSection
                    webSections
                }
                .scrollContentBackground(.hidden)
                .background(
                    LinearGradient(colors: [.white, .blue], startPoint: .bottomLeading, endPoint: .topTrailing)
                )
                .navigationTitle("NTPU one")
                .onAppear {
                    webManager.createData()
                }
                .sheet(isPresented: $showWebView) {
                    if let urlString = urlString {
                        WebDetailView(url: urlString)
                    }
                }
            }
        }
    }
    
    private var orderSection: some View {
        Group {
            if let order = orderManager.order {
                Section {
                    if selectDemo == 0{
                        DemoView
                            .onAppear(perform: orderManager.loadOrder)
                    }else if selectDemo == 1{
                        DemoViewEvent
                            .onAppear(perform: orderManager.loadOrderEvent)
                    }else if selectDemo == 2{
                        DemoViewPost
                            .onAppear(perform: orderManager.loadOrderPost)
                    }else if selectDemo == 3{
                        DemoViewOther
                            .onAppear(perform: orderManager.loadOrderOther)
                    }
                } header: {
                    HStack{
                        Button {
                            selectDemo = 0
                        } label: {
                            Text("All")
                                .font(.caption.bold())
                                .padding(6)
                                .padding(.horizontal, 3)
                                .background(selectDemo == 0 ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                                .cornerRadius(5.0)
                                .padding(.leading, -12)
                        }
                        Button {
                            selectDemo = 1
                        } label: {
                            Text("活動")
                                .font(.caption.bold())
                                .padding(6)
                                .padding(.horizontal, 3)
                                .background(selectDemo == 1 ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                                .cornerRadius(5.0)
                        }
                        
                        Button {
                            selectDemo = 2
                        } label: {
                            Text("公告")
                                .font(.caption.bold())
                                .padding(6)
                                .padding(.horizontal, 3)
                                .background(selectDemo == 2 ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                                .cornerRadius(5.0)
                        }
                        
                        Button {
                            selectDemo = 3
                        } label: {
                            Text("其他")
                                .font(.caption.bold())
                                .padding(6)
                                .padding(.horizontal, 3)
                                .background(selectDemo == 3 ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                                .cornerRadius(5.0)
                        }
                    }
                } footer: {
                    VStack {
                        Text("如需新增活動廣播，請至 about 頁面新增")
                            .foregroundStyle(Color.black)
                            .padding(.bottom)
                        Divider()
                        Text("常用網址")
                            .foregroundStyle(Color.black)
                            .font(.callout)
                    }
                }
                .listRowBackground(Color.white.opacity(0.7))
            } else {
                Section {
                    VStack {
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .onAppear(perform: orderManager.loadOrder)
                    }
                } footer: {
                    Text("連線中，請確認網路連線")
                }
            }
        }
    }
    
    private var webSections: some View {
        ForEach(webManager.websArray) { webs in
                    Section(header: Text(webs.title).foregroundStyle(Color.black), footer: footerText(for: webs.id).foregroundStyle(Color.black)) {
                        if webs.id == 3 {
                            disclosureGroup(for: webs)
                        } else if webs.id == 4 {
                            if let calendar = webManager.Calendar {
                                webLinks(for: webManager.Calendar!)
                            } else {
                                Section {
                                    VStack {
                                        ProgressView("Loading...")
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .onAppear(perform: webManager.createData)
                                    }
                                } footer: {
                                    Text("連線中，請確認網路連線")
                                }
                            }
                        } else {
                            webLinks(for: webs.webs)
                        }
                    }
                }
    }
    
    private func disclosureGroup(for webs: WebsArray) -> some View {
        DisclosureGroup("系網們") {
            ForEach(webs.webs) { web in
                webLinkButton(for: web)
            }
        }
        .frame(height: 50)
        .font(.callout.bold())
    }
    
    private func webLinks(for webs: [WebData]) -> some View {
        ForEach(webs) { web in
            webLinkButton(for: web)
        }
        .frame(height: 50)
    }
    
    private func webLinkButton(for web: WebData) -> some View {
        Group {
            if ["http://dafl.ntpu.edu.tw/main.php", "http://www.rebe.ntpu.edu.tw", "https://past-exam.ntpu.cc", "https://cof.ntpu.edu.tw/student_new.htm"].contains(web.url) {
                AnyView(
                    Button(action: {
                        handleURL(web.url)
                    }) {
                        webLinkLabel(for: web)
                    }
                        .foregroundStyle(Color.black)
                )
            } else {
                AnyView(
                    NavigationLink(destination: WebDetailView(url: web.url)) {
                        webLinkLabel(for: web)
                    }
                )
            }
        }
    }
    
    private func webLinkLabel(for web: WebData) -> some View {
        HStack {
            Image(systemName: web.image)
                .resizable()
                .frame(width: 30, height: 30)
                .padding()
            Text(web.title)
                .font(.callout.bold())
        }.foregroundStyle(Color.black)
    }
    
    func handleURL(_ urlString: String) {
        self.urlString = urlString
        if urlString == "https://past-exam.ntpu.cc" {
            // Open in external browser
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else {
                    print("Cannot open URL: \(urlString)")
                }
            }
        } else {
            // Open in SafariViewController
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    if let topViewController = UIApplication.shared.windows.first?.rootViewController {
                        let safariVC = SFSafariViewController(url: url)
                        topViewController.present(safariVC, animated: true, completion: nil)
                    }
                } else {
                    print("Cannot open URL: \(urlString)")
                }
            }
        }
    }
    
    func footerText(for id: Int) -> some View {
        Group {
            if id == 2 {
                Text("選課請以電腦選課，因為我找不到網址")
            } else if id == 3 {
                Text("有些研究所我不會簡寫，如需要請聯絡我")
            }
        }
    }
    
    var DemoView: some View {
        TabView(selection: $startIndex) {
            if let orders = orderManager.order {
                ForEach(orders.indices, id: \.self) { index in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(orders[index].message) \n -by \(orders[index].name)")
                                .font(.headline)
                                .lineLimit(5)
                                .multilineTextAlignment(.center)
                                .padding()
                            Spacer()
                        }
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: orders[index].url) {
                            if UIApplication.shared.canOpenURL(url) {
                                handleURL(orders[index].url)
                            } else {
                                print("Cannot open URL: \(orders[index].url)")
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.black))
                .padding(.horizontal, 1)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .onReceive(timer) { _ in
            withAnimation {
                if let orders = orderManager.order, orders.count > 1 {
                    startIndex = (startIndex + 1) % orders.count
                }
            }
        }
        .frame(height: 160)
    }
    
    var DemoViewEvent: some View {
        TabView(selection: $startIndexE) {
            if let orders = orderManager.order {
                ForEach(orders.indices, id: \.self) { index in
                    if orders[index].tag == "1"{
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(orders[index].message) \n -by \(orders[index].name)")
                                    .font(.headline)
                                    .lineLimit(5)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                Spacer()
                            }
                            Spacer()
                        }
                        .onTapGesture {
                            if let url = URL(string: orders[index].url) {
                                if UIApplication.shared.canOpenURL(url) {
                                    handleURL(orders[index].url)
                                } else {
                                    print("Cannot open URL: \(orders[index].url)")
                                }
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.black))
                .padding(.horizontal, 1)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .onReceive(timer) { _ in
                withAnimation {
                    if let orders = orderManager.order {
                        if orderManager.eventN > 1 {
                            startIndexE = (startIndexE + 1) % orderManager.eventN
                        }
                    }
                }
            }
        .frame(height: 160)
    }
    
    var DemoViewPost: some View {
        TabView(selection: $startIndexP) {
            if let orders = orderManager.order {
                ForEach(orders.indices, id: \.self) { index in
                    if orders[index].tag == "2"{
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(orders[index].message) \n -by \(orders[index].name)")
                                    .font(.headline)
                                    .lineLimit(5)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                Spacer()
                            }
                            Spacer()
                        }
                        .onTapGesture {
                            if let url = URL(string: orders[index].url) {
                                if UIApplication.shared.canOpenURL(url) {
                                    handleURL(orders[index].url)
                                } else {
                                    print("Cannot open URL: \(orders[index].url)")
                                }
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.black))
                .padding(.horizontal, 1)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .onReceive(timer) { _ in
                withAnimation {
                    if let orders = orderManager.order {
                        if orderManager.postN > 1 {
                            startIndexP = (startIndexP + 1) % orderManager.postN
                        }
                    }
                }
            }
        .frame(height: 160)
    }
    
    var DemoViewOther: some View {
        TabView(selection: $startIndexO) {
            if let orders = orderManager.order {
                ForEach(orders.indices, id: \.self) { index in
                    if orders[index].tag == "3"{
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(orders[index].message) \n -by \(orders[index].name)")
                                    .font(.headline)
                                    .lineLimit(5)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                Spacer()
                            }
                            Spacer()
                        }
                        .onTapGesture {
                            if let url = URL(string: orders[index].url) {
                                if UIApplication.shared.canOpenURL(url) {
                                    handleURL(orders[index].url)
                                } else {
                                    print("Cannot open URL: \(orders[index].url)")
                                }
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.black))
                .padding(.horizontal, 1)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .onReceive(timer) { _ in
                withAnimation {
                    if let orders = orderManager.order {
                        if orderManager.otherN > 1 {
                            startIndexO = (startIndexO + 1) % orderManager.otherN
                        }
                    }
                }
            }
        .frame(height: 160)
    }
    
    
    //MARK: - traffic
    
    @available(iOS 17.0, *)
    struct trafficView: View{
        @ObservedObject var bikeManager = UbikeManager()
        @State private var isExpanded = false
        @State var position: MapCameraPosition = .camera(
            MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 24.942406, longitude: 121.368198), distance: 1500)
        )
        @State var selectionResult: MKMapItem?
        var body: some View{
            VStack {
                NavigationStack {
                    if let bikeDatas = bikeManager.bikeDatas {
                        VStack {
                            List {
                                Section{
                                    if #available(iOS 17.0, *) {
                                        mapView
                                    } else {
                                        // Fallback on earlier versions
                                        Text("升級至 IOS 17.0 以開啟地圖功能")
                                    }
                                } header: {
                                    Text("腳踏車地圖")
                                        .foregroundStyle(Color.black)
                                } footer: {
                                    Text("名稱：站名-(腳踏車數/總數)")
                                        .foregroundStyle(Color.black)
                                }
                                Section {
                                    DisclosureGroup("Ubike in NTPU", isExpanded: $isExpanded){
                                        ForEach(bikeManager.bikeDatas!) { stop in
                                            if isNTPU(sno: stop.sno) {
                                                NavigationLink(destination: bikeView(Bike: stop)){
                                                    HStack{
                                                        Text(stop.tot)
                                                            .font(.title.bold())
                                                        VStack{
                                                            HStack {
                                                                Text(stop.sna.substring(from: 11))
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
                                    }.listRowBackground(Color.white.opacity(0.7))
                                } header: {
                                    HStack {
                                        Text("Ubike in NTPU")
                                            .foregroundStyle(Color.black)
                                        Spacer()
                                        if isExpanded == true {
                                            NavigationLink(destination: MoreBikeView()) {
                                                Text("more")
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                } footer: {
                                    Text("更新頻率：每5分鐘")
                                        .foregroundStyle(Color.black)
                                }
                            }
                            .scrollContentBackground(.hidden)
                            .background(.linearGradient(colors: [.white, .green], startPoint: .bottomLeading, endPoint: .topTrailing))
                            .toolbarBackground(Color.green.opacity(0.9), for: .navigationBar)
                        }
                        .navigationTitle("Traffic")
                    }else{
                        Text("Loading...")
                            .onAppear {
                                bikeManager.fetchData()
                            }
                        ProgressView()
                    }
                }.onAppear(perform: {
                    self.bikeManager.fetchData()
                })
            }
        }
        @available(iOS 17.0, *)
        var mapView: some View {
            VStack{
                if let bikeDatas = bikeManager.bikeDatas {
                    Map(position: $position, selection: $selectionResult){
                        ForEach(bikeManager.bikeDatas!) { stop in
                            Marker("\(stop.sna.substring(from: 11))-(\(stop.sbi)/\(stop.tot))", systemImage: "bicycle", coordinate: CLLocationCoordinate2D(latitude: Double(stop.lat)!, longitude: Double(stop.lng)!))
                        }
                    }.mapStyle(.standard(elevation: .realistic))
                }else{
                    Text("Loading...")
                        .onAppear {
                            bikeManager.fetchData()
                        }
                    ProgressView()
                }
            }.frame(height: 300)
        }
        func isNTPU(sno: String) -> Bool{
            for i in K.Bike.NTPUBikeNum{
                if i == sno{
                    return true
                }
            }
            return false
        }
    }
    
    //MARK: - no map traffic
    struct noMapTrafficView: View{
        @ObservedObject var bikeManager = UbikeManager()
        @State private var isExpanded = false
        var body: some View{
            VStack {
                if let bikeDatas = bikeManager.bikeDatas {
                    NavigationStack(){
                        VStack {
                            List {
                                Section{
                                    Text("升級至 IOS 17.0 以開啟地圖功能")
                                } header: {
                                    Text("腳踏車地圖")
                                        .foregroundStyle(Color.black)
                                } footer: {
                                    Text("名稱：站名-(腳踏車數/總數)")
                                        .foregroundStyle(Color.black)
                                }
                                Section {
                                    DisclosureGroup("Ubike in NTPU", isExpanded: $isExpanded){
                                        ForEach(bikeManager.bikeDatas!) { stop in
                                            if isNTPU(sno: stop.sno) {
                                                NavigationLink(destination: noMapBikeView(Bike: stop)){
                                                    HStack{
                                                        Text(stop.tot)
                                                            .font(.title.bold())
                                                        VStack{
                                                            HStack {
                                                                Text(stop.sna.substring(from: 11))
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
                                    }.listRowBackground(Color.white.opacity(0.7))
                                } header: {
                                    HStack {
                                        Text("Ubike in NTPU")
                                            .foregroundStyle(Color.black)
                                        Spacer()
                                        if isExpanded == true {
                                            NavigationLink(destination: MoreBikeView()) {
                                                Text("more")
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                } footer: {
                                    Text("更新頻率：每5分鐘")
                                        .foregroundStyle(Color.black)
                                }
                            }
                            .scrollContentBackground(.hidden)
                            .background(.linearGradient(colors: [.white, .green], startPoint: .bottomLeading, endPoint: .topTrailing))
                            .navigationTitle("Traffic")
                        }
                    }.onAppear(perform: {
                        self.bikeManager.fetchData()
                    })
                }else{
                    Text("Loading...")
                        .onAppear {
                            bikeManager.fetchData()
                        }
                    ProgressView()
                }
            }
        }
        func isNTPU(sno: String) -> Bool{
            for i in K.Bike.NTPUBikeNum{
                if i == sno{
                    return true
                }
            }
            return false
        }
    }
    
    
    //MARK: - life view
    @ViewBuilder
    var lifeView: some View{
        NavigationStack {
            VStack{
                if let weatherData = weatherManager.weatherDatas {
                    let station = weatherData.records.Station.first!
                    ScrollView {
                        VStack(alignment: .leading) {
                            Section {
                                weatherView(
                                    weathers: station.WeatherElement.Weather,
                                    currentTemperature: station.WeatherElement.AirTemperature,
                                    maxTemperature: station.WeatherElement.DailyExtreme.DailyHigh.TemperatureInfo.AirTemperature,
                                    minTemperature: station.WeatherElement.DailyExtreme.DailyLow.TemperatureInfo.AirTemperature,
                                    windSpeed: station.WeatherElement.WindSpeed,
                                    getTime: station.ObsTime.DateTime,
                                    humidity: station.WeatherElement.RelativeHumidity
                                )
                            } header: {
                                Text("現在天氣")
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal)
                            }
                            Divider()
                            VStack(alignment: .leading) {
                                Section {
                                    VStack(alignment: .leading, spacing: 10) {
                                        NavigationLink{
                                            BreakfastView()
                                        } label: {
                                            HStack {
                                                Image(systemName: "cup.and.saucer")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(Color.black)
                                                    .padding()
                                                    .padding(.leading)
                                                Text("早餐")
                                                    .padding()
                                                    .frame(alignment: .leading)
                                                    .foregroundStyle(Color.black)
                                                
                                                Spacer()
                                            }
                                            .frame(height: 100)
                                            .background(Color.white.opacity(0.7))
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                        }
                                        NavigationLink(destination: LunchView()) {
                                            HStack {
                                                Image(systemName: "carrot")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(Color.black)
                                                    .padding()
                                                    .padding(.leading)
                                                Text("午餐")
                                                    .padding()
                                                    .frame(alignment: .leading)
                                                    .foregroundStyle(Color.black)
                                                
                                                Spacer()
                                            }
                                            .frame(height: 100)
                                            .background(Color.white.opacity(0.7))
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                        }
                                        NavigationLink(destination: dinnerView()) {
                                            HStack {
                                                Image(systemName: "wineglass")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(Color.black)
                                                    .padding()
                                                    .padding(.leading)
                                                Text("晚餐")
                                                    .padding()
                                                    .frame(alignment: .leading)
                                                    .foregroundStyle(Color.black)
                                                
                                                Spacer()
                                            }
                                            .frame(height: 100)
                                            .background(Color.white.opacity(0.7))
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                        }
                                        NavigationLink(destination: MSView()) {
                                            HStack {
                                                Image(systemName: "cross")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(Color.black)
                                                    .padding()
                                                    .padding(.leading)
                                                Text("宵夜")
                                                    .padding()
                                                    .frame(alignment: .leading)
                                                    .foregroundStyle(Color.black)
                                                
                                                Spacer()
                                            }
                                            .frame(height: 100)
                                            .background(Color.white.opacity(0.7))
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                        }
                                        Spacer()
                                    }
                                } header: {
                                    Text("NTPU-今天吃什麼？")
                                        .foregroundStyle(Color.black)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .navigationTitle("PU Life")
                    .scrollContentBackground(.hidden)
                    .background(.linearGradient(colors: [.white, .cyan], startPoint: .bottomLeading, endPoint: .topTrailing))
                }else{
                    Text("Loading...")
                        .onAppear {
                            weatherManager.fetchData()
                        }
                    ProgressView()
                }
            }
        }.onAppear {
            weatherManager.fetchData()
        }
    }
    
    struct weatherView: View{
        let weathers: String
        let currentTemperature: Double
        let maxTemperature: Double
        let minTemperature: Double
        let windSpeed: Double
        let getTime: String
        let humidity: Double
        var body: some View{
            VStack {
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: weatherIcon(weather: weathers))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .padding()
                        Text(weathers)
                    }
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "thermometer.medium")
                                Text(" \(currentTemperature, specifier: "%.1f")°C")
                                    .font(.title3.bold())
                            }
                            HStack {
                                Image(systemName: "thermometer.sun")
                                Text(" \(maxTemperature, specifier: "%.1f")°C")
                                    .font(.title3)
                            }
                            HStack {
                                Image(systemName: "thermometer.snowflake")
                                Text(" \(minTemperature, specifier: "%.1f")°C")
                                    .font(.title3)
                            }
                            HStack {
                                Image(systemName: "wind")
                                Text(" \(windSpeed, specifier: "%.1f") m/s")
                                    .font(.title3)
                            }
                        }
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "clock.badge")
                                Text(getTime.substring(from: 11, length: 5))
                                    .font(.title3)
                            }
                            HStack {
                                if currentTemperature > 27{
                                    Image(systemName: "face.dashed")
                                }else if currentTemperature > 16{
                                    Image(systemName: "face.smiling")
                                }else{
                                    Image(systemName: "face.dashed.fill")
                                }
                                if currentTemperature > 30{
                                    Text("快蒸發了")
                                        .font(.title3)
                                }else if currentTemperature >= 28 {
                                    Text("好叻啊")
                                        .font(.title3)
                                }else if currentTemperature >= 23{
                                    Text("小熱")
                                        .font(.title3)
                                }else if currentTemperature > 15{
                                    Text("舒服")
                                        .font(.title3)
                                }else if currentTemperature > 11{
                                    Text("小冷")
                                        .font(.title3)
                                }else{
                                    Text("凍凍腦")
                                        .font(.title3)
                                }
                            }
                            HStack {
                                Text(" ")
                                    .font(.title3)
                            }
                            HStack {
                                Text(" ")
                                    .font(.title3)
                            }
                        }
                    }
                    Spacer()
                }
                .frame(height: 150)
                .background(Color.white.opacity(0.4))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        func weatherIcon(weather: String) -> String {
            switch weather {
            case "晴": return "sun.max"
            case "晴有霾": return "sun.haze"
            case "晴有靄": return "sun.haze"
            case "晴有閃電": return "sun.bolt"
            case "晴有雷聲": return "sun.bolt"
            case "晴有霧": return "sun.haze"
            case "晴有雨": return "cloud.sun.rain"
            case "晴有雨雪": return "cloud.sun.snow"
            case "晴有大雪": return "cloud.sun.snow"
            case "晴有雪珠": return "cloud.sun.snow"
            case "晴有冰珠": return "cloud.sun.snow"
            case "晴有陣雨": return "cloud.sun.rain"
            case "晴陣雨雪": return "cloud.sun.snow"
            case "晴有雹": return "cloud.sun.hail"
            case "晴有雷雨": return "cloud.sun.bolt.rain"
            case "晴有雷雪": return "cloud.sun.snow"
            case "晴有雷雹": return "cloud.sun.bolt.hail"
            case "晴大雷雨": return "cloud.sun.bolt.rain"
            case "晴大雷雹": return "cloud.sun.bolt.hail"
            case "晴有雷": return "sun.bolt"
                
            case "多雲": return "cloud.sun"
            case "多雲有霾": return "cloud.sun.haze"
            case "多雲有靄": return "cloud.sun.haze"
            case "多雲有閃電": return "cloud.bolt"
            case "多雲有雷聲": return "cloud.bolt"
            case "多雲有霧": return "cloud.sun.haze"
            case "多雲有雨": return "cloud.rain"
            case "多雲有雨雪": return "cloud.sleet"
            case "多雲有大雪": return "cloud.snow"
            case "多雲有雪珠": return "cloud.snow"
            case "多雲有冰珠": return "cloud.snow"
            case "多雲有陣雨": return "cloud.rain"
            case "多雲陣雨雪": return "cloud.sleet"
            case "多雲有雹": return "cloud.hail"
            case "多雲有雷雨": return "cloud.bolt.rain"
            case "多雲有雷雪": return "cloud.snow"
            case "多雲有雷雹": return "cloud.bolt.hail"
            case "多雲大雷雨": return "cloud.bolt.rain"
            case "多雲大雷雹": return "cloud.bolt.hail"
            case "多雲有雷": return "cloud.bolt"
                
            case "陰": return "cloud"
            case "陰有霾": return "cloud.haze"
            case "陰有靄": return "cloud.haze"
            case "陰有閃電": return "cloud.bolt"
            case "陰有雷聲": return "cloud.bolt"
            case "陰有霧": return "cloud.haze"
            case "陰有雨": return "cloud.rain"
            case "陰有雨雪": return "cloud.sleet"
            case "陰有大雪": return "cloud.snow"
            case "陰有雪珠": return "cloud.snow"
            case "陰有冰珠": return "cloud.snow"
            case "陰有陣雨": return "cloud.rain"
            case "陰陣雨雪": return "cloud.sleet"
            case "陰有雹": return "cloud.hail"
            case "陰有雷雨": return "cloud.bolt.rain"
            case "陰有雷雪": return "cloud.snow"
            case "陰有雷雹": return "cloud.bolt.hail"
            case "陰大雷雨": return "cloud.bolt.rain"
            case "陰大雷雹": return "cloud.bolt.hail"
            case "陰有雷": return "cloud.bolt"
                
            case "有霾": return "cloud.haze"
            case "有靄": return "cloud.haze"
            case "有閃電": return "cloud.bolt"
            case "有雷聲": return "cloud.bolt"
            case "有霧": return "cloud.haze"
            case "有雨": return "cloud.rain"
            case "有雨雪": return "cloud.sleet"
            case "有大雪": return "cloud.snow"
            case "有雪珠": return "cloud.snow"
            case "有冰珠": return "cloud.snow"
            case "有陣雨": return "cloud.rain"
            case "陣雨雪": return "cloud.sleet"
            case "有雹": return "cloud.hail"
            case "有雷雨": return "cloud.bolt.rain"
            case "有雷雪": return "cloud.snow"
            case "有雷雹": return "cloud.bolt.hail"
            case "大雷雨": return "cloud.bolt.rain"
            case "大雷雹": return "cloud.bolt.hail"
            case "有雷": return "cloud.bolt"
                
            default: return "questionmark.circle"
            }
        }
    }
    
    //MARK: - about
    
    var aboutView: some View{
        NavigationStack {
            //ad richer
            List{
                Section{
                    NavigationLink {
                        AddOrderView()
                            .navigationTitle("新增")
                    } label: {
                        VStack {
                            Text("新增活動廣播")
                        }
                    }
                    
                } header: {
                    Text("活動廣播")
                } footer: {
                    VStack {
                        Text("無意義的會刪掉喔～")
                    }
                }
                Section{
                    NavigationLink {
                        FeaturesView()
                            .navigationTitle("功能建議")
                    } label: {
                        Text("Features suggestion")
                    }
                    NavigationLink {
                        ReportBugView()
                            .navigationTitle("回報錯誤")
                    } label: {
                        Text("Report Bugs")
                    }
                } header: {
                    Text("suggesstion & Report")
                } footer: {
                    Text("歡迎回報～")
                }
                Section{
                    NavigationLink {
                        ContactMeView()
                    } label: {
                        Text("Contact me")
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Text("Privacy Policy")
                    }
                } header: {
                    Text("Me")
                }
            }
            .navigationTitle("About")
        }
    }
    
}
