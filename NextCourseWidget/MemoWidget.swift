//
//  MemoWidget.swift
//  NextCourseWidget
//
//  Created by AI Assistant on 2026/2/11.
//

import WidgetKit
import SwiftUI
import CoreData

// MARK: - Timeline Entry
struct MemoWidgetEntry: TimelineEntry {
    let date: Date
    let memos: [MemoEntity]
}

// MARK: - Timeline Provider
struct MemoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoWidgetEntry {
        MemoWidgetEntry(date: Date(), memos: [])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MemoWidgetEntry) -> ()) {
        let entry = MemoWidgetEntry(date: Date(), memos: fetchMemos())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoWidgetEntry>) -> ()) {
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? Date()
        let entry = MemoWidgetEntry(date: currentDate, memos: fetchMemos())
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchMemos() -> [MemoEntity] {
        let container = NSPersistentCloudKitContainer(name: "CourseModel")
        let appGroupIdentifier = "group.NTPUOne.NextCourseWidget"
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("shared.sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL!)
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Error loading persistent store: \(error)")
            }
        }
        
        let context = container.viewContext
        let request: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
        
        // 只獲取未完成的備忘錄
        request.predicate = NSPredicate(format: "status != %@", "已完成")
        
        // 使用與app相同的排序邏輯：截止日期優先，然後優先級
        request.sortDescriptors = [
            NSSortDescriptor(key: "dueAt", ascending: true),
            NSSortDescriptor(key: "priority", ascending: false)
        ]
        
        do {
            var result = try context.fetch(request)
            
            // 後處理排序：將沒有截止日期的任務移到最後，並保持優先級排序
            result.sort { memo1, memo2 in
                // 已完成的排最後（雖然predicate已經過濾，但保險起見）
                if memo1.status == "已完成" && memo2.status != "已完成" { return false }
                if memo1.status != "已完成" && memo2.status == "已完成" { return true }
                
                let due1 = memo1.dueAt ?? Date.distantFuture
                let due2 = memo2.dueAt ?? Date.distantFuture
                
                if due1 != due2 { return due1 < due2 }
                
                // 優先級排序：高 > 中 > 低
                let priority1 = memo1.priority ?? "中"
                let priority2 = memo2.priority ?? "中"
                let priorityOrder = ["高": 0, "中": 1, "低": 2]
                return (priorityOrder[priority1] ?? 1) < (priorityOrder[priority2] ?? 1)
            }
            
            print("Fetched \(result.count) memos from Core Data.")
            return result
        } catch {
            print("Error fetching memos: \(error)")
            return []
        }
    }
    
    // 獲取課程名稱的輔助函數
    static func getCourseName(for courseId: String?) -> String? {
        guard let courseId = courseId, !courseId.isEmpty else { return nil }
        
        let container = NSPersistentCloudKitContainer(name: "CourseModel")
        let appGroupIdentifier = "group.NTPUOne.NextCourseWidget"
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("shared.sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL!)
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Error loading persistent store: \(error)")
            }
        }
        
        let context = container.viewContext
        let request: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", courseId)
        request.fetchLimit = 1
        
        do {
            let result = try context.fetch(request)
            return result.first?.name
        } catch {
            print("Error fetching course: \(error)")
            return nil
        }
    }
}

// MARK: - Small Widget View
struct MemoSmallWidgetView: View {
    let entry: MemoWidgetProvider.Entry
    
    // 所有今日任務（用於計算總數）
    var allTodayMemos: [MemoEntity] {
        let calendar = Calendar.current
        return entry.memos.filter { memo in
            // 檢查截止日期是否為今天
            if let dueAt = memo.dueAt, calendar.isDateInToday(dueAt) {
                return true
            }
            // 檢查計劃日期是否為今天
            if let planAt = memo.planAt, calendar.isDateInToday(planAt) {
                return true
            }
            return false
        }
    }
    
    // 要顯示的今日任務（最多4個）
    var todayMemos: [MemoEntity] {
        // 應用手動排序
        return applyManualOrder(to: allTodayMemos).prefix(4).map { $0 }
    }
    
    // 逾期任務數量
    var overdueCount: Int {
        let now = Date()
        return entry.memos.filter { memo in
            guard let dueAt = memo.dueAt else { return false }
            return dueAt < now
        }.count
    }
    
