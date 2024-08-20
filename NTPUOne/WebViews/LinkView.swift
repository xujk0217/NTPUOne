//
//  LinkView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
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

struct LinkView: View {
    @ObservedObject var webManager = WebManager()
    @StateObject private var orderManager = OrderManager()
    
    @State private var urlString: String? = nil
    @State private var showWebView = false
    @State private var showSafariView = false
    @State private var selectDemo = 0
    
    //Course
    @ObservedObject var courseData: CourseData
    @State private var nextCourseOnAppear: Course?
    @State private var showingAlert = false
    let currentDate = Date()
    let calendar = Calendar.current
    @State var courseName = ""
    @State var courseTeacher = ""
    @State var courseDay = ""
    @State var courseTime = ""
    @State var courseLocation = ""
    
    //DemoView
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State var startIndex = 0
    @State var startIndexE = 0
    @State var startIndexP = 0
    @State var startIndexO = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    orderSection
                    Section{
                        VStack(alignment: .leading) {
                            if let nextCourse = nextCourseOnAppear{
                                Button{
                                    courseName = nextCourse.name
                                    courseTeacher = nextCourse.teacher
                                    courseTime = nextCourse.startTime.rawValue
                                    courseLocation = nextCourse.location
                                    courseDay = nextCourse.day
                                    showingAlert = true
                                } label: {
                                    VStack(alignment: .leading){
                                        Text("\(nextCourse.name)")
                                            .font(.title3.bold())
                                        Text("開始時間：\(nextCourse.day), \(nextCourse.startTime.rawValue)")
                                            .font(.callout)
                                    }.foregroundStyle(Color.black)
                                }
                            }else{
                                Text("今日已沒有課程")
                                    .font(.title3.bold())
                                Text("開始時間：無")
                                    .font(.callout)
                            }
                        }.frame(height: 50)
                    } header: {
                        Text("下一堂課")
                    }
                    Section{
                        NavigationLink {
                            VStack{
                                List{
                                    webSections
                                }
                            }.navigationTitle("常用連結")
                        } label: {
                            HStack {
                                Image(systemName: "macwindow")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .padding()
                                Text("常用連結")
                                    .font(.callout.bold())
                            }.frame(height: 50)
                        }
                    } header: {
                        Text("常用連結")
                    }
                }
                .navigationTitle("NTPU one")
                .onAppear {
                    nextCourseOnAppear = nextUpcomingCourse()
                    webManager.createData()
                }
                .sheet(isPresented: $showWebView) {
                    if let urlString = urlString {
                        WebDetailView(url: urlString)
                    }
                }
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text(courseName),
                        message: Text("教授：\(courseTeacher == "" ? "..." : courseTeacher) 教授\n時間：\(courseDay), \(courseTime)\n地點：\(courseLocation == "" ? "..." : courseLocation)"),
                        dismissButton: .default(Text("OK"))
                    )
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
                                .foregroundStyle(selectDemo == 0 ? Color.blue : Color.blue.opacity(0.3))
                                .font(.caption.bold())
                                .padding(6)
                                .padding(.horizontal, 3)
                                .background(selectDemo == 0 ? Color.white : Color.white.opacity(0.3))
                                .cornerRadius(5.0)
                                .padding(.leading, -12)
                        }
                        Button {
                            selectDemo = 1
                        } label: {
                            Text("活動")
                                .foregroundStyle(selectDemo == 1 ? Color.blue : Color.blue.opacity(0.3))
                                .font(.caption.bold())
                                .padding(6)
                                .padding(.horizontal, 3)
                                .background(selectDemo == 1 ? Color.white : Color.white.opacity(0.3))
                                .cornerRadius(5.0)
                        }
                        
                        Button {
                            selectDemo = 2
                        } label: {
                            Text("公告")
                                .foregroundStyle(selectDemo == 2 ? Color.blue : Color.blue.opacity(0.3))
                                .font(.caption.bold())
                                .padding(6)
                                .padding(.horizontal, 3)
                                .background(selectDemo == 2 ? Color.white : Color.white.opacity(0.3))
                                .cornerRadius(5.0)
                        }
                        
                        Button {
                            selectDemo = 3
                        } label: {
                            Text("其他")
                                .foregroundStyle(selectDemo == 3 ? Color.blue : Color.blue.opacity(0.3))
                                .font(.caption.bold())
                                .padding(6)
                                .padding(.horizontal, 3)
                                .background(selectDemo == 3 ? Color.white : Color.white.opacity(0.3))
                                .cornerRadius(5.0)
                        }
                    }
                } footer: {
                    VStack {
                        Text("如需新增活動廣播，請至 about 頁面新增")
                            .foregroundStyle(Color.black)
                            .padding(.bottom)
                        Divider()
//                        Text("常用網址")
//                            .foregroundStyle(Color.black)
//                            .font(.callout)
                    }
                }
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
//            if ["http://dafl.ntpu.edu.tw/main.php", "http://www.rebe.ntpu.edu.tw", "https://past-exam.ntpu.cc", "https://cof.ntpu.edu.tw/student_new.htm"].contains(web.url) {
                AnyView(
                    Button(action: {
                        handleURL(web.url)
                    }) {
                        webLinkLabel(for: web)
                    }
                        .foregroundStyle(Color.black)
                )
//            } else {
//                AnyView(
//                    NavigationLink(destination: WebDetailView(url: web.url)) {
//                        webLinkLabel(for: web)
//                    }
//                )
//            }
        }
    }
    
    private func webLinkLabel(for web: WebData) -> some View {
        HStack {
            Image(systemName: web.image)
                .resizable()
                .scaledToFit()
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
    
    func nextUpcomingCourse() -> Course? {
        let currentDate = Date()
        let calendar = Calendar.current
        print("find next course")
        
        var nextCourse: Course?
        var smallestTimeDifference: TimeInterval = .greatestFiniteMagnitude
        
        for course in courseData.courses {
            // 将课程的 day 字符串转换为今天的日期
            if let courseDate = getCourseDate(for: course) {
                // 计算当前时间与课程开始时间的差距
                let timeDifference = courseDate.timeIntervalSince(currentDate)
                
                // 只选择当天未来的课程
                if timeDifference > 0 && timeDifference < smallestTimeDifference {
                    smallestTimeDifference = timeDifference
                    nextCourse = course
                }
            }
        }
        
        return nextCourse
    }

    private func getCourseDate(for course: Course) -> Date? {
        let currentDate = Date()
        let calendar = Calendar.current
        
        // 将 day 转换为星期几的整数
        let weekday = courseData.weekday(from: course.day) // Assuming course.day is like "Monday", "Tuesday", etc.
        
        // 获取当前日期的 DateComponents
        var dateComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: currentDate)
        
        // 检查课程是否是今天的
        if dateComponents.weekday == weekday {
            // 获取课程的时间
            dateComponents.hour = courseData.hour(from: course.startTime)
            dateComponents.minute = 15 // Assuming course.startTime has hour precision, otherwise modify accordingly
            
            return calendar.date(from: dateComponents)
        }
        
        return nil
    }

    private func calculateTriggerDate(for course: Course) -> DateComponents {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        
        dateComponents.hour = courseData.hour(from: course.startTime) // 小时
        dateComponents.minute = 0 // 分钟
        
        // 输出计算过程中的信息
        print("Calculating Trigger Date for Course: \(course.name)")
        print("Date Components: \(dateComponents)")
        
        return dateComponents
    }
}

