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
    @ObservedObject private var rewardedAd = RewardedAdManager.shared
    @State private var showAdConfirm = false
    @State private var showNotReadyAlert = false
    @StateObject var weatherManager = WeatherManager()  // 新增 weather manager
    
    @State private var urlString: String? = nil
    @State private var showWebView = false
    @State private var showSafariView = false
    @State private var selectDemo = 0
    
    let cardShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    
    //Course
    @ObservedObject var courseData: CourseData
    @ObservedObject var memoManager: MemoManager
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
    @State private var isDragging = false   // 追蹤用戶是否正在拖動
    
    
    @State private var goSchoolPosts = false
    @State private var goLinks = false
    @State private var goRandomFood = false
    @State private var goToday = false
    @State private var goTraffic = false  // 新增：前往交通頁面
    @State private var showFoodMenu = false  // 新增：顯示餐廳選單
    @State private var goBreakfast = false
    @State private var goLunch = false
    @State private var goDinner = false
    @State private var goMidnightSnack = false
    @State private var showTodayTasks = false  // 新增：顯示今日代辦展開
    @State private var selectedMemoForDetail: Memo? = nil  // 新增：選中的備忘錄
    @State private var showWeatherDetail = false  // 新增：顯示天氣詳情
    
    @State private var peekCourse: Course? = nil
    
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0

    // greeting
    @AppStorage("commentNickname") private var nickname: String = ""
    @State private var greetingText = ""

    // 初始化 MemoManager
    init(courseData: CourseData, memoManager: MemoManager) {
        self.courseData = courseData
        self.memoManager = memoManager
    }
    
    // MARK: - 子視圖

    private func buildGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let station = weatherManager.weatherDatas?.records.Station.first
        let weather = station?.WeatherElement.Weather ?? ""
        let temp = Double(station?.WeatherElement.AirTemperature ?? "") ?? 20.0
        let name = nickname.isEmpty ? "" : " \(nickname)"
        let isRain = weather.contains(String(localized: "rain_keyword"))
        let isCold = temp < 14
        let isHot = temp >= 33
        let isWarm = !isRain && temp >= 20 && temp <= 27

        var candidates: [String] = []

        switch hour {
        case 5..<9:  candidates += [String(localized: "greeting_morning_1 \(name)"), String(localized: "greeting_morning_2 \(name)")]
        case 9..<12: candidates += [String(localized: "greeting_late_morning_1 \(name)"), String(localized: "greeting_late_morning_2 \(name)")]
        case 12..<14: candidates += [String(localized: "greeting_noon_1 \(name)"), String(localized: "greeting_noon_2 \(name)")]
        case 14..<18: candidates += [String(localized: "greeting_afternoon_1 \(name)"), String(localized: "greeting_afternoon_2 \(name)")]
        case 18..<22: candidates += [String(localized: "greeting_evening_1 \(name)"), String(localized: "greeting_evening_2 \(name)")]
        default:     candidates += [String(localized: "greeting_night_1 \(name)"), String(localized: "greeting_night_2 \(name)")]
        }

        if isRain { candidates += [String(localized: "greeting_rain_1 \(name)"), String(localized: "greeting_rain_2 \(name)")] }
        if isCold  { candidates += [String(localized: "greeting_cold_1 \(name)"), String(localized: "greeting_cold_2 \(Int(temp)) \(name)")] }
        if isHot   { candidates += [String(localized: "greeting_hot_1 \(name)"), String(localized: "greeting_hot_2 \(Int(temp)) \(name)")] }
        if isWarm  { candidates += [String(localized: "greeting_warm_1 \(name)"), String(localized: "greeting_warm_2 \(name)")] }

        candidates += [
            String(localized: "greeting_general_1 \(name)"),
            String(localized: "greeting_general_2 \(name)"),
            String(localized: "greeting_general_3 \(name)"),
            String(localized: "greeting_general_4 \(name)")
        ]

        return candidates.randomElement() ?? String(localized: "greeting_welcome \(name)")
    }

    // 天气 Toolbar 按钮
    @ViewBuilder
    private func weatherToolbarButton(station: Station) -> some View {
        let weather = station.WeatherElement.Weather
        let currentTemp = station.WeatherElement.AirTemperature
        
        Button {
            showWeatherDetail = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: weatherIcon(weather))
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(weatherTint(weather))
                
                Text(safeTemp(currentTemp))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
    }
    
    // 天气详情 Sheet
    @ViewBuilder
    private var weatherDetailSheet: some View {
        if let weatherData = weatherManager.weatherDatas,
           let station = weatherData.records.Station.first {
            NavigationStack {
                WeatherDetailView(station: station)
                    .navigationTitle(String(localized: "weather_detail"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "close")) {
                                showWeatherDetail = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    @ViewBuilder
    private var weatherBannerSection: some View {
        Section {
            if let weatherData = weatherManager.weatherDatas,
               let station = weatherData.records.Station.first {
                weatherBannerView(station: station)
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                        .onAppear { weatherManager.fetchData() }
                    Spacer()
                }
                .frame(height: 50)
            }
        }
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private func weatherBannerView(station: Station) -> some View {
        let weather = station.WeatherElement.Weather
        let currentTemp = station.WeatherElement.AirTemperature
        let maxTemp = station.WeatherElement.DailyExtreme.DailyHigh.TemperatureInfo.AirTemperature
        let minTemp = station.WeatherElement.DailyExtreme.DailyLow.TemperatureInfo.AirTemperature
        
        HStack(spacing: 12) {
            // 天氣圖示
            ZStack {
                Circle()
                    .fill(weatherTint(weather).opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: weatherIcon(weather))
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(weatherTint(weather))
            }
            
            // 天氣資訊
            VStack(alignment: .leading, spacing: 3) {
                Text(weather)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 10) {
                    Text(safeTemp(currentTemp))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text(String(localized: "high_low_temp \(safeTemp(maxTemp)) \(safeTemp(minTemp))"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }
    
    @ViewBuilder
    private var nextCourseSection: some View {
        Section(String(localized: "next_course")) {
            if let c = nextCourseOnAppear {
                nextCourseCard(course: c)
            } else {
                noCourseCard
            }
        }
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private func nextCourseCard(course: Course) -> some View {
        Button {
            peekCourse = course
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // 左側圖示圓點
                ZStack {
                    Circle()
                        .fill(slotTint(course.timeSlot).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(slotTint(course.timeSlot))
                }

                // 主要文字
                courseInfoView(course: course)

                Spacer()

                if course.isNotification {
                    Image(systemName: "bell.fill")
                        .font(.callout)
                        .foregroundStyle(slotTint(course.timeSlot))
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(slotTint(course.timeSlot))
                            .frame(width: 4)
                            .padding(.vertical, 8)
                            .padding(.leading, 6)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    
    @ViewBuilder
    private func courseInfoView(course: Course) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(course.name)
                .font(.headline)
                .lineLimit(1)

            // 時間 + 倒數
            HStack(spacing: 8) {
                Label("\(course.day) • \(course.startTime.rawValue)", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let m = minutesUntilStart(of: course) {
                    Text(String(localized: "minutes_remaining \(m-5)"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(slotTint(course.timeSlot).opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // 地點 + 老師
            HStack(spacing: 12) {
                Label(course.location.isEmpty ? "—" : course.location,
                      systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label(course.teacher.isEmpty ? "—" : course.teacher,
                      systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private var noCourseCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "no_more_courses_today"))
                    .font(.headline)
                Text(String(localized: "take_a_rest"))
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
    
    @ViewBuilder
    private var todayTasksSection: some View {
        Section {
            todayTasksDisclosureGroup
        }
    }
    
    @ViewBuilder
    private var todayTasksDisclosureGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showTodayTasks.toggle()
            } label: {
                todayTasksLabel
            }
            .buttonStyle(.plain)
            .animation(nil, value: showTodayTasks)
            
            if showTodayTasks {
                todayTasksList
                    .transition(.opacity.combined(with: .scale(scale: 1.0, anchor: .top)))
                    .animation(.easeInOut(duration: 0.25), value: showTodayTasks)
            }
        }
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    
    @ViewBuilder
    private var todayTasksList: some View {
        let todayMemos = getTodayMemos()
        if todayMemos.isEmpty {
            Text(String(localized: "no_today_tasks"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
        } else {
            VStack(spacing: 0) {
                ForEach(todayMemos) { memo in
                    todayTaskRow(memo: memo)
                    
                    if memo.id != todayMemos.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    private func nextStatusName(_ currentStatus: Memo.MemoStatus) -> String {
        switch currentStatus {
        case .todo: return String(localized: "status_doing")
        case .doing: return String(localized: "status_done")
        case .done: return String(localized: "status_todo")
        case .snoozed: return String(localized: "status_doing")
        }
    }
    
    @ViewBuilder
    private func todayTaskRow(memo: Memo) -> some View {
        Button {
            selectedMemoForDetail = memo
        } label: {
            HStack(spacing: 12) {
                // 狀態圖示
                ZStack {
                    Circle()
                        .fill(memo.status.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: memo.status.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(memo.status.color)
                }
                
                // 主要內容
                VStack(alignment: .leading, spacing: 2) {
                    Text(memo.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 3) {
                        HStack(spacing: 2) {
                            Image(systemName: memo.tagType.icon)
                            Text(memo.tagType.displayName)
                        }
                            .font(.caption2)
                            .foregroundStyle(memo.tagType.color)
                        
                        if let desc = memo.dueDateDescription {
                            Text("• \(desc)")
                                .font(.caption2)
                                .foregroundStyle(memo.isOverdue ? .red : .secondary)
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var todayTasksLabel: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "checklist")
                    .font(.title3)
                    .foregroundStyle(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "today_tasks"))
                    .font(.headline)
                
                todayTasksStatsView
            }
            
            Spacer()
            
            Image(systemName: showTodayTasks ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        }
    }
    
    @ViewBuilder
    private var todayTasksStatsView: some View {
        let stats = getTodayMemoStats()
        HStack(spacing: 8) {
            if stats.overdue > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(String(localized: "overdue_count \(stats.overdue)"))
                }
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if stats.planExpired > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "calendar.badge.exclamationmark")
                    Text(String(localized: "plan_expired_count \(stats.planExpired)"))
                }
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
            if stats.today > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                    Text(String(localized: "today_tasks_count \(stats.today)"))
                }
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if stats.total > 0 && stats.overdue == 0 && stats.today == 0 && stats.planExpired == 0 {
                HStack(spacing: 2) {
                    Image(systemName: "list.bullet")
                    Text(String(localized: "in_progress_count \(stats.total)"))
                }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if stats.total == 0 {
                Text(String(localized: "no_tasks"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var weatherSection: some View {
        Section {
            if let weatherData = weatherManager.weatherDatas,
               let station = weatherData.records.Station.first {
                compactWeatherView(station: station)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                        .onAppear { weatherManager.fetchData() }
                    Spacer()
                }
                .frame(height: 60)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        }
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private var quickFeaturesSection: some View {
        Section(String(localized: "quick_features")) {
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 12) {
                Button { goSchoolPosts = true } label: {
                    featureCard(icon: "text.bubble.fill", title: String(localized: "school_announcements"), iconColor: .blue)
                }
                .buttonStyle(.plain).contentShape(Rectangle())

                Button { goLinks = true } label: {
                    featureCard(icon: "macwindow", title: String(localized: "common_links"), iconColor: .green)
                }
                .buttonStyle(.plain).contentShape(Rectangle())

                if #available(iOS 17.0, *) {
                    Button { goRandomFood = true } label: {
                        featureCard(icon: "chart.pie.fill", title: String(localized: "food_wheel"), iconColor: .orange)
                    }
                    .buttonStyle(.plain).contentShape(Rectangle())
                }
                
                Button { goTraffic = true } label: {
                    featureCard(icon: "bicycle", title: "Ubike", iconColor: .green)
                }
                .buttonStyle(.plain).contentShape(Rectangle())
                
                Button { showFoodMenu = true } label: {
                    featureCard(icon: "fork.knife", title: String(localized: "restaurant"), iconColor: .red)
                }
                .buttonStyle(.plain).contentShape(Rectangle())
            }
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    orderSection
                    nextCourseSection
                    todayTasksSection
                    quickFeaturesSection
                    // Native 廣告 Section
                    if !adFree.isAdFree {
                        Section {
                            NativeAdSectionView(style: .compact)
                                .frame(height: 140)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.tertiarySystemBackground))
                                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }
                .navigationTitle("NTPU one")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 1) {
                            Text("NTPU one")
                                .font(.headline.bold())
                            if !greetingText.isEmpty {
                                Text(greetingText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onAppear {
                    nextCourseOnAppear = nextUpcomingCourse()
                    webManager.createData()
                    memoManager.loadMemosFromCoreData()
                    greetingText = buildGreeting()
                }
                .onChange(of: weatherManager.weatherDatas?.records.Station.first?.WeatherElement.AirTemperature) { _ in
                    greetingText = buildGreeting()
                }
                .onChange(of: nickname) { _ in
                    greetingText = buildGreeting()
                }
                .sheet(isPresented: $showWebView) {
                    if let urlString = urlString {
                        WebDetailView(url: urlString)
                    }
                }
                .sheet(item: $peekCourse) { course in
                    CourseDetailSheet(course: course, memoManager: memoManager, courseData: courseData)
                        .presentationDetents([.fraction(0.35)])
                        .presentationDragIndicator(.visible)
                }
                .sheet(item: $selectedMemoForDetail, onDismiss: {
                    // 當備忘錄詳情 sheet 關閉時，重新加載數據以確保任務列表更新
                    memoManager.loadMemosFromCoreData()
                }) { memo in
                    MemoDetailSheet(memoManager: memoManager, courseData: courseData, memo: memo)
                }
                .sheet(isPresented: $showWeatherDetail) {
                    weatherDetailSheet
                }
                // 底部廣告已移除，改用 List 內 Native Ad
                // 放在 NavigationStack 裡、List 後面（同一層）
                NavigationLink(destination: SchoolPostView(), isActive: $goSchoolPosts) { EmptyView() }.hidden()

                NavigationLink(destination: CommonLinksView(), isActive: $goLinks) { EmptyView() }.hidden()

                if #available(iOS 17.0, *) {
                    NavigationLink(
                        destination: RandomFoodView(),
                        isActive: $goRandomFood
                    ) { EmptyView() }
                    .hidden()
                }
                
                // 今日頁面 NavigationLink
                NavigationLink(
                    destination: TodayView(memoManager: memoManager, courseData: courseData),
                    isActive: $goToday
                ) { EmptyView() }
                .hidden()
                
                // 新增：交通（Ubike）NavigationLink
                if #available(iOS 17.0, *) {
                    NavigationLink(
                        destination: TrafficView(),
                        isActive: $goTraffic
                    ) { EmptyView() }
                    .hidden()
                } else {
                    NavigationLink(
                        destination: BackTrafficView(),
                        isActive: $goTraffic
                    ) { EmptyView() }
                    .hidden()
                }
                
                // 新增：餐廳選單 NavigationLinks
                NavigationLink(destination: BreakfastView(), isActive: $goBreakfast) { EmptyView() }.hidden()
                NavigationLink(destination: LunchView(), isActive: $goLunch) { EmptyView() }.hidden()
                NavigationLink(destination: dinnerView(), isActive: $goDinner) { EmptyView() }.hidden()
                NavigationLink(destination: MSView(), isActive: $goMidnightSnack) { EmptyView() }.hidden()
            }
            .sheet(isPresented: $showFoodMenu) {
                foodMenuSheet
            }
            .toolbar {
                // 左上角天气按钮
                ToolbarItem(placement: .topBarLeading) {
                    if let weatherData = weatherManager.weatherDatas,
                       let station = weatherData.records.Station.first {
                        weatherToolbarButton(station: station)
                    } else {
                        Button {
                            // 加载中不可点击
                        } label: {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .disabled(true)
                        .onAppear { weatherManager.fetchData() }
                    }
                }
                
                // 右上角按鈕
                ToolbarItem(placement: toolbarPlacementTrailing) {
                    if adFree.isAdFree {
                        Label(String(localized: "no_banner_today"), systemImage: "checkmark.seal.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.green)
                            .help(String(localized: "no_banner_until_midnight"))
                    } else {
                        Button {
                            if !rewardedAd.isLoading {
                                showAdConfirm = true
                            }
                        } label: {
                            if rewardedAd.isLoading {
                                ProgressView()
                            } else {
                                Label(String(localized: "watch_video_disable_banner"), systemImage: "film.stack")
                                    .labelStyle(.iconOnly)
                            }
                        }
                        .disabled(rewardedAd.isLoading)
                        .help(String(localized: "after_watching_disable_banner"))
                    }
                }
            }
            .onAppear { preloadRewardedIfNeeded() }
            .alert(String(localized: "disable_today_banner_title"), isPresented: $showAdConfirm) {
                Button(String(localized: "cancel"), role: .cancel) { }
                Button(String(localized: "start_watching")) {
                    if rewardedAd.isLoading || !rewardedAd.isReady {
                        showNotReadyAlert = true
                    } else {
                        showRewarded()
                    }
                }
            } message: {
                Text(String(localized: "disable_banner_message"))
            }
            .alert(String(localized: "video_not_ready"), isPresented: $showNotReadyAlert) {
                Button(String(localized: "ok"), role: .cancel) { }
            } message: {
                Text(rewardedAd.remainingViews > 0 ? String(localized: "loading_ad_retry") : String(localized: "daily_view_limit_reached"))
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
    
    // 取得今日待辦統計
    private func getTodayMemoStats() -> (overdue: Int, planExpired: Int, today: Int, total: Int) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let now = Date()
        let overdue = memoManager.memos.filter { memo in
            memo.status != .done && memo.isOverdue
        }.count
        
        let planExpired = memoManager.memos.filter { memo in
            guard memo.status != .done, let planAt = memo.planAt else { return false }
            if let dueAt = memo.dueAt, dueAt < now { return false }
            return planAt < todayStart
        }.count
        
        let todayCount = memoManager.memos.filter { memo in
            guard memo.status != .done && !memo.isOverdue else { return false }
            if let dueAt = memo.dueAt, dueAt >= todayStart && dueAt < tomorrow { return true }
            if let planAt = memo.planAt, planAt >= todayStart && planAt < tomorrow { return true }
            return false
        }.count
        
        let total = memoManager.memos.filter { $0.status != .done }.count
        
        return (overdue, planExpired, todayCount, total)
    }
    
    // 新增：取得今日待辦任務列表
    private func getTodayMemos() -> [Memo] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        return memoManager.memos.filter { memo in
            guard memo.status != .done else { return false }
            
            // 包含逾期的任務
            if memo.isOverdue { return true }
            
            // 今日截止的任務
            if let dueAt = memo.dueAt, dueAt >= todayStart && dueAt < tomorrow { return true }
            
            // 今日計劃的任務
            if let planAt = memo.planAt, planAt >= todayStart && planAt < tomorrow { return true }
            
            return false
        }
        .sorted { memo1, memo2 in
            // 優先顯示逾期的
            if memo1.isOverdue && !memo2.isOverdue { return true }
            if !memo1.isOverdue && memo2.isOverdue { return false }
            
            // 然後按截止時間排序
            if let due1 = memo1.dueAt, let due2 = memo2.dueAt {
                return due1 < due2
            }
            return false
        }
    }
    
    // 新增：簡化版天氣視圖
    @ViewBuilder
    private func compactWeatherView(station: Station) -> some View {
        let weather = station.WeatherElement.Weather
        let currentTemp = station.WeatherElement.AirTemperature
        let maxTemp = station.WeatherElement.DailyExtreme.DailyHigh.TemperatureInfo.AirTemperature
        let minTemp = station.WeatherElement.DailyExtreme.DailyLow.TemperatureInfo.AirTemperature
        
        HStack(spacing: 12) {
            // 天氣圖示
            ZStack {
                Circle()
                    .fill(weatherTint(weather).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: weatherIcon(weather))
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(weatherTint(weather))
            }
            
            // 天氣資訊
            VStack(alignment: .leading, spacing: 2) {
                Text(weather)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    Text(safeTemp(currentTemp))
                        .font(.title3.weight(.bold))
                    Text(String(localized: "high_low_temp \(safeTemp(maxTemp)) \(safeTemp(minTemp))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        }
    }
    
    // 新增：餐廳選單 Sheet
    private var foodMenuSheet: some View {
        NavigationStack {
            List {
                Button {
                    goBreakfast = true
                    showFoodMenu = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 40)
                        Text(String(localized: "breakfast"))
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Button {
                    goLunch = true
                    showFoodMenu = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "carrot.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 40)
                        Text(String(localized: "lunch"))
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Button {
                    goDinner = true
                    showFoodMenu = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "wineglass.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                            .frame(width: 40)
                        Text(String(localized: "dinner"))
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Button {
                    goMidnightSnack = true
                    showFoodMenu = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                            .frame(width: 40)
                        Text(String(localized: "midnight_snack"))
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle(String(localized: "choose_meal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close")) {
                        showFoodMenu = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // 天氣相關輔助函數
    private func safeTemp(_ s: String) -> String {
        (s == "-99" || s.isEmpty) ? "—" : "\(s)°"
    }
    
    private func weatherTint(_ text: String) -> Color {
        if text.contains("雷") { return .purple }
        if text.contains("雪") { return .indigo }
        if text.contains("雨") { return .teal }
        if text.contains("陰") { return .gray }
        if text.contains("多雲") { return .blue }
        return .orange
    }
    
    private func weatherIcon(_ weather: String) -> String {
        if weather.contains("晴") && weather.contains("雨") { return "cloud.sun.rain" }
        if weather.contains("晴") { return "sun.max" }
        if weather.contains("多雲") && weather.contains("雨") { return "cloud.rain" }
        if weather.contains("多雲") { return "cloud.sun" }
        if weather.contains("陰") { return "cloud" }
        if weather.contains("雨") { return "cloud.rain" }
        return "cloud"
    }

    
    // iOS 17 用 .topBarTrailing；iOS 16/15 用 .navigationBarTrailing
    private var toolbarPlacementTrailing: ToolbarItemPlacement {
        if #available(iOS 17.0, *) { return .topBarTrailing }
        else { return .navigationBarTrailing }
    }

    private func preloadRewardedIfNeeded() {
        guard !adFree.isAdFree else { return }
        rewardedAd.preload()
    }

    private func showRewarded() {
        rewardedAd.present(onReward: {
            adFree.grantForTodayEnd()
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
                            Text(String(localized: "tag_activity")).tag(1)
                            Text(String(localized: "tag_club")).tag(2)
                            Text(String(localized: "tag_other")).tag(3)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Spacer()
                    }
                } footer: {
                    VStack {
                        Text(String(localized: "add_broadcast_hint"))
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
                    Text(String(localized: "connecting_check_network"))
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
                            Text(String(localized: "connecting_check_network"))
                        }
                    }
                } else {
                    webLinks(for: webs.webs)
                }
            }
        }
    }
    
    private func disclosureGroup(for webs: WebsArray) -> some View {
        DisclosureGroup(String(localized: "department_websites")) {
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
                Text(String(localized: "course_selection_desktop_hint"))
            } else if id == 3 {
                Text(String(localized: "graduate_abbreviation_hint"))
            }
        }
    }
    
    var DemoView: some View {
        let orders = orderManager.order ?? []
        // 計算含 native ad 的總頁數（每 3 個廣播後插入 1 個 native ad）
        let nativeAdInterval = 3
        let nativeAdCount = orders.count >= nativeAdInterval ? orders.count / nativeAdInterval : 0
        let totalPages = orders.count + nativeAdCount

        return TabView(selection: $startIndex) {
            ForEach(0..<totalPages, id: \.self) { pageIndex in
                let nativeAdsBefore = nativeAdInterval > 0 ? pageIndex / (nativeAdInterval + 1) : 0
                let isNativeAdPage = nativeAdInterval > 0 && (pageIndex + 1) % (nativeAdInterval + 1) == 0
                Group {
                    if isNativeAdPage && !adFree.isAdFree {
                        NativeAdSectionView(style: .compact, showCardBackground: true)
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .padding(.horizontal, 8)
                    } else {
                        let orderIndex = pageIndex - nativeAdsBefore
                        if orderIndex < orders.count {
                            let item = orders[orderIndex]
                            AnnouncementCard(
                                message: item.message,
                                author: "— \(item.name)",
                                tag: item.tag,
                                urlString: item.url,
                                email: item.email,
                                time: item.time
                            ) {
                                handleURL(item.url)
                            }
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .tag(pageIndex)
            }
        }
        .id("DemoView-\(orders.count)")
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isDragging = true }
                .onEnded { _ in isDragging = false }
        )
        .onReceive(timer) { _ in
            guard !isDragging else { return }
            withAnimation {
                if totalPages > 1 {
                    startIndex = (startIndex + 1) % totalPages
                }
            }
        }
        .onChange(of: orders.count) { _ in
            startIndex = 0
        }
    }

    
    var DemoViewEvent: some View {
        let orders = orderManager.order ?? []
        let filtered = orders.filter { $0.tag == "1" }  // 活動
        let nativeAdInterval = 3
        let nativeAdCount = filtered.count >= nativeAdInterval ? filtered.count / nativeAdInterval : 0
        let totalPages = filtered.count + nativeAdCount

        return TabView(selection: $startIndexE) {
            ForEach(0..<totalPages, id: \.self) { pageIndex in
                let nativeAdsBefore = nativeAdInterval > 0 ? pageIndex / (nativeAdInterval + 1) : 0
                let isNativeAdPage = nativeAdInterval > 0 && (pageIndex + 1) % (nativeAdInterval + 1) == 0
                Group {
                    if isNativeAdPage && !adFree.isAdFree {
                        NativeAdSectionView(style: .compact, showCardBackground: true)
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .padding(.horizontal, 8)
                    } else {
                        let orderIndex = pageIndex - nativeAdsBefore
                        if orderIndex < filtered.count {
                            let item = filtered[orderIndex]
                            AnnouncementCard(
                                message: item.message,
                                author: "— \(item.name)",
                                tag: item.tag,
                                urlString: item.url,
                                email: item.email,
                                time: item.time
                            ) {
                                handleURL(item.url)
                            }
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .tag(pageIndex)
            }
        }
        .id("DemoViewEvent-\(filtered.count)")
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isDragging = true }
                .onEnded { _ in isDragging = false }
        )
        .onReceive(timer) { _ in
            guard !isDragging else { return }
            guard totalPages > 1 else { return }
            withAnimation { startIndexE = (startIndexE + 1) % totalPages }
        }
        .onChange(of: filtered.count) { _ in
            startIndexE = 0
        }
    }

    var DemoViewPost: some View {
        let orders = orderManager.order ?? []
        let filtered = orders.filter { $0.tag == "2" }  // 社團
        let nativeAdInterval = 3
        let nativeAdCount = filtered.count >= nativeAdInterval ? filtered.count / nativeAdInterval : 0
        let totalPages = filtered.count + nativeAdCount

        return TabView(selection: $startIndexP) {
            ForEach(0..<totalPages, id: \.self) { pageIndex in
                let nativeAdsBefore = nativeAdInterval > 0 ? pageIndex / (nativeAdInterval + 1) : 0
                let isNativeAdPage = nativeAdInterval > 0 && (pageIndex + 1) % (nativeAdInterval + 1) == 0
                Group {
                    if isNativeAdPage && !adFree.isAdFree {
                        NativeAdSectionView(style: .compact, showCardBackground: true)
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .padding(.horizontal, 8)
                    } else {
                        let orderIndex = pageIndex - nativeAdsBefore
                        if orderIndex < filtered.count {
                            let item = filtered[orderIndex]
                            AnnouncementCard(
                                message: item.message,
                                author: "— \(item.name)",
                                tag: item.tag,
                                urlString: item.url,
                                email: item.email,
                                time: item.time
                            ) {
                                handleURL(item.url)
                            }
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .tag(pageIndex)
            }
        }
        .id("DemoViewPost-\(filtered.count)")
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isDragging = true }
                .onEnded { _ in isDragging = false }
        )
        .onReceive(timer) { _ in
            guard !isDragging else { return }
            guard totalPages > 1 else { return }
            withAnimation { startIndexP = (startIndexP + 1) % totalPages }
        }
        .onChange(of: filtered.count) { _ in
            startIndexP = 0
        }
    }

    var DemoViewOther: some View {
        let orders = orderManager.order ?? []
        let filtered = orders.filter { $0.tag == "3" }  // 其他
        let nativeAdInterval = 3
        let nativeAdCount = filtered.count >= nativeAdInterval ? filtered.count / nativeAdInterval : 0
        let totalPages = filtered.count + nativeAdCount

        return TabView(selection: $startIndexO) {
            ForEach(0..<totalPages, id: \.self) { pageIndex in
                let nativeAdsBefore = nativeAdInterval > 0 ? pageIndex / (nativeAdInterval + 1) : 0
                let isNativeAdPage = nativeAdInterval > 0 && (pageIndex + 1) % (nativeAdInterval + 1) == 0
                Group {
                    if isNativeAdPage && !adFree.isAdFree {
                        NativeAdSectionView(style: .compact, showCardBackground: true)
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .padding(.horizontal, 8)
                    } else {
                        let orderIndex = pageIndex - nativeAdsBefore
                        if orderIndex < filtered.count {
                            let item = filtered[orderIndex]
                            AnnouncementCard(
                                message: item.message,
                                author: "— \(item.name)",
                                tag: item.tag,
                                urlString: item.url,
                                email: item.email,
                                time: item.time
                            ) {
                                handleURL(item.url)
                            }
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .tag(pageIndex)
            }
        }
        .id("DemoViewOther-\(filtered.count)")
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 160)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isDragging = true }
                .onEnded { _ in isDragging = false }
        )
        .onReceive(timer) { _ in
            guard !isDragging else { return }
            guard totalPages > 1 else { return }
            withAnimation { startIndexO = (startIndexO + 1) % totalPages }
        }
        .onChange(of: filtered.count) { _ in
            startIndexO = 0
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
func tagInfo(_ tag: String) -> (title: String, color: Color) {
    switch tag {
    case "1": return (String(localized: "tag_activity"), .blue)
    case "2": return (String(localized: "tag_club"), .green)
    case "3": return (String(localized: "tag_other"), .orange)
    default:  return (String(localized: "tag_announcement"), .gray)
    }
}

// 從 url 取網域（去掉 www.）
func host(from urlString: String) -> String? {
    guard let url = URL(string: urlString), let h = url.host else { return nil }
    return h.replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
}

// 上方左側分類膠囊
struct TagChip: View {
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
struct LinkChip: View {
    let host: String
    var body: some View {
        Label(String(localized: "go_to_host \(host)"), systemImage: "arrow.up.right.square")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(.tint)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

// 可重用的公告卡片內容
struct AnnouncementCard: View {
    let message: String
    let author: String
    let tag: String
    let urlString: String?
    let email: String?          // 圖片網址
    var time: String? = nil     // 新增 time 參數
    let onTap: () -> Void

    var hasURL: Bool { (urlString?.isEmpty == false) && (URL(string: urlString!) != nil) }
    var tagMeta: (title: String, color: Color) { tagInfo(tag) }
    
    /// 判斷是否為圖片型公告（email 和 time 相同且是有效的圖片網址）
    var isImageCard: Bool {
        guard let email = email, !email.isEmpty else { return false }
        guard let time = time, !time.isEmpty else { return false }
        guard email == time else { return false }
        return isValidImageURL(email)
    }
    
    /// 圖片網址（從 email 取得）
    var imageURL: String? {
        guard isImageCard else { return nil }
        return email
    }
    
    private func isValidImageURL(_ urlString: String) -> Bool {
        guard URL(string: urlString) != nil else { return false }
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp"]
        let ext = (urlString as NSString).pathExtension.lowercased()
        return imageExtensions.contains(ext) || urlString.contains("cms-carrier.ntpu.edu.tw")
    }

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
            
            if isImageCard {
                // 圖片型公告
                imageCardContent
            } else {
                // 一般文字型公告
                textCardContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if hasURL { onTap() } }
        .opacity(hasURL ? 1 : 0.9)
        .contextMenu {
            if hasURL, let urlStr = urlString {
                Button(String(localized: "open_link"), systemImage: "arrow.up.right.square") { onTap() }
                Button(String(localized: "copy_link"), systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = urlStr
                }
            }
        }
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - 圖片型公告內容
    private var imageCardContent: some View {
        ZStack {
            // 背景圖片（填滿整個卡片，左右裁切）
            GeometryReader { geo in
                AsyncImage(url: URL(string: imageURL ?? "")) { phase in
                    switch phase {
                    case .empty:
                        Color(.systemGray5)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    case .failure:
                        Color(.systemGray5)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            
            // 漸層遮罩（讓文字更清楚）
            LinearGradient(
                colors: [.black.opacity(0.5), .black.opacity(0.1), .black.opacity(0.1), .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 資訊層（固定佈局，和文字型一樣的結構）
            VStack(alignment: .leading, spacing: 8) {
                // 頂部：標籤 + 連結
                HStack {
                    TagChip(text: tagMeta.title, color: .white)
                        .background(tagMeta.color.opacity(0.85), in: Capsule())

                    Spacer()

                    if hasURL, let h = host(from: urlString!) {
                        Label(String(localized: "go_to_host \(h)"), systemImage: "arrow.up.right.square")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(.white.opacity(0.3), in: Capsule())
                    }
                }

                Spacer(minLength: 6)

                // 底部：作者
                Label(author, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .labelStyle(.titleAndIcon)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - 一般文字型公告內容
    private var textCardContent: some View {
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
}

// MARK: - WeatherDetailView
struct WeatherDetailView: View {
    let station: Station
    
    var body: some View {
        let weather = station.WeatherElement.Weather
        let currentTemp = station.WeatherElement.AirTemperature
        let maxTemp = station.WeatherElement.DailyExtreme.DailyHigh.TemperatureInfo.AirTemperature
        let minTemp = station.WeatherElement.DailyExtreme.DailyLow.TemperatureInfo.AirTemperature
        let windSpeed = station.WeatherElement.WindSpeed
        let humidity = station.WeatherElement.RelativeHumidity
        let time = station.ObsTime.DateTime
        
        ScrollView {
            VStack(spacing: 20) {
                // 主要天气信息
                VStack(spacing: 16) {
                    // 天气图标
                    ZStack {
                        Circle()
                            .fill(weatherTint(weather).opacity(0.15))
                            .frame(width: 120, height: 120)
                        Image(systemName: weatherIcon(weather))
                            .font(.system(size: 60))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(weatherTint(weather))
                    }
                    
                    // 天气描述
                    Text(weather)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    // 当前温度
                    Text(safeTemp(currentTemp))
                        .font(.system(size: 72, weight: .thin))
                        .foregroundStyle(.primary)
                    
                    // 高低温
                    HStack(spacing: 20) {
                        VStack {
                            Text(String(localized: "highest"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(safeTemp(maxTemp))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        VStack {
                            Text(String(localized: "lowest"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(safeTemp(minTemp))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.top, 20)
                
                // 详细信息卡片
                VStack(spacing: 12) {
                    weatherInfoRow(icon: "wind", title: String(localized: "wind_speed"), value: safeWind(windSpeed))
                    Divider()
                    weatherInfoRow(icon: "humidity", title: String(localized: "humidity"), value: safeHumidity(humidity))
                    Divider()
                    weatherInfoRow(icon: "clock", title: String(localized: "update_time"), value: shortTimeString(time))
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                }
                .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
        }
    }
    
    @ViewBuilder
    private func weatherInfoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
    
    private func safeTemp(_ s: String) -> String {
        (s == "-99" || s.isEmpty) ? "—" : "\(s)°C"
    }
    
    private func safeWind(_ s: String) -> String {
        (s == "-99" || s.isEmpty) ? "—" : "\(s) m/s"
    }
    
    private func safeHumidity(_ s: String) -> String {
        (s == "-99" || s.isEmpty) ? "—" : "\(s)%"
    }
    
    private func shortTimeString(_ s: String) -> String {
        guard s.count >= 16 else { return "—" }
        let start = s.index(s.startIndex, offsetBy: 11)
        let end = s.index(start, offsetBy: 5, limitedBy: s.endIndex) ?? s.endIndex
        return String(s[start..<end])
    }
    
    private func weatherTint(_ text: String) -> Color {
        if text.contains("雷") { return .purple }
        if text.contains("雪") { return .indigo }
        if text.contains("雨") { return .teal }
        if text.contains("陰") { return .gray }
        if text.contains("多雲") { return .blue }
        return .orange
    }
    
    private func weatherIcon(_ weather: String) -> String {
        if weather.contains("晴") && weather.contains("雨") { return "cloud.sun.rain" }
        if weather.contains("晴") { return "sun.max" }
        if weather.contains("多雲") && weather.contains("雨") { return "cloud.rain" }
        if weather.contains("多雲") { return "cloud.sun" }
        if weather.contains("陰") { return "cloud" }
        if weather.contains("雨") { return "cloud.rain" }
        if weather.contains("雷") { return "cloud.bolt.rain" }
        if weather.contains("雪") { return "cloud.snow" }
        return "cloud"
    }
}