    // 計劃過期任務數量
    var planOverdueCount: Int {
        let calendar = Calendar.current
        let now = Date()
        return entry.memos.filter { memo in
            guard memo.dueAt == nil else { return false }  // 沒有截止日期才檢查計劃
            guard let planAt = memo.planAt else { return false }
            return planAt < now && !calendar.isDateInToday(planAt)
        }.count
    }
    
    // 從UserDefaults讀取手動排序
    private func applyManualOrder(to memos: [MemoEntity]) -> [MemoEntity] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "memo.manualPlanOrder.\(formatter.string(from: Date()))"
        
        guard let manualOrder = UserDefaults.standard.array(forKey: key) as? [String],
              !manualOrder.isEmpty else {
            return memos
        }
        
        // 建立id到memo的映射
        let memoMap = Dictionary(uniqueKeysWithValues: memos.map { ($0.id ?? "", $0) })
        
        // 按手動順序排列
        var ordered: [MemoEntity] = manualOrder.compactMap { memoMap[$0] }
        
        // 加入不在手動順序中的任務
        let remaining = memos.filter { memo in
            guard let id = memo.id else { return true }
            return !manualOrder.contains(id)
        }
        ordered.append(contentsOf: remaining)
        
        return ordered
    }
    
    var body: some View {
        VStack(spacing: 5) {
            // 標題
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                Text("今日")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                
                // 逾期指示點
                if overdueCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(overdueCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(Color.red)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.trailing, 4)
                }
                
                // 計劃過期指示點
                if planOverdueCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(planOverdueCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.trailing, 4)
                }
                
                Text("\(allTodayMemos.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue))
            }
            
            // 任務列表
            if todayMemos.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    Text("今天沒有任務")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                VStack(spacing: 4) {
                    ForEach(todayMemos, id: \.id) { memo in
                        HStack(spacing: 5) {
                            // 標籤圖標
                            Image(systemName: tagIcon(memo.tagType ?? "其他"))
                                .font(.system(size: 10))
                                .foregroundColor(tagColor(memo.tagType ?? "其他"))
                                .frame(width: 14)
                            
                            // 任務標題
                            Text(memo.title ?? "無標題")
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                            
                            Spacer(minLength: 0)
                            
                            // 優先級標記
                            Circle()
                                .fill(priorityColor(memo.priority ?? "中"))
                                .frame(width: 4, height: 4)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(tagColor(memo.tagType ?? "其他").opacity(0.08))
                        )
                    }
                    
                    // 省略標記
                    if allTodayMemos.count > 4 {
                        Text("+\(allTodayMemos.count - 4)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 1)
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
    }
}

// MARK: - Medium Widget View
struct MemoMediumWidgetView: View {
    let entry: MemoWidgetProvider.Entry
    
    var priorityMemos: [MemoEntity] {
        let calendar = Calendar.current
        let now = Date()
        
        // 分類：需處理的（逾期+計劃過期）、即將到期（今天+明天+本週）、其他
        var needHandle: [MemoEntity] = []  // 需處理的：逾期 + 計劃過期
        var upcoming: [MemoEntity] = []    // 即將到期：今天 + 明天 + 本週
        var others: [MemoEntity] = []
        
        for memo in entry.memos {
            // 先檢查計劃是否過期
            var isPlanOverdue = false
            if let planAt = memo.planAt, planAt < now, !calendar.isDateInToday(planAt) {
                isPlanOverdue = true
            }
            
            if let dueAt = memo.dueAt {
                if dueAt < now {
                    // 逾期 - 需處理
                    needHandle.append(memo)
                } else if calendar.isDateInToday(dueAt) {
                    // 今天 - 即將到期
                    upcoming.append(memo)
                } else if calendar.isDateInTomorrow(dueAt) {
                    // 明天 - 即將到期
                    upcoming.append(memo)
                } else {
                    let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now) ?? now
                    if dueAt <= weekFromNow {
                        // 本週 - 即將到期
                        upcoming.append(memo)
                    } else {
                        // 其他
                        others.append(memo)
                    }
                }
            } else if isPlanOverdue {
                // 計劃過期 - 需處理
                needHandle.append(memo)
            } else if let planAt = memo.planAt {
                if calendar.isDateInToday(planAt) {
                    // 今天 - 即將到期
                    upcoming.append(memo)
                } else if calendar.isDateInTomorrow(planAt) {
                    // 明天 - 即將到期
                    upcoming.append(memo)
                } else {
                    // 其他
                    others.append(memo)
                }
            } else {
                others.append(memo)
            }
        }
        
        // 按優先級合併：需處理的 > 即將到期 > 其他
        var result: [MemoEntity] = []
        result.append(contentsOf: needHandle)
        result.append(contentsOf: upcoming)
        result.append(contentsOf: others)
        
        return result
    }
    
    var displayedMemos: [MemoEntity] {
        return Array(priorityMemos.prefix(6))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 標題列
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                Text("我的任務")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\(entry.memos.count) 個待辦")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            Divider()
            
            // 任務列表 - 改為兩列布局
            if displayedMemos.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    Text("太棒了！沒有待辦任務")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 6) {
                        // 左列
                        VStack(spacing: 0) {
                            ForEach(Array(displayedMemos.prefix(3).enumerated()), id: \.element.id) { index, memo in
                                MemoCompactRowView(memo: memo)
                                if index < min(2, displayedMemos.count - 1) {
                                    Divider().padding(.leading, 8)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 分隔線
                        if displayedMemos.count > 3 {
                            Divider()
                        }
                        
                        // 右列
                        if displayedMemos.count > 3 {
                            VStack(spacing: 0) {
                                ForEach(Array(displayedMemos.dropFirst(3).prefix(3).enumerated()), id: \.element.id) { index, memo in
                                    MemoCompactRowView(memo: memo)
                                    if index < min(2, displayedMemos.count - 4) {
                                        Divider().padding(.leading, 8)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    
                    // 省略標記
                    if priorityMemos.count > 6 {
                        Text("+\(priorityMemos.count - 6)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 4)
    }
    
    func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
    
    func shortDueText(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInTomorrow(date) {
            return "明天"
        } else if date < now {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            return "逾期\(days)天"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
            return "\(days)天"
        }
    }
}

// MARK: - Large Widget View
struct MemoLargeWidgetView: View {
    let entry: MemoWidgetProvider.Entry
    
    // 高度常數
    let headerHeight: CGFloat = 48  // 標題列 + Divider
    let sectionHeaderHeight: CGFloat = 36  // 分類標題高度
    let memoRowHeight: CGFloat = 46  // 每個任務行高度（包含課程標籤）
    let dividerHeight: CGFloat = 1  // 分隔線高度
    let bottomPadding: CGFloat = 6
    
    var categorizedMemos: (overdue: [MemoEntity], planOverdue: [MemoEntity], today: [MemoEntity], thisWeek: [MemoEntity], others: [MemoEntity]) {
        let calendar = Calendar.current
        let now = Date()
        
        var overdue: [MemoEntity] = []
        var planOverdue: [MemoEntity] = []
        var today: [MemoEntity] = []
        var thisWeek: [MemoEntity] = []
        var others: [MemoEntity] = []
        
        for memo in entry.memos {
            // 先檢查計劃是否過期
            var isPlanOverdue = false
            if let planAt = memo.planAt, planAt < now, !calendar.isDateInToday(planAt) {
                isPlanOverdue = true
            }
            
            if let dueAt = memo.dueAt {
                if dueAt < now {
                    overdue.append(memo)
                } else if calendar.isDateInToday(dueAt) {
                    today.append(memo)
                } else {
                    let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now) ?? now
                    if dueAt <= weekFromNow {
                        thisWeek.append(memo)
                    } else {
                        others.append(memo)
                    }
                }
            } else if isPlanOverdue {
                planOverdue.append(memo)
            } else if let planAt = memo.planAt, calendar.isDateInToday(planAt) {
                today.append(memo)
            } else {
                others.append(memo)
            }
        }
        
        // 對今天的任務應用手動排序
        today = applyManualOrder(to: today)
        
        return (overdue, planOverdue, today, thisWeek, others)
    }
    
    // 從UserDefaults讀取手動排序
    private func applyManualOrder(to memos: [MemoEntity]) -> [MemoEntity] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "memo.manualPlanOrder.\(formatter.string(from: Date()))"
        
        guard let manualOrder = UserDefaults.standard.array(forKey: key) as? [String],
              !manualOrder.isEmpty else {
            return memos
        }
        
        // 建立 id 到 memo 的映射
        let memoMap = Dictionary(uniqueKeysWithValues: memos.map { ($0.id ?? "", $0) })
        
        // 按手動順序排列
        var ordered: [MemoEntity] = manualOrder.compactMap { memoMap[$0] }
        
        // 加入不在手動順序中的任務
        let remaining = memos.filter { memo in
            guard let id = memo.id else { return true }
            return !manualOrder.contains(id)
        }
        ordered.append(contentsOf: remaining)
        
        return ordered
    }
    
    func calculateDisplayMemos(availableHeight: CGFloat) -> [(section: String, memos: [MemoEntity], totalCount: Int, color: Color)] {
        let (overdue, planOverdue, today, thisWeek, others) = categorizedMemos
        var result: [(String, [MemoEntity], Int, Color)] = []
        var usedHeight: CGFloat = headerHeight + bottomPadding
        
        // 輔助函數：計算添加一個section需要的高度
        func heightForSection(itemCount: Int) -> CGFloat {
            return sectionHeaderHeight + CGFloat(itemCount) * memoRowHeight + CGFloat(max(0, itemCount - 1)) * dividerHeight
        }
        
        // 輔助函數：嘗試添加section（不限制最大數量）
        func tryAddSection(name: String, memos: [MemoEntity], color: Color) {
            guard !memos.isEmpty else { return }
            
            var itemsToAdd = 0
            for i in 1...memos.count {
                let sectionHeight = heightForSection(itemCount: i)
                if usedHeight + sectionHeight <= availableHeight {
                    itemsToAdd = i
                } else {
                    break
                }
            }
            
            if itemsToAdd > 0 {
                result.append((name, Array(memos.prefix(itemsToAdd)), memos.count, color))
                usedHeight += heightForSection(itemCount: itemsToAdd)
            }
        }
        
        // 按優先級添加：逾期 > 計劃過期 > 今天 > 本週 > 其他
        tryAddSection(name: "逾期", memos: overdue, color: .red)
        tryAddSection(name: "計劃過期", memos: planOverdue, color: .orange)
        tryAddSection(name: "今天", memos: today, color: .blue)
        tryAddSection(name: "本週", memos: thisWeek, color: .green)
        tryAddSection(name: "其他任務", memos: others, color: .gray)
        
        return result
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 標題列
                HStack {
                    Image(systemName: "checklist")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("任務總覽")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    
                    // 統計資訊
                    HStack(spacing: 12) {
                        let (overdue, planOverdue, _, _, _) = categorizedMemos
                        if !overdue.isEmpty {
                            Label("\(overdue.count)", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.red)
                        }
                        if !planOverdue.isEmpty {
                            Label("\(planOverdue.count)", systemImage: "calendar.badge.exclamationmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        Label("\(entry.memos.count) 個待辦", systemImage: "circle")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
                
                Divider()
                
                let displayMemos = calculateDisplayMemos(availableHeight: geometry.size.height)
                
                if displayMemos.isEmpty {
                    // 空狀態
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("太棒了！")
                            .font(.system(size: 16, weight: .bold))
                        Text("沒有待辦任務")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(displayMemos.indices, id: \.self) { sectionIndex in
                            let section = displayMemos[sectionIndex]
                            
                            SectionHeaderView(title: section.section, count: section.totalCount, color: section.color)
                            
                            ForEach(section.memos.indices, id: \.self) { index in
                                MemoRowView(memo: section.memos[index])
                                if index < section.memos.count - 1 {
                                    Divider().padding(.leading, 50)
                                }
                            }
                        }
                        
                        // 省略標記
                        let totalDisplayed = displayMemos.reduce(0) { $0 + $1.memos.count }
                        if entry.memos.count > totalDisplayed {
                            HStack {
                                Spacer()
                                Text("還有 \(entry.memos.count - totalDisplayed) 個任務未顯示...")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 10)
        }
    }
}

// MARK: - 輔助 Views
struct SectionHeaderView: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(color))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
    }
}

struct MemoRowView: View {
    let memo: MemoEntity
    
    var courseName: String? {
        MemoWidgetProvider.getCourseName(for: memo.courseLink)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // 優先級標記
            Circle()
                .fill(priorityColor(memo.priority ?? "中"))
                .frame(width: 6, height: 6)
            
            // 標籤圖標
            Image(systemName: tagIcon(memo.tagType ?? "其他"))
                .font(.system(size: 13))
                .foregroundColor(tagColor(memo.tagType ?? "其他"))
                .frame(width: 24)
            
            // 任務內容
            VStack(alignment: .leading, spacing: 2) {
                Text(memo.title ?? "無標題")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                // 顯示課程
                if let courseName = courseName {
                    Text(courseName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                }
            }
            
            Spacer()
            
            // 截止時間
            if let dueAt = memo.dueAt {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDate(dueAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isOverdue(dueAt) ? .red : .secondary)
                    
                    if isOverdue(dueAt) {
                        Text("已逾期")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
    
    func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: date)
        } else if calendar.isDateInTomorrow(date) {
            return "明天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}

// Medium Widget 專用的精簡行視圖
struct MemoCompactRowView: View {
    let memo: MemoEntity
    
    var courseName: String? {
        MemoWidgetProvider.getCourseName(for: memo.courseLink)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                // 優先級標記
                Circle()
                    .fill(priorityColor(memo.priority ?? "中"))
                    .frame(width: 4, height: 4)
                
                // 標籤圖標
                Image(systemName: tagIcon(memo.tagType ?? "其他"))
                    .font(.system(size: 10))
                    .foregroundColor(tagColor(memo.tagType ?? "其他"))
                    .frame(width: 14)
                
                // 任務標題
                Text(memo.title ?? "無標題")
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                // 截止時間或計劃過期
                if let dueAt = memo.dueAt {
                    Text(shortDueText(dueAt))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(isOverdue(dueAt) ? .red : .orange)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill((isOverdue(dueAt) ? Color.red : Color.orange).opacity(0.15))
                        )
                } else if let planAt = memo.planAt, isPlanOverdue(planAt) {
                    Text("過期\(planOverdueDays(planAt))天")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                }
            }
            
            // 課程標籤
            if let courseName = courseName {
                Text(courseName)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                    .padding(.leading, 23)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(height: 38)  // 固定高度
    }
    
    func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
    
    func isPlanOverdue(_ planAt: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        return planAt < now && !calendar.isDateInToday(planAt)
    }
    
    func planOverdueDays(_ planAt: Date) -> Int {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateComponents([.day], from: planAt, to: now).day ?? 0
    }
    
    func shortDueText(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInTomorrow(date) {
            return "明天"
        } else if date < now {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            return "過期\(days)天"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
            return "\(days)天"
        }
    }
}

// MARK: - 輔助函數
func tagIcon(_ tagType: String) -> String {
    switch tagType {
    case "活動": return "party.popper"
    case "作業": return "doc.text"
    case "考試": return "pencil.and.list.clipboard"
    case "會議": return "person.3"
    case "提醒": return "bell"
    default: return "tag"
    }
}

func tagColor(_ tagType: String) -> Color {
    switch tagType {
    case "活動": return .orange
    case "作業": return .blue
    case "考試": return .red
    case "會議": return .purple
    case "提醒": return .yellow
    default: return .gray
    }
}

func priorityColor(_ priority: String) -> Color {
    switch priority {
    case "高": return .red
    case "中": return .orange
    default: return .gray
    }
}

// MARK: - Widget Configuration
struct MemoWidget: Widget {
    let kind: String = "MemoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                MemoWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MemoWidgetEntryView(entry: entry)
                    .background(Color(.systemBackground))
            }
        }
        .configurationDisplayName("任務清單")
        .description("顯示待辦任務和提醒事項")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct MemoWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: MemoWidgetProvider.Entry
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            MemoSmallWidgetView(entry: entry)
        case .systemMedium:
            MemoMediumWidgetView(entry: entry)
        case .systemLarge:
            MemoLargeWidgetView(entry: entry)
        default:
            MemoMediumWidgetView(entry: entry)
        }
    }
}
