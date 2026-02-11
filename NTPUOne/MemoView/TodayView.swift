//
//  TodayView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//

import SwiftUI
import UserNotifications
import GoogleMobileAds

// MARK: - 優先級標籤元件
struct PriorityBadge: View {
    let priority: Memo.Priority
    var compact: Bool = false
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: priority.icon)
                .font(.caption2)
            if !compact {
                Text(priority.displayName)
                    .font(.caption2.weight(.medium))
            }
        }
        .foregroundColor(priority == .low ? .secondary : priority.color)
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(priority == .low ? Color.clear : priority.color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(priority == .low ? Color.secondary.opacity(0.3) : Color.clear, lineWidth: 0.5)
        )
    }
}

struct TodayView: View {
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    @EnvironmentObject var adFree: AdFreeService
    
    @State private var selectedTab = 0
    @State private var showAddMemo = false
    @State private var selectedMemo: Memo? = nil
    @State private var editingMemo: Memo? = nil
    @State private var presetCourseLink: String? = nil
    @State private var allTasksGroupMode: AllTasksGroupMode = .byCourse
    @State private var isManualOrderingTodayPlan = false
    @State private var manualPlannedTodayOrder: [String] = []
    @State private var todayEditMode: EditMode = .inactive
    @State private var statusPickerMemo: Memo? = nil
    @State private var showScheduledSheet = false
    @State private var scheduledMemos: [ScheduledMemoInfo] = []
    @State private var isLoadingScheduledMemos = false
    
    private let calendar = Calendar.current
    
    enum AllTasksGroupMode: String, CaseIterable, Identifiable {
        case byCourse = "依課程"
        case byPriority = "依重要程度"
        case byTag = "依類型"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                navigationContent
            }
            
