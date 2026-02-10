//
//  MemoManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//

import Foundation
import CoreData
import UserNotifications
import SwiftUI

class MemoManager: ObservableObject {
    @Published var memos: [Memo] = []
    @Published var filteredMemos: [Memo] = []
    
    // 篩選條件
    @Published var filterStatus: Memo.MemoStatus? = nil
    @Published var filterTagType: Memo.TagType? = nil
    @Published var filterCourseLink: String? = nil
    @Published var filterIncompleteOnly: Bool = true
    @Published var showOverdueOnly: Bool = false
    @Published var sortBy: SortOption = .dueDate
    
    var viewContext: NSManagedObjectContext?
    
    enum SortOption: String, CaseIterable {
        case dueDate = "截止時間"
        case priority = "優先級"
        case createdAt = "建立時間"
        case updatedAt = "更新時間"
    }
    
    init(context: NSManagedObjectContext? = nil) {
        self.viewContext = context
        loadMemosFromCoreData()
        requestNotificationPermissionAndSchedule()
    }
    
    // MARK: - 通知權限請求
    
    func requestNotificationPermissionAndSchedule() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            print("📱 Notification Settings:")
            print("  - Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("  - Alert Setting: \(settings.alertSetting.rawValue)")
            print("  - Sound Setting: \(settings.soundSetting.rawValue)")
            print("  - Badge Setting: \(settings.badgeSetting.rawValue)")
            
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                print("✅ Notifications already authorized")
                DispatchQueue.main.async {
                    self?.scheduleNotificationsForAllMemos()
                }
            case .notDetermined:
                print("⏳ Requesting notification permission...")
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if granted {
                        print("✅ Notification permission granted")
                        DispatchQueue.main.async {
                            self?.scheduleNotificationsForAllMemos()
                        }
                    } else if let error = error {
                        print("❌ Notification permission error: \(error.localizedDescription)")
                    } else {
                        print("❌ Notification permission denied")
                    }
                }
            case .denied:
                print("❌ Notifications denied - user needs to enable in Settings")
            case .ephemeral:
                print("⚠️ Ephemeral notifications")
            @unknown default:
                print("❓ Unknown notification status")
            }
        }
    }
    
    // MARK: - Core Data 操作
    
    func loadMemosFromCoreData() {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot load memos from Core Data.")
            return
        }
        
        let fetchRequest: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
        
        do {
            let memoEntities = try viewContext.fetch(fetchRequest)
            print("Success: Fetched \(memoEntities.count) memos from Core Data.")
            self.memos = memoEntities.compactMap { entity in
                convertToMemo(from: entity)
            }
            
            // 清理過期的提醒規則
            cleanupExpiredReminders()
            
            applyFiltersAndSort()
        } catch {
            print("Error: Failed to fetch memos from Core Data - \(error.localizedDescription)")
        }
    }
    
    /// 清理過期的非重複提醒規則
    func cleanupExpiredReminders() {
        guard let viewContext = viewContext else { return }
        
        let now = Date()
        var hasChanges = false
        
        for i in memos.indices {
            let originalCount = memos[i].reminderRules.count
            memos[i].reminderRules = memos[i].reminderRules.filter { rule in
                // 保留重複的提醒，或者尚未過期的提醒
                rule.repeatType != .none || rule.triggerAt > now
            }
            
            if memos[i].reminderRules.count != originalCount {
                hasChanges = true
                
                // 直接更新 Core Data entity
                let fetchRequest: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", memos[i].id)
                
                if let entity = try? viewContext.fetch(fetchRequest).first {
                    // 編碼更新後的提醒規則
                    entity.reminderRulesData = try? JSONEncoder().encode(memos[i].reminderRules)
                }
            }
        }
        
        if hasChanges {
            try? viewContext.save()
            print("🧹 Cleaned up expired reminder rules")
        }
    }
    
    private func convertToMemo(from entity: MemoEntity) -> Memo? {
        guard let id = entity.id,
              let title = entity.title else {
            return nil
        }
        
        // 解碼提醒規則
        var reminderRules: [ReminderRule] = []
        if let data = entity.reminderRulesData {
            do {
                reminderRules = try JSONDecoder().decode([ReminderRule].self, from: data)
            } catch {
                print("Error decoding reminder rules: \(error)")
            }
        }
        
        return Memo(
            id: id,
            title: title,
            content: entity.content ?? "",
            tagType: Memo.TagType(rawValue: entity.tagType ?? "") ?? .other,
            courseLink: entity.courseLink,
            status: Memo.MemoStatus(rawValue: entity.status ?? "") ?? .todo,
            priority: Memo.Priority(rawValue: entity.priority ?? "") ?? .medium,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            dueAt: entity.dueAt,
            planAt: entity.planAt,
            doneAt: entity.doneAt,
            reminderRules: reminderRules
        )
    }
    
    func addMemo(_ memo: Memo) {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot add memo.")
            return
        }
        
        let newEntity = MemoEntity(context: viewContext)
        updateEntity(newEntity, with: memo)
        
        do {
            try viewContext.save()
            memos.append(memo)
            applyFiltersAndSort()
            scheduleNotification(for: memo)
            print("Success: Added memo '\(memo.title)'")
        } catch {
            print("Error: Failed to save memo - \(error.localizedDescription)")
        }
    }
    
    func updateMemo(_ memo: Memo) {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot update memo.")
            return
        }
        
        let fetchRequest: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", memo.id)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let entity = results.first {
                updateEntity(entity, with: memo)
                try viewContext.save()
                
                if let index = memos.firstIndex(where: { $0.id == memo.id }) {
                    memos[index] = memo
                }
                applyFiltersAndSort()
                scheduleNotification(for: memo)
                print("Success: Updated memo '\(memo.title)'")
            }
        } catch {
            print("Error: Failed to update memo - \(error.localizedDescription)")
        }
    }
    
    func deleteMemo(_ memo: Memo) {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot delete memo.")
            return
        }
        
        let fetchRequest: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", memo.id)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let entity = results.first {
                viewContext.delete(entity)
                try viewContext.save()
                
                memos.removeAll { $0.id == memo.id }
                applyFiltersAndSort()
                cancelNotification(for: memo)
                print("Success: Deleted memo '\(memo.title)'")
            }
        } catch {
            print("Error: Failed to delete memo - \(error.localizedDescription)")
        }
    }
    
    private func updateEntity(_ entity: MemoEntity, with memo: Memo) {
        entity.id = memo.id
        entity.title = memo.title
        entity.content = memo.content
        entity.tagType = memo.tagType.rawValue
        entity.courseLink = memo.courseLink
        entity.status = memo.status.rawValue
        entity.priority = memo.priority.rawValue
        entity.createdAt = memo.createdAt
        entity.updatedAt = memo.updatedAt
        entity.dueAt = memo.dueAt
        entity.planAt = memo.planAt
        entity.doneAt = memo.doneAt
        
        // 編碼提醒規則
        do {
            entity.reminderRulesData = try JSONEncoder().encode(memo.reminderRules)
        } catch {
            print("Error encoding reminder rules: \(error)")
        }
    }
    
    // MARK: - 狀態操作
    
    /// 標記為完成
    func markAsCompleted(_ memo: Memo) {
        var updatedMemo = memo
        updatedMemo.status = .done
        updatedMemo.doneAt = Date()
        updatedMemo.updatedAt = Date()
        updateMemo(updatedMemo)
    }
    
    /// 取消完成
    func markAsIncomplete(_ memo: Memo) {
        var updatedMemo = memo
        updatedMemo.status = .todo
        updatedMemo.doneAt = nil
        updatedMemo.updatedAt = Date()
        updateMemo(updatedMemo)
    }
    
    /// 切換完成狀態
    func toggleCompletion(_ memo: Memo) {
        if memo.status == .done {
            markAsIncomplete(memo)
        } else {
            markAsCompleted(memo)
        }
    }
    
    /// 更新狀態
    func updateStatus(_ memo: Memo, to status: Memo.MemoStatus) {
        var updatedMemo = memo
        updatedMemo.status = status
        updatedMemo.updatedAt = Date()
        if status == .done {
            updatedMemo.doneAt = Date()
        } else {
            updatedMemo.doneAt = nil
        }
        updateMemo(updatedMemo)
    }

    /// 更新計劃時間
    func updatePlanAt(_ memo: Memo, to date: Date) {
        var updatedMemo = memo
        updatedMemo.planAt = date
        updatedMemo.updatedAt = Date()
        updateMemo(updatedMemo)
    }
    
    /// 延後備忘錄
    func snoozeMemo(_ memo: Memo, until date: Date) {
        var updatedMemo = memo
        updatedMemo.status = .snoozed
        updatedMemo.planAt = date
        updatedMemo.updatedAt = Date()
        updateMemo(updatedMemo)
    }
    
    // MARK: - 篩選與排序
    
    func applyFiltersAndSort() {
        var result = memos
        
        // 狀態篩選
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        } else if filterIncompleteOnly {
            result = result.filter { $0.status != .done }
        }
        
        // 標籤篩選
        if let tagType = filterTagType {
            result = result.filter { $0.tagType == tagType }
        }
        
        // 課程篩選
        if let courseLink = filterCourseLink {
            result = result.filter { $0.courseLink == courseLink }
        }
        
        // 只顯示逾期
        if showOverdueOnly {
            result = result.filter { $0.isOverdue }
        }
        
        // 排序
        switch sortBy {
        case .dueDate:
            result.sort { memo1, memo2 in
                // 未完成的排前面
                if memo1.status == .done && memo2.status != .done { return false }
                if memo1.status != .done && memo2.status == .done { return true }

                let due1 = memo1.dueAt ?? Date.distantFuture
                let due2 = memo2.dueAt ?? Date.distantFuture
                if due1 != due2 { return due1 < due2 }
                return memo1.priority.sortOrder < memo2.priority.sortOrder
            }
        case .priority:
            result.sort { $0.priority.sortOrder < $1.priority.sortOrder }
        case .createdAt:
            result.sort { $0.createdAt > $1.createdAt }
        case .updatedAt:
            result.sort { $0.updatedAt > $1.updatedAt }
        }
        
        filteredMemos = result
    }
    
    /// 取得特定課程的備忘錄
    func memosForCourse(_ courseId: String) -> [Memo] {
        return memos.filter { $0.courseLink == courseId && $0.status != .done }
    }
    
    /// 取得今日待辦
    func todayMemos() -> [Memo] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return memos.filter { memo in
            guard memo.status != .done else { return false }
            
            // 計劃今天做的
            if let planAt = memo.planAt,
               planAt >= today && planAt < tomorrow {
                return true
            }
            
            // 今天到期的
            if let dueAt = memo.dueAt,
               dueAt >= today && dueAt < tomorrow {
                return true
            }
            
            // 已逾期的
            if memo.isOverdue {
                return true
            }
            
            return false
        }.sorted { memo1, memo2 in
            // 逾期的排最前
            if memo1.isOverdue && !memo2.isOverdue { return true }
            if !memo1.isOverdue && memo2.isOverdue { return false }
            
            // 按優先級排序
            return memo1.priority.sortOrder < memo2.priority.sortOrder
        }
    }
    
    /// 統計資料
    func statistics() -> (total: Int, completed: Int, overdue: Int, todayDue: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let total = memos.count
        let completed = memos.filter { $0.status == .done }.count
        let overdue = memos.filter { $0.isOverdue }.count
        let todayDue = memos.filter { memo in
            guard let dueAt = memo.dueAt, memo.status != .done else { return false }
            return dueAt >= today && dueAt < tomorrow
        }.count
        
        return (total, completed, overdue, todayDue)
    }
    
    // MARK: - 通知
    
    func scheduleNotificationsForAllMemos() {
        // 移除所有 Memo 相關的通知
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let memoNotificationIds = requests
                .filter { $0.identifier.hasPrefix("memo_") }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: memoNotificationIds)
        }
        
        // 重新排程
        for memo in memos where memo.status != .done {
            scheduleNotification(for: memo)
        }
    }
    
    func scheduleNotification(for memo: Memo) {
        guard memo.status != .done else { return }
        
        // 先取消舊的通知
        cancelNotification(for: memo)
        
        // 1. 使用者自訂的提醒規則
        for rule in memo.reminderRules where rule.enabled {
            // 非重複通知需要檢查時間是否已過
            if rule.repeatType == .none && rule.triggerAt <= Date() {
                print("⏭️ Skipping expired reminder for '\(memo.title)'")
                continue
            }
            scheduleNotificationRequest(
                identifier: "memo_\(memo.id)_\(rule.id)",
                memo: memo,
                triggerDate: rule.triggerAt,
                repeatType: rule.repeatType
            )
        }
        
        // 2. 自動在截止時間前 30 分鐘提醒（如果有設定截止時間）
        if let dueAt = memo.dueAt {
            let thirtyMinsBefore = dueAt.addingTimeInterval(-30 * 60)
            if thirtyMinsBefore > Date() {
                scheduleNotificationRequest(
                    identifier: "memo_\(memo.id)_auto_due",
                    memo: memo,
                    triggerDate: thirtyMinsBefore,
                    bodyOverride: "距離截止時間還有 30 分鐘"
                )
            }
        }
        
        // 3. 自動在計劃時間提醒（如果有設定計劃時間）
        if let planAt = memo.planAt, planAt > Date() {
            scheduleNotificationRequest(
                identifier: "memo_\(memo.id)_auto_plan",
                memo: memo,
                triggerDate: planAt,
                bodyOverride: "計劃時間到了，該開始處理了"
            )
        }
    }

    private func formatNotificationDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func memoNotificationDetail(for memo: Memo) -> String {
        var parts: [String] = []
        if let dueAt = memo.dueAt {
            parts.append("截止 \(formatNotificationDate(dueAt))")
        }
        if let planAt = memo.planAt {
            parts.append("計劃 \(formatNotificationDate(planAt))")
        }
        return parts.joined(separator: " · ")
    }

    private func buildMemoNotificationBody(for memo: Memo, bodyOverride: String?) -> String {
        let detail = memoNotificationDetail(for: memo)
        let base: String?
        if let bodyOverride = bodyOverride {
            base = bodyOverride
        } else if !memo.content.isEmpty {
            base = memo.content
        } else {
            base = nil
        }

        switch (base, detail.isEmpty) {
        case let (base?, false):
            return "\(base)\n\(detail)"
        case let (base?, true):
            return base
        case (nil, false):
            return detail
        case (nil, true):
            return "點擊查看詳情"
        }
    }
    
    private func scheduleNotificationRequest(
        identifier: String,
        memo: Memo,
        triggerDate: Date,
        bodyOverride: String? = nil,
        repeatType: ReminderRule.RepeatType = .none
    ) {
        let content = UNMutableNotificationContent()
        content.title = "📝 \(memo.title)"
        content.subtitle = "標籤：\(memo.tagType.rawValue) · 優先：\(memo.priority.displayName)"
        content.body = buildMemoNotificationBody(for: memo, bodyOverride: bodyOverride)
        content.sound = .default
        content.userInfo = ["memoId": memo.id]
        
        let trigger: UNNotificationTrigger
        
        switch repeatType {
        case .none:
            // 一次性通知
            let triggerComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            
        case .daily:
            // 每天重複
            let triggerComponents = Calendar.current.dateComponents(
                [.hour, .minute],
                from: triggerDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
            
        case .weekly:
            // 每週重複（同一星期幾）
            let triggerComponents = Calendar.current.dateComponents(
                [.weekday, .hour, .minute],
                from: triggerDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
            
        case .monthly:
            // 每月重複（同一天）
            let triggerComponents = Calendar.current.dateComponents(
                [.day, .hour, .minute],
                from: triggerDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        }
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = TimeZone.current
                let localTime = formatter.string(from: triggerDate)
                
                if triggerDate <= Date() {
                    print("⚠️ Notification for '\(memo.title)' scheduled at \(localTime) (已過期，不會觸發)")
                } else {
                    print("✅ Notification scheduled for '\(memo.title)' at \(localTime)")
                }
            }
        }
    }
    
    func cancelNotification(for memo: Memo) {
        // 取消所有與此備忘錄相關的通知
        var identifiers = memo.reminderRules.map { "memo_\(memo.id)_\($0.id)" }
        identifiers.append("memo_\(memo.id)_auto_due")
        identifiers.append("memo_\(memo.id)_auto_plan")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Cancelled notifications for memo '\(memo.title)'")
    }
    
    // 除錯用：列出所有排程的通知
    func listAllPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let memoRequests = requests.filter { $0.identifier.hasPrefix("memo_") }
            if memoRequests.isEmpty {
                print("📭 No pending memo notifications.")
            } else {
                print("📬 Pending memo notifications (\(memoRequests.count)):")
                for request in memoRequests {
                    print("  ────────────────────")
                    print("  📝 \(request.content.title)")
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        // 將 dateComponents 轉成可讀時間
                        let dc = trigger.dateComponents
                        let timeStr = String(format: "%02d:%02d", dc.hour ?? 0, dc.minute ?? 0)
                        let dateStr = dc.year != nil ? "\(dc.year!)/\(dc.month ?? 0)/\(dc.day ?? 0)" : "重複"
                        print("  ⏰ \(dateStr) \(timeStr)")
                        print("  🔁 重複: \(trigger.repeats ? "是" : "否")")
                    }
                }
                print("  ────────────────────")
            }
        }
    }
    
    // 除錯用：發送測試通知（5秒後）
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🧪 測試通知"
        content.body = "如果你看到這個，通知功能正常運作！"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "memo_test_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification failed: \(error)")
            } else {
                print("✅ Test notification scheduled - will appear in 5 seconds")
                print("💡 記得把 App 切到背景才能看到通知橫幅！")
            }
        }
    }
}
