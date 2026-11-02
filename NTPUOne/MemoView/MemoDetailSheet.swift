//
//  MemoDetailSheet.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//

import SwiftUI

struct MemoDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var academic: AcademicSyncStore
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    
    @State private var memo: Memo
    @State private var showEditSheet = false
    @State private var currentStatus: Memo.MemoStatus
    
    init(memoManager: MemoManager, courseData: CourseData, memo: Memo) {
        self.memoManager = memoManager
        self.courseData = courseData
        self._memo = State(initialValue: memo)
        self._currentStatus = State(initialValue: memo.status)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if let task = academic.remoteTask(for: memo.id) {
                    Section {
                        NavigationLink { AcademicTaskView(task: task) } label: {
                            Label("Moodle 作業來源與繳交狀態", systemImage: "link")
                        }
                    }
                }
                // 基本資訊
                Section {
                    // 標題
                    HStack {
                        Image(systemName: memo.tagType.icon)
                            .foregroundColor(memo.tagType.color)
                        Text(memo.title)
                            .font(.headline)
                    }
                    
                    // 內容
                    if !memo.content.isEmpty {
                        Text(memo.content)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 課程連結
                    if let courseLink = memo.courseLink,
                       let courseName = courseData.courses.first(where: { $0.id == courseLink })?.name {
                        HStack {
                            Image(systemName: "book.closed")
                                .foregroundColor(.blue)
                            Text(courseName)
                                .font(.subheadline)
                        }
                    }
                }
                
                // 時間資訊
                Section(String(localized: "time_section")) {
                    if let planAt = memo.planAt {
                        HStack {
                            Label(String(localized: "plan_time_label"), systemImage: "calendar")
                            Spacer()
                            Text(formatDate(planAt))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let dueAt = memo.dueAt {
                        HStack {
                            Label(String(localized: "due_time_label"), systemImage: "clock.badge.exclamationmark")
                            Spacer()
                            Text(formatDate(dueAt))
                                .foregroundColor(memo.isOverdue ? .red : .secondary)
                        }
                    }
                    
                    if memo.isOverdue {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(memo.dueDateDescription ?? String(localized: "already_overdue"))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // 狀態設定
                Section(String(localized: "status_section")) {
                    ForEach(Memo.MemoStatus.allCases) { status in
                        Button {
                            updateStatus(to: status)
                        } label: {
                            HStack {
                                Image(systemName: status.icon)
                                    .foregroundColor(status.color)
                                Text(status.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if currentStatus == status {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // 提醒設定
                Section(String(localized: "reminder_section")) {
                    // 過濾已過期的非重複提醒
                    let activeRules = memo.reminderRules.filter { rule in
                        rule.repeatType != .none || rule.triggerAt > Date()
                    }
                    
                    // 檢查是否有自動提醒
                    let hasBeforeDueReminder = memo.reminderRules.contains { $0.enabled && $0.kind == .beforeDue }
                    let hasPlanReminder = memo.reminderRules.contains { $0.enabled && $0.kind == .atPlan }
                    let showAutoDueReminder = memo.dueAt != nil && !hasBeforeDueReminder && !memo.disableAutoDueReminder
                    let showAutoPlanReminder = memo.planAt != nil && !hasPlanReminder && !memo.disableAutoPlanReminder
                    
                    // 顯示現有提醒
                    if activeRules.isEmpty && !showAutoDueReminder && !showAutoPlanReminder && !memo.disableAutoDueReminder && !memo.disableAutoPlanReminder {
                        Text(String(localized: "reminder_not_set"))
                            .foregroundColor(.secondary)
                    } else {
                        // 用戶自訂提醒
                        ForEach(activeRules) { rule in
                            HStack {
                                Image(systemName: rule.enabled ? "bell" : "bell.slash")
                                    .foregroundColor(rule.enabled ? .blue : .gray)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatDate(rule.triggerAt))
                                        .font(.subheadline)
                                    if rule.repeatType != .none {
                                        Text(rule.repeatType.displayName)
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                Spacer()
                                Text(rule.kind.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 自動截止前提醒
                        if showAutoDueReminder, let dueAt = memo.dueAt {
                            // 提醒1：截止前一天
                            let oneDayBefore = dueAt.addingTimeInterval(-24 * 60 * 60)
                            if oneDayBefore > Date() {
                                HStack {
                                    Image(systemName: "bell")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatDate(oneDayBefore))
                                            .font(.subheadline)
                                        Text(String(localized: "1_day_before_due"))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(String(localized: "auto"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 提醒2：截止前 30 分鐘
                            let thirtyMinsBefore = dueAt.addingTimeInterval(-30 * 60)
                            if thirtyMinsBefore > Date() {
                                HStack {
                                    Image(systemName: "bell")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatDate(thirtyMinsBefore))
                                            .font(.subheadline)
                                        Text(String(localized: "30_min_before_due"))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(String(localized: "auto"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else if memo.dueAt != nil && !hasBeforeDueReminder && memo.disableAutoDueReminder {
                            // 顯示已禁用的自動提醒
                            HStack {
                                Image(systemName: "bell.slash")
                                    .foregroundColor(.gray)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "30_min_before_deadline"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(String(localized: "disabled"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(localized: "auto"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 自動計劃時間提醒
                        if showAutoPlanReminder, let planAt = memo.planAt, planAt > Date() {
                            HStack {
                                Image(systemName: "bell")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatDate(planAt))
                                        .font(.subheadline)
                                    Text(String(localized: "plan_time_start"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(localized: "auto"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if memo.planAt != nil && !hasPlanReminder && memo.disableAutoPlanReminder {
                            // 顯示已禁用的自動提醒
                            HStack {
                                Image(systemName: "bell.slash")
                                    .foregroundColor(.gray)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "plan_time"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(String(localized: "disabled"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(localized: "auto"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 提示
                    Text(String(localized: "edit_reminder_hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 編輯按鈕
                Section {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label(String(localized: "edit_details"), systemImage: "pencil")
                    }
                }
            }
            .navigationTitle(String(localized: "navigation_memo_detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditSheet, onDismiss: {
                // 編輯完成後，重新從 memoManager 獲取最新的 memo 數據
                if let updatedMemo = memoManager.memos.first(where: { $0.id == memo.id }) {
                    memo = updatedMemo
                    currentStatus = updatedMemo.status
                }
            }) {
                MemoFormView(
                    memoManager: memoManager,
                    courseData: courseData,
                    memo: memo
                )
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func updateStatus(to status: Memo.MemoStatus) {
        currentStatus = status
        var updatedMemo = memo
        updatedMemo.status = status
        updatedMemo.updatedAt = Date()
        
        if status == .done {
            updatedMemo.doneAt = Date()
        } else {
            updatedMemo.doneAt = nil
        }
        
        memoManager.updateMemo(updatedMemo)
    }
    
}

#Preview {
    MemoDetailSheet(
        memoManager: MemoManager(),
        courseData: CourseData(),
        memo: Memo.create(title: "測試備忘錄")
    )
}