            // 横幅广告
            if !adFree.isAdFree {
                BannerAdView()
                    .frame(height: 50)
            }
        }
        .onAppear {
            loadManualPlannedTodayOrder()
            syncManualOrderWithCurrentTasks()
        }
        .onChange(of: plannedTodayTaskIds) { _ in
            syncManualOrderWithCurrentTasks()
        }
        .sheet(isPresented: $showAddMemo) {
            MemoFormView(
                memoManager: memoManager,
                courseData: courseData,
                memo: nil,
                presetCourseLink: presetCourseLink,
                presetPlanAt: Date()
                )
            }
            .sheet(isPresented: $showScheduledSheet) {
                ScheduledNotificationsSheet(
                    items: scheduledMemos,
                    isLoading: isLoadingScheduledMemos,
                    courseNameProvider: getCourseName(for:),
                    onRefresh: loadScheduledMemos
                )
            }
            .sheet(item: $statusPickerMemo) { memo in
                StatusPickerSheet(memo: memo) { status in
                    memoManager.updateStatus(memo, to: status)
                }
            }
            .sheet(item: $selectedMemo) { memo in
                MemoDetailSheet(
                    memoManager: memoManager,
                    courseData: courseData,
                    memo: memo
            )
        }
        .sheet(item: $editingMemo) { memo in
            MemoFormView(
                memoManager: memoManager,
                courseData: courseData,
                memo: memo
            )
        }
    }

    private var navigationContent: some View {
        mainStack
            .navigationTitle("備忘錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
    }

    private var mainStack: some View {
        VStack(spacing: 0) {
            // 頂部統計
            todayHeader
            
            // Tab 選擇器
            tabPicker
            
            // 內容區（使用普通切換，不用 page style）
            Group {
                if memoManager.filterStatus == .done {
                    completedTasksView
                } else {
                    switch selectedTab {
                    case 0:
                        todayTasksView
                    case 1:
                        upcomingView
                    case 2:
                        allTasksView
                    default:
                        todayTasksView
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                presetCourseLink = nil
                showAddMemo = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 12) {
                // 排序選項
                Menu {
                    ForEach(MemoManager.SortOption.allCases, id: \.self) { option in
                        Button {
                            memoManager.sortBy = option
                            memoManager.applyFiltersAndSort()
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if memoManager.sortBy == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 除錯選項
                    Button {
                        showScheduledSheet = true
                        loadScheduledMemos()
                    } label: {
                        Label("列出排程通知", systemImage: "list.bullet")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
                
                // 篩選選單
                Menu {
                    // 狀態篩選區塊
                    Section("狀態篩選") {
                        Button {
                            if memoManager.filterStatus == nil && memoManager.filterIncompleteOnly {
                                memoManager.filterIncompleteOnly = false
                            } else {
                                memoManager.filterStatus = nil
                                memoManager.filterIncompleteOnly = true
                            }
                            memoManager.applyFiltersAndSort()
                        } label: {
                            HStack {
                                Text("未完成")
                                if memoManager.filterStatus == nil && memoManager.filterIncompleteOnly {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        ForEach([Memo.MemoStatus.todo, .doing, .done, .snoozed], id: \.self) { status in
                            Button {
                                if memoManager.filterStatus == status {
                                    memoManager.filterStatus = nil
                                } else {
                                    memoManager.filterStatus = status
                                    memoManager.filterIncompleteOnly = false
                                }
                                memoManager.applyFiltersAndSort()
                            } label: {
                                HStack {
                                    Text(status.displayName)
                                    if memoManager.filterStatus == status {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    // 類型篩選區塊（多選）
                    Section("類型篩選（可多選）") {
                        ForEach(Memo.TagType.allCases, id: \.self) { tagType in
                            Button {
                                if memoManager.filterTagTypes.contains(tagType) {
                                    memoManager.filterTagTypes.remove(tagType)
                                } else {
                                    memoManager.filterTagTypes.insert(tagType)
                                }
                                memoManager.applyFiltersAndSort()
                            } label: {
                                HStack {
                                    Text(tagType.rawValue)
                                    if memoManager.filterTagTypes.contains(tagType) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    // 其他篩選
                    Section("其他") {
                        Button {
                            memoManager.showOverdueOnly.toggle()
                            memoManager.applyFiltersAndSort()
                        } label: {
                            HStack {
                                Text("僅顯示逾期")
                                if memoManager.showOverdueOnly {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    // 清除篩選
                    if memoManager.filterStatus != nil || memoManager.filterIncompleteOnly || 
                       memoManager.showOverdueOnly || !memoManager.filterTagTypes.isEmpty {
                        Section {
                            Button(role: .destructive) {
                                memoManager.filterStatus = nil
                                memoManager.filterIncompleteOnly = false
                                memoManager.showOverdueOnly = false
                                memoManager.filterTagTypes.removeAll()
                                memoManager.applyFiltersAndSort()
                            } label: {
                                Label("清除所有篩選", systemImage: "xmark.circle")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .symbolVariant(hasActiveFilters ? .fill : .none)
                        .foregroundColor(hasActiveFilters ? .blue : .primary)
                }
            }
        }
    }
    
    // 計算是否有啟用的篩選器
    private var hasActiveFilters: Bool {
        memoManager.filterStatus != nil || 
        memoManager.filterIncompleteOnly || 
        memoManager.showOverdueOnly || 
        !memoManager.filterTagTypes.isEmpty
    }
    
    // MARK: - 頂部統計
    private var todayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 今日統計
            HStack(spacing: 16) {
                VStack {
                    Text("\(todayTasks.count)")
                        .font(.title3.bold())
                        .foregroundColor(.blue)
                    Text("今日")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(overdueTasks.count)")
                        .font(.title3.bold())
                        .foregroundColor(overdueTasks.isEmpty ? .gray : .red)
                    Text("逾期")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(activeMemos.count)")
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                    Text("總計")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab 選擇器
    private var tabPicker: some View {
        HStack(spacing: 0) {
            TabButton(title: "需處理", count: todayTasks.count + overdueTasks.count, isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            TabButton(title: "即將到期", count: upcomingTasks.count, isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            TabButton(title: "所有任務", count: allTasks.count, isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 篩選標籤
    private var filterTagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 狀態篩選
                FilterChipView(
                    title: "未完成",
                    isSelected: memoManager.filterStatus == nil && memoManager.filterIncompleteOnly,
                    color: .gray
                ) {
                    if memoManager.filterStatus == nil && memoManager.filterIncompleteOnly {
                        memoManager.filterIncompleteOnly = false
                    } else {
                        memoManager.filterStatus = nil
                        memoManager.filterIncompleteOnly = true
                    }
                    memoManager.applyFiltersAndSort()
                }
                
                FilterChipView(
                    title: Memo.MemoStatus.todo.displayName,
                    isSelected: memoManager.filterStatus == .todo,
                    color: Memo.MemoStatus.todo.color
                ) {
                    if memoManager.filterStatus == .todo {
                        memoManager.filterStatus = nil
                    } else {
                        memoManager.filterStatus = .todo
                        memoManager.filterIncompleteOnly = false
                    }
                    memoManager.applyFiltersAndSort()
                }
                
                FilterChipView(
                    title: Memo.MemoStatus.doing.displayName,
                    isSelected: memoManager.filterStatus == .doing,
                    color: Memo.MemoStatus.doing.color
                ) {
                    if memoManager.filterStatus == .doing {
                        memoManager.filterStatus = nil
                    } else {
                        memoManager.filterStatus = .doing
                        memoManager.filterIncompleteOnly = false
                    }
                    memoManager.applyFiltersAndSort()
                }
                
                FilterChipView(
                    title: Memo.MemoStatus.done.displayName,
                    isSelected: memoManager.filterStatus == .done,
                    color: Memo.MemoStatus.done.color
                ) {
                    if memoManager.filterStatus == .done {
                        memoManager.filterStatus = nil
                    } else {
                        memoManager.filterStatus = .done
                        memoManager.filterIncompleteOnly = false
                    }
                    memoManager.applyFiltersAndSort()
                }
                
                FilterChipView(
                    title: Memo.MemoStatus.snoozed.displayName,
                    isSelected: memoManager.filterStatus == .snoozed,
                    color: Memo.MemoStatus.snoozed.color
                ) {
                    if memoManager.filterStatus == .snoozed {
                        memoManager.filterStatus = nil
                    } else {
                        memoManager.filterStatus = .snoozed
                        memoManager.filterIncompleteOnly = false
                    }
                    memoManager.applyFiltersAndSort()
                }
                
                Divider()
                    .frame(height: 20)
                
                // 標籤類型篩選
                ForEach(Memo.TagType.allCases) { tag in
                    FilterChipView(
                        title: tag.rawValue,
                        isSelected: memoManager.filterTagTypes.contains(tag),
                        color: tag.color
                    ) {
                        if memoManager.filterTagTypes.contains(tag) {
                            memoManager.filterTagTypes.remove(tag)
                        } else {
                            memoManager.filterTagTypes.insert(tag)
                        }
                        memoManager.applyFiltersAndSort()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 需處理清單
    private var todayTasksView: some View {
        List {
            if overdueTasks.isEmpty && planExpiredTasks.isEmpty && todayTasks.isEmpty && plannedTomorrowTasks.isEmpty {
                Section {
                    emptyTodayView
                }
                .listRowBackground(Color.clear)
            } else {
                // 逾期區塊
                if !overdueTasks.isEmpty {
                    Section {
                        ForEach(overdueTasks) { memo in
                            memoRowWithSwipe(memo: memo)
                                .contextMenu {
                                    Button("加入今日安排") {
                                        moveOverdueToToday(memo)
                                    }
                                }
                        }
                    } header: {
                        sectionHeaderLabel(title: "逾期", color: .red, count: overdueTasks.count)
                    }
                }

                // 計劃過期
                if !planExpiredTasks.isEmpty {
                    Section {
                        ForEach(planExpiredTasks) { memo in
                            memoRowWithSwipe(memo: memo)
                                .contextMenu {
                                    Button("加入今日安排") {
                                        moveMemoToPlannedToday(memo.id, insertAt: nil, markSnoozed: true)
                                    }
                                }
                        }
                    } header: {
                        sectionHeaderLabel(title: "計劃過期", color: .purple, count: planExpiredTasks.count)
                    }
                }
                
                // 今日到期
                let dueTodayTasks = todayTasks.filter { isDueToday($0) }
                if !dueTodayTasks.isEmpty {
                    Section {
                        ForEach(dueTodayTasks) { memo in
                            memoRowWithSwipe(memo: memo)
                        }
                    } header: {
                        sectionHeaderLabel(title: "今日到期", color: .orange, count: dueTodayTasks.count)
                    }
                }
                
                // 今日安排
                if !plannedTodayTasksOrdered.isEmpty {
                    Section {
                        ForEach(Array(plannedTodayTasksOrdered.enumerated()), id: \.element.id) { index, memo in
                            memoRowWithSwipe(memo: memo, orderIndex: isManualOrderingTodayPlan ? index + 1 : nil)
                        }
                        .onMove { indices, newOffset in
                            var updated = plannedTodayTasksOrdered
                            updated.move(fromOffsets: indices, toOffset: newOffset)
                            manualPlannedTodayOrder = updated.map { $0.id }
                            saveManualPlannedTodayOrder()
                        }
                    } header: {
                        HStack {
                            sectionHeaderLabel(title: "今日安排", color: .blue, count: plannedTodayTasksOrdered.count)
                            if isManualOrderingTodayPlan {
                                Text("安排順序")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !plannedTodayTasksOrdered.isEmpty {
                                Button(isManualOrderingTodayPlan ? "完成" : "安排順序") {
                                    toggleManualOrderingTodayPlan()
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
                
                // 明天安排
                if !plannedTomorrowTasks.isEmpty {
                    Section {
                        ForEach(plannedTomorrowTasks) { memo in
                            memoRowWithSwipe(memo: memo)
                                .contextMenu {
                                    Button("加入今日安排") {
                                        moveMemoToPlannedToday(memo.id, insertAt: nil, markSnoozed: false)
                                    }
                                }
                        }
                    } header: {
                        sectionHeaderLabel(title: "明天安排", color: .teal, count: plannedTomorrowTasks.count)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $todayEditMode)
    }
    
    // MARK: - 即將到期
    private var upcomingView: some View {
        List {
            if upcomingTasks.isEmpty {
                Section {
                    emptyUpcomingView
                }
                .listRowBackground(Color.clear)
            } else {
                let buckets = upcomingBuckets
                if !buckets.tomorrow.isEmpty {
                    Section {
                        ForEach(buckets.tomorrow) { memo in
                            memoRowWithSwipe(memo: memo)
                        }
                    } header: {
                        sectionHeaderLabel(title: "明天到期", color: .orange, count: buckets.tomorrow.count)
                    }
                }
                
                if !buckets.nextThreeDays.isEmpty {
                    Section {
                        ForEach(buckets.nextThreeDays) { memo in
                            memoRowWithSwipe(memo: memo)
                        }
                    } header: {
                        sectionHeaderLabel(title: "2-3 天內", color: .blue, count: buckets.nextThreeDays.count)
                    }
                }
                
                if !buckets.nextWeek.isEmpty {
                    Section {
                        ForEach(buckets.nextWeek) { memo in
                            memoRowWithSwipe(memo: memo)
                        }
                    } header: {
                        sectionHeaderLabel(title: "4-7 天內", color: .purple, count: buckets.nextWeek.count)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - 今日課程
    private var todayScheduleView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if todayCourses.isEmpty {
                    emptyScheduleView
                } else {
                    ForEach(todayCourses) { course in
                        TodayCourseCard(
                            course: course,
                            relatedMemos: memoManager.memosForCourse(course.id),
                            onAddMemo: {
                                presetCourseLink = course.id
                                showAddMemo = true
                            },
                            onMemoTap: { memo in
                                selectedMemo = memo
                            },
                            onMemoToggle: { memo in
                                memoManager.toggleCompletion(memo)
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - 所有任務
    private var allTasksView: some View {
        VStack(spacing: 0) {
            allTasksGroupPicker
            
            switch allTasksGroupMode {
            case .byCourse:
                allTasksByCourseView
            case .byPriority:
                allTasksByPriorityView
            case .byTag:
                allTasksByTagView
            }
        }
    }
    
    private var allTasksGroupPicker: some View {
        Picker("分塊方式", selection: $allTasksGroupMode) {
            ForEach(AllTasksGroupMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var allTasksByCourseView: some View {
        List {
            if allTasks.isEmpty {
                Section {
                    emptyAllTasksView
                }
                .listRowBackground(Color.clear)
            } else {
                // 無課程連結的備忘錄
                let memosWithoutCourse = allTasks.filter { $0.courseLink == nil }.sorted { sortMemos($0, $1) }
                if !memosWithoutCourse.isEmpty {
                    Section {
                        ForEach(memosWithoutCourse) { memo in
                            memoRowWithSwipe(memo: memo)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 10, height: 10)
                            Text("一般待辦")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(memosWithoutCourse.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                let knownCourseIds = Set(courseData.courses.map { $0.id })
                ForEach(courseData.courses, id: \.id) { course in
                    let memos = allTasks.filter { $0.courseLink == course.id }.sorted { sortMemos($0, $1) }
                    if !memos.isEmpty {
                        Section {
                            ForEach(memos) { memo in
                                memoRowWithSwipe(memo: memo)
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(getCourseColor(for: course.id))
                                    .frame(width: 10, height: 10)
                                Text(course.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(memos.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                let unknownCourseIds = Set(allTasks.compactMap { $0.courseLink }).subtracting(knownCourseIds)
                ForEach(Array(unknownCourseIds).sorted(), id: \.self) { courseId in
                    let memos = allTasks.filter { $0.courseLink == courseId }.sorted { sortMemos($0, $1) }
                    if !memos.isEmpty {
                        Section {
                            ForEach(memos) { memo in
                                memoRowWithSwipe(memo: memo)
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(getCourseColor(for: courseId))
                                    .frame(width: 10, height: 10)
                                Text(getCourseName(for: courseId) ?? courseId)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(memos.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var allTasksByPriorityView: some View {
        List {
            if allTasks.isEmpty {
                Section {
                    emptyAllTasksView
                }
                .listRowBackground(Color.clear)
            } else {
                let priorities = Memo.Priority.allCases.sorted { $0.sortOrder < $1.sortOrder }
                ForEach(priorities) { priority in
                    let memos = allTasks.filter { $0.priority == priority }.sorted { sortMemos($0, $1) }
                    if !memos.isEmpty {
                        Section {
                            ForEach(memos) { memo in
                                memoRowWithSwipe(memo: memo)
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(systemName: priority.icon)
                                    .foregroundColor(priority.color)
                                Text(priority.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(memos.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var allTasksByTagView: some View {
        List {
            if allTasks.isEmpty {
                Section {
                    emptyAllTasksView
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(Memo.TagType.allCases) { tag in
                    let memos = allTasks.filter { $0.tagType == tag }.sorted { sortMemos($0, $1) }
                    if !memos.isEmpty {
                        Section {
                            ForEach(memos) { memo in
                                memoRowWithSwipe(memo: memo)
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(systemName: tag.icon)
                                    .foregroundColor(tag.color)
                                Text(tag.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(memos.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 已完成清單
    private var completedTasksView: some View {
        let completedMemos = memoManager.filteredMemos.filter { $0.status == .done }
        return List {
            if completedMemos.isEmpty {
                Section {
                    emptyCompletedView
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(completedMemos) { memo in
                        memoRowWithSwipe(memo: memo)
                    }
                } header: {
                    sectionHeaderLabel(title: "已完成", color: .green, count: completedMemos.count)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - 空狀態視圖
    private var emptyTodayView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green.opacity(0.6))
            Text("太棒了！沒有待辦事項")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("點擊右上角新增任務")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var emptyUpcomingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.blue.opacity(0.6))
            Text("未來 7 天沒有待辦事項")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var emptyScheduleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double")
                .font(.system(size: 48))
                .foregroundColor(.purple.opacity(0.6))
            Text("今天沒有課程")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("好好休息吧～")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var emptyAllTasksView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            Text("沒有任務")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyCompletedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green.opacity(0.6))
            Text("尚無已完成的備忘錄")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - 帶滑動操作的備忘錄行
    private func memoRowWithSwipe(memo: Memo, orderIndex: Int? = nil) -> some View {
        let content = HStack(spacing: 12) {
            // 完成按鈕 - 使用獨立點擊區域
            Image(systemName: memo.status.icon)
                .font(.title3)
                .foregroundColor(memo.status.color)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
                .onTapGesture {
                    statusPickerMemo = memo
                }
            
            if let orderIndex = orderIndex {
                Text("\(orderIndex)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 18, alignment: .leading)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 標題行
                HStack {
                    Text(memo.title)
                        .font(.subheadline.weight(.medium))
                        .strikethrough(memo.status == .done)
                        .foregroundColor(memo.status == .done ? .gray : .primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // 優先級標籤
                    PriorityBadge(priority: memo.priority)
                }
                
                // 標籤和課程
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: memo.tagType.icon)
                        Text(memo.tagType.rawValue)
                    }
                        .font(.caption2)
                        .foregroundColor(memo.tagType.color)
                    
                    if let courseName = getCourseName(for: memo.courseLink) {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(courseName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let dueAt = memo.dueAt {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(formatTime(dueAt))
                            .font(.caption2)
                            .foregroundColor(memo.isOverdue ? .red : .secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedMemo = memo
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                memoManager.deleteMemo(memo)
            } label: {
                Label("刪除", systemImage: "trash")
            }
            
            Button {
                editingMemo = memo
            } label: {
                Label("編輯", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                memoManager.toggleCompletion(memo)
            } label: {
                if memo.status == .done {
                    Label("取消完成", systemImage: "arrow.uturn.backward")
                } else {
                    Label("完成", systemImage: "checkmark")
                }
            }
            .tint(memo.status == .done ? .orange : .green)
        }
        
        return AnyView(content)
    }
    
    // MARK: - Section Header Label
    private func sectionHeaderLabel(title: String, color: Color, count: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("(\(count))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - 資料計算
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: Date())
    }
    
    /// 逾期任務
    private var overdueTasks: [Memo] {
        memoManager.filteredMemos.filter { memo in
            memo.status != .done && memo.isOverdue
        }.sorted { sortMemos($0, $1) }
    }

    /// 計劃過期（非今天且是過去日期，且未截止）
    private var planExpiredTasks: [Memo] {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return memoManager.filteredMemos.filter { memo in
            guard memo.status != .done, let planAt = memo.planAt else { return false }
            if let dueAt = memo.dueAt, dueAt < now { return false } // 先判斷截止日過期
            return planAt < today
        }.sorted { sortMemos($0, $1) }
    }
    
    /// 今日任務（今天到期 or 今天安排）
    private var todayTasks: [Memo] {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return memoManager.filteredMemos.filter { memo in
            guard memo.status != .done && !memo.isOverdue else { return false }
            
            // 今天到期
            if let dueAt = memo.dueAt, dueAt >= today && dueAt < tomorrow {
                return true
            }
            
            // 今天安排
            if let planAt = memo.planAt, planAt >= today && planAt < tomorrow {
                return true
            }
            
            return false
        }.sorted { sortMemos($0, $1) }
    }

    /// 今日安排（排除今日到期）
    private var plannedTodayTasksBase: [Memo] {
        todayTasks.filter { isPlannedToday($0) && !isDueToday($0) }
    }
    
    private var plannedTodayTaskIds: [String] {
        plannedTodayTasksBase.map { $0.id }
    }

    /// 今日安排（可手動排序）
    private var plannedTodayTasksOrdered: [Memo] {
        let base = plannedTodayTasksBase
        guard !manualPlannedTodayOrder.isEmpty else { return base }
        let map = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        var ordered: [Memo] = manualPlannedTodayOrder.compactMap { map[$0] }
        let remaining = base.filter { manualPlannedTodayOrder.contains($0.id) == false }
        ordered.append(contentsOf: remaining)
        return ordered
    }

    /// 明天安排
    private var plannedTomorrowTasks: [Memo] {
        memoManager.filteredMemos.filter { memo in
            guard memo.status != .done && !memo.isOverdue else { return false }
            guard memo.planAt != nil else { return false }
            return isPlannedTomorrow(memo)
        }.sorted { sortMemos($0, $1) }
    }

    private var droppablePlanToTodayIds: Set<String> {
        Set(planExpiredTasks.map { $0.id }).union(plannedTomorrowTasks.map { $0.id })
    }
    
    /// 即將到期（未來 7 天）
    private var upcomingTasks: [Memo] {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let weekLater = calendar.date(byAdding: .day, value: 7, to: today)!
        
        return memoManager.filteredMemos.filter { memo in
            guard memo.status != .done, let dueAt = memo.dueAt else { return false }
            return dueAt >= tomorrow && dueAt < weekLater
        }.sorted { sortMemos($0, $1) }
    }

    private struct UpcomingBuckets {
        let tomorrow: [Memo]
        let nextThreeDays: [Memo]
        let nextWeek: [Memo]
    }
    
    private var upcomingBuckets: UpcomingBuckets {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let tomorrowTasks = upcomingTasks.filter { memo in
            guard let dueAt = memo.dueAt else { return false }
            return isSameDay(dueAt, tomorrow)
        }
        
        let nextThreeDays = upcomingTasks.filter { memo in
            guard let dueAt = memo.dueAt else { return false }
            let days = daysBetween(today, dueAt)
            return days >= 2 && days <= 3
        }
        
        let nextWeek = upcomingTasks.filter { memo in
            guard let dueAt = memo.dueAt else { return false }
            let days = daysBetween(today, dueAt)
            return days >= 4 && days <= 7
        }
        
        return UpcomingBuckets(
            tomorrow: tomorrowTasks,
            nextThreeDays: nextThreeDays,
            nextWeek: nextWeek
        )
    }
    
    /// 今日課程
    private var todayCourses: [Course] {
        let weekday = calendar.component(.weekday, from: Date())
        let dayString = weekdayToString(weekday)
        
        return courseData.courses
            .filter { $0.day == dayString }
            .sorted { $0.timeSlot.id < $1.timeSlot.id }
    }
    
    /// 所有任務（含已完成）
    private var allTasks: [Memo] {
        memoManager.filteredMemos
    }

    /// 所有進行中的備忘錄（排除已完成）
    private var activeMemos: [Memo] {
        memoManager.filteredMemos.filter { $0.status != .done }
    }
    
    // MARK: - Helper Methods
    
    private func weekdayToString(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "日"
        case 2: return "一"
        case 3: return "二"
        case 4: return "三"
        case 5: return "四"
        case 6: return "五"
        case 7: return "六"
        default: return ""
        }
    }
    
    private func isDueToday(_ memo: Memo) -> Bool {
        guard let dueAt = memo.dueAt else { return false }
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return dueAt >= today && dueAt < tomorrow
    }
    
    private func isPlannedToday(_ memo: Memo) -> Bool {
        guard let planAt = memo.planAt else { return false }
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return planAt >= today && planAt < tomorrow
    }

    private func isPlannedTomorrow(_ memo: Memo) -> Bool {
        guard let planAt = memo.planAt else { return false }
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today)!
        return planAt >= tomorrow && planAt < dayAfter
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }
    
    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }
    
    private func toggleManualOrderingTodayPlan() {
        if isManualOrderingTodayPlan {
            isManualOrderingTodayPlan = false
            todayEditMode = .inactive
        } else {
            if manualPlannedTodayOrder.isEmpty {
                manualPlannedTodayOrder = plannedTodayTasksOrdered.map { $0.id }
            }
            isManualOrderingTodayPlan = true
            todayEditMode = .active
        }
        saveManualPlannedTodayOrder()
    }
    
    private func manualOrderKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "memo.manualPlanOrder.\(formatter.string(from: date))"
    }
    
    private func loadManualPlannedTodayOrder() {
        let key = manualOrderKey(for: Date())
        if let stored = UserDefaults.standard.array(forKey: key) as? [String] {
            manualPlannedTodayOrder = stored
        } else {
            manualPlannedTodayOrder = []
        }
    }
    
    private func saveManualPlannedTodayOrder() {
        let key = manualOrderKey(for: Date())
        UserDefaults.standard.set(manualPlannedTodayOrder, forKey: key)
    }
    
    private func syncManualOrderWithCurrentTasks() {
        let currentIds = plannedTodayTaskIds
        if currentIds.isEmpty {
            if !manualPlannedTodayOrder.isEmpty {
                manualPlannedTodayOrder = []
                saveManualPlannedTodayOrder()
            }
            return
        }
        
        var newOrder = manualPlannedTodayOrder.filter { currentIds.contains($0) }
        for id in currentIds where !newOrder.contains(id) {
            newOrder.append(id)
        }
        
        if newOrder != manualPlannedTodayOrder {
            manualPlannedTodayOrder = newOrder
            saveManualPlannedTodayOrder()
        }
    }

    private func todayLateAdjusted() -> Date {
        let now = Date()
        if let late = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now) {
            return late
        }
        return now
    }
    
    private func moveMemoToPlannedToday(_ memoId: String, insertAt: Int?, markSnoozed: Bool) {
        guard droppablePlanToTodayIds.contains(memoId) else { return }
        guard let memo = memoManager.memos.first(where: { $0.id == memoId }) else { return }
        let newPlanAt = todayLateAdjusted()
        var updatedMemo = memo
        updatedMemo.planAt = newPlanAt
        if markSnoozed {
            updatedMemo.status = .snoozed
        }
        updatedMemo.updatedAt = Date()
        memoManager.updateMemo(updatedMemo)
        
        if plannedTodayTasksOrdered.contains(where: { $0.id == memoId }) == false {
            var newOrder = manualPlannedTodayOrder.filter { $0 != memoId }
            let target = insertAt ?? newOrder.count
            let index = min(max(target, 0), newOrder.count)
            newOrder.insert(memoId, at: index)
            manualPlannedTodayOrder = newOrder
            saveManualPlannedTodayOrder()
        }
    }

    private func moveOverdueToToday(_ memo: Memo) {
        let dueToday = todayLateAdjusted()
        var updatedMemo = memo
        updatedMemo.dueAt = dueToday
        updatedMemo.planAt = dueToday
        updatedMemo.status = .snoozed
        updatedMemo.updatedAt = Date()
        memoManager.updateMemo(updatedMemo)
    }

    
    private func sortMemos(_ m1: Memo, _ m2: Memo) -> Bool {
        switch memoManager.sortBy {
        case .dueDate:
            let time1 = m1.dueAt ?? Date.distantFuture
            let time2 = m2.dueAt ?? Date.distantFuture
            if time1 != time2 { return time1 < time2 }
            return m1.priority.sortOrder < m2.priority.sortOrder
        case .priority:
            if m1.priority.sortOrder != m2.priority.sortOrder {
                return m1.priority.sortOrder < m2.priority.sortOrder
            }
            let time1 = m1.dueAt ?? m1.planAt ?? m1.createdAt
            let time2 = m2.dueAt ?? m2.planAt ?? m2.createdAt
            return time1 < time2
        case .createdAt:
            if m1.createdAt != m2.createdAt { return m1.createdAt > m2.createdAt }
            return m1.priority.sortOrder < m2.priority.sortOrder
        case .updatedAt:
            if m1.updatedAt != m2.updatedAt { return m1.updatedAt > m2.updatedAt }
            return m1.priority.sortOrder < m2.priority.sortOrder
        }
    }


    private func loadScheduledMemos() {
        isLoadingScheduledMemos = true
        let currentMemos = memoManager.memos
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let memoRequests = requests.filter { $0.identifier.hasPrefix("memo_") }
            var counts: [String: Int] = [:]
            var earliest: [String: Date] = [:]
            
            for request in memoRequests {
                guard let memoId = extractMemoId(from: request) else { continue }
                counts[memoId, default: 0] += 1
                
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let next = trigger.nextTriggerDate() {
                    if let existing = earliest[memoId] {
                        if next < existing { earliest[memoId] = next }
                    } else {
                        earliest[memoId] = next
                    }
                }
            }
            
            let memoMap = Dictionary(uniqueKeysWithValues: currentMemos.map { ($0.id, $0) })
            var items: [ScheduledMemoInfo] = []
            for (id, count) in counts {
                guard let memo = memoMap[id] else { continue }
                items.append(ScheduledMemoInfo(
                    id: id,
                    memo: memo,
                    count: count,
                    nextTrigger: earliest[id]
                ))
            }
            
            items.sort { a, b in
                switch (a.nextTrigger, b.nextTrigger) {
                case let (d1?, d2?) where d1 != d2:
                    return d1 < d2
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return a.memo.priority.sortOrder < b.memo.priority.sortOrder
                }
            }
            
            DispatchQueue.main.async {
                scheduledMemos = items
                isLoadingScheduledMemos = false
            }
        }
    }
    
    private func extractMemoId(from request: UNNotificationRequest) -> String? {
        if let memoId = request.content.userInfo["memoId"] as? String {
            return memoId
        }
        let parts = request.identifier.split(separator: "_", omittingEmptySubsequences: true)
        guard parts.count >= 2, parts[0] == "memo" else { return nil }
        return String(parts[1])
    }
    
    private func getCourseName(for courseId: String?) -> String? {
        guard let courseId = courseId else { return nil }
        return courseData.courses.first { $0.id == courseId }?.name
    }
    
    private func getCourseColor(for courseId: String) -> Color {
        // 根據課程名稱生成一致的顏色
        guard let course = courseData.courses.first(where: { $0.id == courseId }) else {
            return .blue
        }
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .mint, .indigo, .teal]
        let hash = abs(course.name.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - 排程通知清單
struct ScheduledMemoInfo: Identifiable {
    let id: String
    let memo: Memo
    let count: Int
    let nextTrigger: Date?
}

struct ScheduledNotificationsSheet: View {
    let items: [ScheduledMemoInfo]
    let isLoading: Bool
    let courseNameProvider: (String?) -> String?
    let onRefresh: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("載入中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(items) { item in
                            memoRow(item)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("排程通知")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            if items.isEmpty {
                onRefresh()
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            Text("沒有排程中的通知")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    @ViewBuilder
    private func memoRow(_ item: ScheduledMemoInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.memo.title)
                    .font(.headline)
                Spacer()
                Text("\(item.count) 個提醒")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Image(systemName: item.memo.tagType.icon)
                    Text(item.memo.tagType.rawValue)
                }
                    .font(.caption)
                    .foregroundColor(item.memo.tagType.color)
                
                Text("• \(item.memo.priority.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let courseName = courseNameProvider(item.memo.courseLink) {
                    Text("• \(courseName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Text("下次提醒：\(formatDate(item.nextTrigger))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 狀態選擇 Sheet
struct StatusPickerSheet: View {
    let memo: Memo
    let onSelect: (Memo.MemoStatus) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Memo.MemoStatus.allCases) { status in
                        Button {
                            onSelect(status)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: status.icon)
                                    .foregroundColor(status.color)
                                Text(status.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if memo.status == status {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text(memo.title)
                        .lineLimit(2)
                }
            }
            .navigationTitle("更新狀態")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.35)])
    }
}

// MARK: - Filter Chip View
struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color(.tertiarySystemBackground))
                .foregroundColor(isSelected ? color : .secondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isSelected ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundColor(isSelected ? .white : .secondary)
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(isSelected ? .primary : .secondary)
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Today Memo Card
struct TodayMemoCard: View {
    let memo: Memo
    let courseName: String?
    let onToggle: () -> Void
    let onTap: () -> Void
    let onSnooze: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // 完成按鈕
                Button(action: onToggle) {
                    Image(systemName: memo.status.icon)
                        .font(.title2)
                        .foregroundColor(memo.status.color)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 6) {
                    // 標題行
                    HStack {
                        Text(memo.title)
                            .font(.subheadline.weight(.medium))
                            .strikethrough(memo.status == .done)
                            .foregroundColor(memo.status == .done ? .gray : .primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        // 優先級
                        PriorityBadge(priority: memo.priority)
                    }
                    
                    // 標籤和課程
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Image(systemName: memo.tagType.icon)
                            Text(memo.tagType.rawValue)
                        }
                            .font(.caption2)
                            .foregroundColor(memo.tagType.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(memo.tagType.color.opacity(0.1))
                            .clipShape(Capsule())
                        
                        if let courseName = courseName {
                            Text(courseName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // 時間資訊
                    HStack(spacing: 12) {
                        if let dueAt = memo.dueAt {
                            Label(formatTime(dueAt), systemImage: "calendar.badge.clock")
                                .font(.caption2)
                                .foregroundColor(memo.isOverdue ? .red : .secondary)
                        }
                        
                        if let description = memo.dueDateDescription {
                            Text(description)
                                .font(.caption2.weight(.medium))
                                .foregroundColor(memo.isOverdue ? .red : .orange)
                        }
                    }
                }
                
                // 延後按鈕
                if let onSnooze = onSnooze, memo.status != .done {
                    Button(action: onSnooze) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
                    .overlay(alignment: .leading) {
                        if memo.isOverdue {
                            Capsule()
                                .fill(Color.red)
                                .frame(width: 3)
                                .padding(.vertical, 8)
                                .padding(.leading, 4)
                        }
                    }
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Today Course Card
struct TodayCourseCard: View {
    let course: Course
    let relatedMemos: [Memo]
    let onAddMemo: () -> Void
    let onMemoTap: (Memo) -> Void
    let onMemoToggle: (Memo) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 課程資訊
            HStack(alignment: .top, spacing: 12) {
                // 時間標籤
                VStack {
                    Text(course.startTime.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(slotColor)
                        .clipShape(Capsule())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.subheadline.weight(.semibold))
                    
                    HStack(spacing: 12) {
                        Label(course.location.isEmpty ? "—" : course.location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label(course.teacher.isEmpty ? "—" : course.teacher, systemImage: "person")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 新增備忘錄按鈕
                Button(action: onAddMemo) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // 相關備忘錄
            if !relatedMemos.isEmpty {
                Divider()
                
                ForEach(relatedMemos) { memo in
                    HStack(spacing: 8) {
                        Button {
                            onMemoToggle(memo)
                        } label: {
                            Image(systemName: memo.status.icon)
                                .font(.caption)
                                .foregroundColor(memo.status.color)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            onMemoTap(memo)
                        } label: {
                            HStack {
                                Text(memo.title)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if memo.isOverdue {
                                    Text("逾期")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 4)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(slotColor)
                        .frame(width: 3)
                        .padding(.vertical, 8)
                        .padding(.leading, 4)
                }
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }
    
    private var slotColor: Color {
        switch course.timeSlot {
        case .morning1, .morning2, .morning3, .morning4:
            return .blue
        case .afternoon1, .afternoon2, .afternoon3, .afternoon4, .afternoon5:
            return .orange
        case .evening1, .evening2, .evening3, .evening4:
            return .purple
        }
    }
}

// MARK: - Course Memo Section (依課程分組的備忘錄區塊)
struct CourseMemoSection: View {
    let courseName: String
    let courseColor: Color
    let memos: [Memo]
    let onMemoTap: (Memo) -> Void
    let onMemoToggle: (Memo) -> Void
    let onAddMemo: () -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 課程標題
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // 課程顏色標記
                    Circle()
                        .fill(courseColor)
                        .frame(width: 12, height: 12)
                    
                    Text(courseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    // 待辦數量
                    let pendingCount = memos.filter { $0.status != .done }.count
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(courseColor)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // 新增按鈕
                    Button(action: onAddMemo) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    // 展開/收合圖示
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            
            // 備忘錄列表
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(memos) { memo in
                        CourseMemoRow(
                            memo: memo,
                            onTap: { onMemoTap(memo) },
                            onToggle: { onMemoToggle(memo) }
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Course Memo Row
struct CourseMemoRow: View {
    let memo: Memo
    let onTap: () -> Void
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                // 完成按鈕
                Button(action: onToggle) {
                    Image(systemName: memo.status.icon)
                        .font(.body)
                        .foregroundColor(memo.status.color)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    // 標題行
                    HStack {
                        Text(memo.title)
                            .font(.subheadline)
                            .strikethrough(memo.status == .done)
                            .foregroundColor(memo.status == .done ? .gray : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // 優先級標籤
                        PriorityBadge(priority: memo.priority, compact: true)
                    }
                    
                    // 資訊行
                    HStack(spacing: 8) {
                        // 標籤類型
                        HStack(spacing: 2) {
                            Image(systemName: memo.tagType.icon)
                            Text(memo.tagType.rawValue)
                        }
                            .font(.caption2)
                            .foregroundColor(memo.tagType.color)
                        
                        // 時間
                        if let dueAt = memo.dueAt {
                            Text(formatDate(dueAt))
                                .font(.caption2)
                                .foregroundColor(memo.isOverdue ? .red : .secondary)
                        }
                        
                        // 逾期提示
                        if memo.isOverdue {
                            Text("逾期")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
                    .overlay(alignment: .leading) {
                        if memo.isOverdue {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                        }
                    }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    TodayView(
        memoManager: MemoManager(),
        courseData: CourseData()
    )
}
