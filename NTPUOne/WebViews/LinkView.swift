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
    @EnvironmentObject var adFree: AdFreeService
    @State private var isLoading = false
    private let helper = RewardedAdHelper()
    @State private var showAdConfirm = false
    @State private var showNotReadyAlert = false

    private let rewardedUnitID = "ca-app-pub-4105005748617921/1893622165"
    
    @State private var urlString: String? = nil
    @State private var showWebView = false
    @State private var showSafariView = false
    @State private var selectDemo = 0
    
    let cardShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    
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
    
    
    @State private var goSchoolPosts = false
    @State private var goLinks = false
    @State private var goRandomFood = false
    
    @State private var peekCourse: Course? = nil
    
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    orderSection
                    Section("下一堂課") {
                        if let c = nextCourseOnAppear {
                            Button {
//                                courseName = c.name
//                                courseTeacher = c.teacher
//                                courseTime = c.startTime.rawValue
//                                courseLocation = c.location
//                                courseDay = c.day
//                                showingAlert = true
                                peekCourse = c
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    // 左側圖示圓點
                                    ZStack {
                                        Circle()
                                            .fill(slotTint(c.timeSlot).opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "book.closed.fill")
                                            .font(.title3)
                                            .foregroundStyle(slotTint(c.timeSlot))
                                    }

                                    // 主要文字
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(c.name)
                                            .font(.headline)
                                            .lineLimit(1)

                                        // 時間 + 倒數
                                        HStack(spacing: 8) {
                                            Label("\(c.day) • \(c.startTime.rawValue)", systemImage: "clock")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if let m = minutesUntilStart(of: c) {
                                                Text("還有 \(m-5) 分")
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(slotTint(c.timeSlot).opacity(0.12))
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        // 地點 + 老師
                                        HStack(spacing: 12) {
                                            Label(c.location.isEmpty ? "—" : c.location,
                                                  systemImage: "mappin.and.ellipse")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)

                                            Label(c.teacher.isEmpty ? "—" : c.teacher,
                                                  systemImage: "person.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    if c.isNotification {
                                        Image(systemName: "bell.fill")
                                            .font(.callout)
                                            .foregroundStyle(slotTint(c.timeSlot))
                                    }
                                }
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.tertiarySystemBackground))
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(slotTint(c.timeSlot))
                                                .frame(width: 4)
                                                .padding(.vertical, 8)
                                                .padding(.leading, 6)
                                        }
                                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain) // 避免 List 預設高亮
                            .contentShape(Rectangle())
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                            
                            
                        } else {
                            // 沒有課的樣式
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("今日已沒有課程")
                                        .font(.headline)
                                    Text("好好休息～")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.tertiarySystemBackground))
                                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
                            }
                            .listRowInsets(.init(top: 1, leading: 1, bottom: 1, trailing: 1))
                        }
                    }
                    .listRowBackground(Color.clear)
                    
                    Section("功能快捷") {
                        LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 12) {
                            Button { goSchoolPosts = true } label: {
                                featureCard(icon: "text.bubble.fill", title: "學校公告", iconColor: .blue)
                            }
                            .buttonStyle(.plain).contentShape(Rectangle())

                            Button { goLinks = true } label: {
                                featureCard(icon: "macwindow", title: "常用連結", iconColor: .green)
                            }
                            .buttonStyle(.plain).contentShape(Rectangle())

                            if #available(iOS 17.0, *) {
                                Button { goRandomFood = true } label: {
                                    featureCard(icon: "chart.pie.fill", title: "吃飯轉盤", iconColor: .orange)
                                }
                                .buttonStyle(.plain).contentShape(Rectangle())
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
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
                .sheet(item: $peekCourse) { course in
                    CourseDetailSheet(course: course)
                        .presentationDetents([.fraction(0.35)])
                        .presentationDragIndicator(.visible)
                }
                if !adFree.isAdFree{
                    // 廣告標記
                    Section {
                        BannerAdView()
                            .frame(height: 50)
                    }
                }
                // 放在 NavigationStack 裡、List 後面（同一層）
                NavigationLink(destination: SchoolPostView(), isActive: $goSchoolPosts) { EmptyView() }.hidden()

                NavigationLink(destination:
                    VStack{
                        List {
                            webSections
                        }
                       // 廣告標記
                       if !adFree.isAdFree {
                           Section { BannerAdView().frame(height: 50) }
                       }
                    }
                    .navigationTitle("常用連結")
                , isActive: $goLinks) { EmptyView() }.hidden()

                if #available(iOS 17.0, *) {
                    NavigationLink(
                        destination: RandomFoodView(),
                        isActive: $goRandomFood
                    ) { EmptyView() }
                    .hidden()
                }
            }
            .toolbar {
                // 右上角按鈕
                ToolbarItem(placement: toolbarPlacementTrailing) {
                    if adFree.isAdFree {
                        Label("今天已無橫幅廣告", systemImage: "checkmark.seal.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.green)
                            .help("今天 23:59 前都不會顯示橫幅")
                    } else {
                        Button {
                            if !isLoading {
                                showAdConfirm = true
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                            } else {
                                Label("看 30 秒影片，今日關閉橫幅", systemImage: "film.stack")
                                    .labelStyle(.iconOnly) // 只顯示圖示；想顯示文字可拿掉
                            }
                        }
                        .disabled(isLoading)
                        .help("觀看完成後，今日關閉橫幅廣告")
                    }
                }
            }
            .onAppear { preloadRewardedIfNeeded() }
            .alert("關閉今日橫幅廣告？", isPresented: $showAdConfirm) {
                Button("取消", role: .cancel) { }
                Button("開始觀看") {
                    if isLoading {
                        // 若尚未預載好，給個提示（可省略）
                        showNotReadyAlert = true
                    } else {
                        showRewarded()
                    }
                }
            } message: {
                Text("觀看一支約 30 秒的獎勵影片後，今天（到 23:59）將不再顯示橫幅廣告。")
            }
            .alert("影片尚未就緒", isPresented: $showNotReadyAlert) {
                Button("好", role: .cancel) { }
            } message: {
                Text("正在載入廣告，請稍後再試。")
            }
        }
    }
    
    @ViewBuilder
    private func featureCard(icon: String,
                             title: String,
                             iconColor: Color? = nil) -> some View {
        VStack {
            let img = Image(systemName: icon).font(.system(size: 28)).padding(.top).padding(.bottom, 8)
            
            if let iconColor {
                img.foregroundStyle(iconColor)
            } else {
                img.foregroundStyle(.primary)
            }

            Text(title)
              .font(.footnote.bold())
              .multilineTextAlignment(.center)
              .foregroundStyle(.primary)
              .padding(.bottom)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // 倒數分鐘（若已過時回傳 nil）
    private func minutesUntilStart(of course: Course) -> Int? {
        guard let date = getCourseDate(for: course) else { return nil }
        let diff = date.timeIntervalSince(Date())
        let mins = Int(ceil(diff / 60))
        return mins > 0 ? mins : nil
    }

    // 依時段給色彩（可自行調整）
    private func slotTint(_ slot: Course.TimeSlot) -> Color {
        switch slot {
        case .morning1, .morning2, .morning3, .morning4:
            return .blue
        case .afternoon1, .afternoon2, .afternoon3, .afternoon4, .afternoon5:
            return .orange
        case .evening1, .evening2, .evening3, .evening4:
            return .purple
        }
    }

    
    // iOS 17 用 .topBarTrailing；iOS 16/15 用 .navigationBarTrailing
    private var toolbarPlacementTrailing: ToolbarItemPlacement {
        if #available(iOS 17.0, *) { return .topBarTrailing }
        else { return .navigationBarTrailing }
    }

    private func preloadRewardedIfNeeded() {
        guard !adFree.isAdFree else { return }
        isLoading = true
        helper.load(adUnitID: rewardedUnitID) { _ in
            DispatchQueue.main.async { self.isLoading = false }
        }
    }

    private func showRewarded() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { return }

        helper.present(from: root, onReward: {
            adFree.grantForTodayEnd() // ✅ 觀看完成 → 今日關閉橫幅
        }, onDismiss: {
            // 若你允許再次觀看，可在關閉後預載下一支
            // preloadRewardedIfNeeded()
        })
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
                    HStack {
                        Picker("", selection: $selectDemo) {
                            Text("All").tag(0)
                            Text("活動").tag(1)
                            Text("社團").tag(2)
                            Text("其他").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Spacer()
                    }
                } footer: {
                    VStack {
                        Text("如需新增活動廣播，請至 about 頁面新增")
                            .foregroundStyle(.secondary)
                            .padding(.bottom)
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
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var webSections: some View {
        ForEach(webManager.websArray) { webs in
            Section(header: Text(webs.title), footer: footerText(for: webs.id)) {
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
            AnyView(
                Button(action: {
                    handleURL(web.url)
                }) {
                    webLinkLabel(for: web)
                }
            )
        }
    }
    
    private func webLinkLabel(for web: WebData) -> some View {
        HStack(spacing: 12) {
            // 圖示徽章
            Image(systemName: web.image)
                .font(.system(size: 20))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // 標題 + 網域（可選）
            VStack(alignment: .leading, spacing: 2) {
                Text(web.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let h = host(from: web.url) {
                    Text(h)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
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
        let orders = orderManager.order ?? []

        return TabView(selection: $startIndex) {
            ForEach(Array(orders.enumerated()), id: \.offset) { index, item in
                AnnouncementCard(
                    message: item.message,
                    author: "— \(item.name)",
                    tag: item.tag,
                    urlString: item.url
                ) {
                    handleURL(item.url)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
                .padding(.horizontal, 8)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .onReceive(timer) { _ in
            withAnimation {
                if orders.count > 1 {
                    startIndex = (startIndex + 1) % orders.count
                }
            }
        }
    }

    
    var DemoViewEvent: some View {
        let orders = orderManager.order ?? []
        let tagged = orders.enumerated().filter { $0.element.tag == "1" }  // 活動
        let total = tagged.count

        return TabView(selection: $startIndexE) {
            ForEach(Array(orders.enumerated()), id: \.offset) { index, item in
                AnnouncementCard(
                    message: item.message,
                    author: "— \(item.name)",
                    tag: item.tag,
                    urlString: item.url
                ) {
                    handleURL(item.url)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
                .padding(.horizontal, 8)
                .tag(index)
            }

        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .onReceive(timer) { _ in
            guard total > 1 else { return }
            withAnimation { startIndexE = (startIndexE + 1) % total }
        }
    }

    var DemoViewPost: some View {
        let orders = orderManager.order ?? []
        let tagged = orders.enumerated().filter { $0.element.tag == "2" }  // 社團
        let total = tagged.count

        return TabView(selection: $startIndexP) {
            ForEach(Array(orders.enumerated()), id: \.offset) { index, item in
                AnnouncementCard(
                    message: item.message,
                    author: "— \(item.name)",
                    tag: item.tag,                    // 若你的型別是 Int，記得轉成 String
                    urlString: item.url
                ) {
                    handleURL(item.url)               // 你的開啟邏輯
                }
                .frame(maxWidth: .infinity, minHeight: 140)
                .padding(.horizontal, 8)
                .tag(index)
            }

        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .onReceive(timer) { _ in
            guard total > 1 else { return }
            withAnimation { startIndexP = (startIndexP + 1) % total }
        }
    }

    var DemoViewOther: some View {
        let orders = orderManager.order ?? []
        let tagged = orders.enumerated().filter { $0.element.tag == "3" }  // 其他
        let total = tagged.count

        return TabView(selection: $startIndexO) {
            ForEach(Array(orders.enumerated()), id: \.offset) { index, item in
                AnnouncementCard(
                    message: item.message,
                    author: "— \(item.name)",
                    tag: item.tag,                    // 若你的型別是 Int，記得轉成 String
                    urlString: item.url
                ) {
                    handleURL(item.url)               // 你的開啟邏輯
                }
                .frame(maxWidth: .infinity, minHeight: 140)
                .padding(.horizontal, 8)
                .tag(index)
            }

        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .onReceive(timer) { _ in
            guard total > 1 else { return }
            withAnimation { startIndexO = (startIndexO + 1) % total }
        }
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

import UIKit // UIPasteboard 複製連結

// 分類→標題+顏色
private func tagInfo(_ tag: String) -> (title: String, color: Color) {
    switch tag {
    case "1": return ("活動", .blue)
    case "2": return ("社團", .green)
    case "3": return ("其他", .orange)
    default:  return ("公告", .gray)
    }
}

// 從 url 取網域（去掉 www.）
private func host(from urlString: String) -> String? {
    guard let url = URL(string: urlString), let h = url.host else { return nil }
    return h.replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
}

// 上方左側分類膠囊
private struct TagChip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// 右下角「有連結」提示膠囊
private struct LinkChip: View {
    let host: String
    var body: some View {
        Label("前往 · \(host)", systemImage: "arrow.up.right.square")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(.tint)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

// 可重用的公告卡片內容
private struct AnnouncementCard: View {
    let message: String
    let author: String
    let tag: String
    let urlString: String?
    let onTap: () -> Void

    var hasURL: Bool { (urlString?.isEmpty == false) && (URL(string: urlString!) != nil) }
    var tagMeta: (title: String, color: Color) { tagInfo(tag) }

    var body: some View {
        ZStack {
            // 背景卡片（適配 iOS 26 Liquid Glass 風格）
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 8) {
                // 左上分類
                HStack {
                    TagChip(text: tagMeta.title, color: tagMeta.color)

                    Spacer()

                    if hasURL, let h = host(from: urlString!) {
                        LinkChip(host: h)
                    }
                }

                // 內文
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .lineSpacing(2)
                    .foregroundStyle(.primary)
                    .padding(.top, 2)

                Spacer(minLength: 6)

                // 底部：作者
                Label(author, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)

            }
            .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture { if hasURL { onTap() } }   // 只有有連結時才動作
        .opacity(hasURL ? 1 : 0.9)                // 無連結略微降噪
        .contextMenu {                            // 長按選單（有連結時）
            if hasURL, let urlStr = urlString {
                Button("開啟連結", systemImage: "arrow.up.right.square") { onTap() }
                Button("複製連結", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = urlStr
                }
            }
        }
        .accessibilityAddTraits(.isButton)
    }
}
