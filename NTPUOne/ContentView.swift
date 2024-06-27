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

struct ContentView: View {
    
    @ObservedObject var webManager = WebManager()
    @ObservedObject var bikeManager = UbikeManager()
    @ObservedObject var weatherManager = WeatherManager()
    @StateObject private var orderManager = OrderManager()
    
    @State private var urlString: String? = nil
    @State private var showWebView = false
    @State private var showSafariView = false
    
    @State private var isExpanded = false
    
    //DemoView
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    @State var startIndex = 0
    
    var trafficTitle = "UBike in ntpu"
    
    var body: some View {
        TabView{
            linkView.tabItem {
                Image(systemName: "house")
                Text("main")
            }
            trafficView.tabItem {
                Image(systemName: "bicycle")
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
        .edgesIgnoringSafeArea(.bottom)
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
}

//MARK: - sub page

private extension ContentView{
    
    //MARK: - home view
    var linkView: some View {
        NavigationView {
            VStack {
                List {
                    Section {
                        DemoView
                            .onAppear(perform: {
                                orderManager.loadOrder()
                            })
                    } footer: {
                        Text("如需新增活動廣播，請至 about 頁面新增")
                    }
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
                                        if web.url == "http://dafl.ntpu.edu.tw/main.php" || web.url == "http://www.rebe.ntpu.edu.tw"{
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
                                }
                            }
                        }
                    }
                }
                .navigationTitle("NTPU one")
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
                Text("有些研究所我不會簡寫，如需要請聯絡我")
            }
        }
    }
    
    var DemoView: some View {
        TabView(selection: $startIndex) {
            ForEach(orderManager.order.indices, id: \.self) { index in
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(orderManager.order[index].message) \n -by \(orderManager.order[index].name)")
                            .font(.headline)
                            .lineLimit(5)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                    Spacer()
                }.onTapGesture {
                    if orderManager.order[index].url != ""{
                        handleURL(orderManager.order[index].url)
                    }
                }
            }
            .background(Color.gray.opacity(0.2))
            .cornerRadius(15)
            .padding(.horizontal, 2)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onReceive(timer) { _ in
            withAnimation {
                if orderManager.order.count > 1{
                    startIndex = (startIndex + 1) % orderManager.order.count
                }
            }
        }
        .frame(height: 130)
    }
    
    
    //MARK: - traffic
    
    var trafficView: some View{
        NavigationView{
            VStack {
                List {
                    Section {
                        DisclosureGroup("Ubike in NTPU", isExpanded: $isExpanded){
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
                        }
                    } header: {
                        HStack {
                            Text("Ubike in NTPU")
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
    @ViewBuilder
    var lifeView: some View{
        NavigationView {
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
                                    .foregroundStyle(Color.gray)
                                    .padding(.horizontal)
                            }
                            Divider()
                            VStack(alignment: .leading) {
                                Section {
                                    VStack(alignment: .leading, spacing: 10) {
                                            NavigationLink(destination: BreakfastView()) {
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
                                                .background(Color.gray.opacity(0.2))
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
                                                .background(Color.gray.opacity(0.2))
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
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(10)
                                                .padding(.horizontal)
                                            }
                                            NavigationLink(destination: MSVIew()) {
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
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(10)
                                                .padding(.horizontal)
                                            }
                                            Spacer()
                                    }
                                } header: {
                                    Text("NTPU-今天吃什麼？")
                                        .foregroundStyle(Color.gray)
                                        .padding(.horizontal)
                            }
                            }
                        }
                    }
                    .navigationTitle("PU Life")
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
                .background(Color.gray.opacity(0.2))
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
    
    //MARK: - timetable
    
    var timetableView: some View{
        NavigationView {
            Text("un")
                .navigationTitle("Time table")
        }
    }
    
    //MARK: - about
    
    var aboutView: some View{
        NavigationView {
            //ad richer
            List{
                Section{
                    NavigationLink {
                        AddOrderView()
                            .navigationTitle("新增")
                    } label: {
                        Text("新增活動廣播")
                    }
                    
                } header: {
                    Text("活動廣播")
                } footer: {
                    Text("無意義的會刪掉喔～")
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
                        AboutMeView()
                    } label: {
                        Text("about me")
                    }
                } header: {
                    Text("Me")
                }
            }
            .navigationTitle("About")
        }
    }
    
}
