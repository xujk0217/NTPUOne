//
//  MemoFormView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//

import SwiftUI

struct MemoFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    
    let memo: Memo?
    
    // 預設值（從 Today 頁面傳入）
    var presetCourseLink: String? = nil
    var presetPlanAt: Date? = nil
    
    // 表單狀態
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var tagType: Memo.TagType = .other
    @State private var priority: Memo.Priority = .medium
    @State private var selectedCourseId: String? = nil
    
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var hasPlanDate: Bool = false
    @State private var planDate: Date = Date()
    
    @State private var status: Memo.MemoStatus = .todo
    
    @State private var reminderRules: [ReminderRule] = []
    @State private var showAddReminder: Bool = false
    @State private var disableAutoDueReminder: Bool = false
    @State private var disableAutoPlanReminder: Bool = false
    
    private var isEditing: Bool { memo != nil }
    
    // 去重複的課程列表（只保留不同名稱的課程）
    private var uniqueCourses: [Course] {
        var seenNames = Set<String>()
        return courseData.courses.filter { course in
            if seenNames.contains(course.name) {
                return false
            } else {
                seenNames.insert(course.name)
                return true
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本資訊
                Section(String(localized: "basic_section")) {
                    TextField(String(localized: "textfield_title"), text: $title)
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if content.isEmpty {
                                    Text(String(localized: "note_optional"))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                // 分類
                Section {
                    // 標籤類型
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "tag_type"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Memo.TagType.allCases) { tag in
                                    Button {
                                        tagType = tag
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: tag.icon)
                                                .font(.caption)
                                            Text(tag.displayName)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(tagType == tag ? tag.color.opacity(0.2) : Color.gray.opacity(0.1))
                                        .foregroundColor(tagType == tag ? tag.color : .secondary)
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(tagType == tag ? tag.color : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    
                    // 優先級
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "priority"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(Memo.Priority.allCases) { p in
                                Button {
                                    priority = p
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: p.icon)
                                            .font(.subheadline)
                                        Text(p.displayName)
                                            .font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(priority == p ? p.color.opacity(0.2) : Color.gray.opacity(0.1))
                                    .foregroundColor(priority == p ? p.color : .secondary)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(priority == p ? p.color : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text(String(localized: "category_section"))
                }
                
                // 連結課程
                Section(String(localized: "link_course_section")) {
                    Picker(String(localized: "picker_select_course"), selection: $selectedCourseId) {
                        Text(String(localized: "no_course_link"))
                            .tag(nil as String?)
                        
                        ForEach(uniqueCourses, id: \.name) { course in
                            Text(course.name)
                                .tag(course.id as String?)
                        }
                    }
                }
                
                // 時間設定
                Section(String(localized: "time_settings_section")) {
                    Toggle(String(localized: "toggle_set_plan_time"), isOn: $hasPlanDate)
                    
                    if hasPlanDate {
                        DatePicker(
                            String(localized: "plan_time_label"),
                            selection: $planDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                    
                    Toggle(String(localized: "toggle_set_due_time"), isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            String(localized: "due_time_label"),
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                // 狀態設定（編輯模式）
                if isEditing {
                    Section(String(localized: "status_section")) {
                        Picker(String(localized: "picker_current_status"), selection: $status) {
                            ForEach(Memo.MemoStatus.allCases) { s in
                                HStack {
                                    Image(systemName: s.icon)
                                        .foregroundColor(s.color)
                                    Text(s.displayName)
                                }
                                .tag(s)
                            }
                        }
                    }
                }
                
                // 提醒設定
                Section {
                    // 檢查是否有自動提醒
                    let hasBeforeDueReminder = reminderRules.contains { $0.enabled && $0.kind == .beforeDue }
                    let hasPlanReminder = reminderRules.contains { $0.enabled && $0.kind == .atPlan }
                    let showAutoDueReminder = hasDueDate && !hasBeforeDueReminder && !disableAutoDueReminder
                    let showAutoPlanReminder = hasPlanDate && !hasPlanReminder && !disableAutoPlanReminder
                    
                    // 用戶自訂提醒
                    ForEach(reminderRules) { rule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(rule.kind.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatDate(rule.triggerAt))
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { rule.enabled },
                                set: { newValue in
                                    if let index = reminderRules.firstIndex(where: { $0.id == rule.id }) {
                                        reminderRules[index].enabled = newValue
                                    }
                                }
                            ))
                            .labelsHidden()
                            
                            Button {
                                reminderRules.removeAll { $0.id == rule.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // 自動截止前提醒
                    if showAutoDueReminder {
                        // 提醒1：截止前一天
                        let oneDayBefore = dueDate.addingTimeInterval(-24 * 60 * 60)
                        if oneDayBefore > Date() {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(String(localized: "auto"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDate(oneDayBefore))
                                        .font(.subheadline)
                                    Text(String(localized: "1_day_before_due"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { !disableAutoDueReminder },
                                    set: { disableAutoDueReminder = !$0 }
                                ))
                                .labelsHidden()
                            }
                        }
                        
                        // 提醒2：截止前30分鐘
                        let thirtyMinsBefore = dueDate.addingTimeInterval(-30 * 60)
                        if thirtyMinsBefore > Date() {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(String(localized: "auto"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDate(thirtyMinsBefore))
                                        .font(.subheadline)
                                    Text(String(localized: "30_min_before_due"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { !disableAutoDueReminder },
                                    set: { disableAutoDueReminder = !$0 }
                                ))
                                .labelsHidden()
                            }
                        }
                    } else if hasDueDate && !hasBeforeDueReminder && disableAutoDueReminder {
                        // 顯示已禁用的自動提醒
                        HStack {
                            VStack(alignment: .leading) {
                                Text(String(localized: "auto_disabled"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(localized: "30_min_before_deadline"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !disableAutoDueReminder },
                                set: { disableAutoDueReminder = !$0 }
                            ))
                            .labelsHidden()
                        }
                    }
                    
                    // 自動計劃時間提醒
                    if showAutoPlanReminder {
                        if planDate > Date() {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(String(localized: "auto"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDate(planDate))
                                        .font(.subheadline)
                                    Text(String(localized: "plan_time_start"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { !disableAutoPlanReminder },
                                    set: { disableAutoPlanReminder = !$0 }
                                ))
                                .labelsHidden()
                            }
                        }
                    } else if hasPlanDate && !hasPlanReminder && disableAutoPlanReminder {
                        // 顯示已禁用的自動提醒
                        HStack {
                            VStack(alignment: .leading) {
                                Text(String(localized: "auto_disabled"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(localized: "plan_time"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !disableAutoPlanReminder },
                                set: { disableAutoPlanReminder = !$0 }
                            ))
                            .labelsHidden()
                        }
                    }
                    
                    Button {
                        showAddReminder = true
                    } label: {
                        Label(String(localized: "add_reminder"), systemImage: "bell.badge.plus")
                    }
                } header: {
                    Text(String(localized: "reminder_settings"))
                } footer: {
                    Text(String(localized: "reminder_push_hint"))
                }
                
                // 刪除按鈕（編輯模式）
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if let memo = memo {
                                memoManager.deleteMemo(memo)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text(String(localized: "delete_memo"))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "edit") : String(localized: "add_memo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "save")) {
                        saveMemo()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showAddReminder) {
                AddReminderSheet(
                    dueDate: hasDueDate ? dueDate : nil,
                    planDate: hasPlanDate ? planDate : nil
                ) { newRule in
                    reminderRules.append(newRule)
                }
            }
            .onAppear {
                loadMemoData()
            }
        }
    }
    
    private func loadMemoData() {
        // 如果是編輯模式，載入現有資料
        if let memo = memo {
            title = memo.title
            content = memo.content
            tagType = memo.tagType
            priority = memo.priority
            selectedCourseId = memo.courseLink
            status = memo.status
            
            if let dueAt = memo.dueAt {
                hasDueDate = true
                dueDate = dueAt
            }
            
            if let planAt = memo.planAt {
                hasPlanDate = true
                planDate = planAt
            }
            
            reminderRules = memo.reminderRules
            disableAutoDueReminder = memo.disableAutoDueReminder
            disableAutoPlanReminder = memo.disableAutoPlanReminder
        } else {
            // 新增模式：套用預設值
            if let presetCourseLink = presetCourseLink {
                selectedCourseId = presetCourseLink
            }
            
            if let presetPlanAt = presetPlanAt {
                hasPlanDate = true
                planDate = presetPlanAt
            }
        }
    }
    
    private func saveMemo() {
        let now = Date()
        
        if let existingMemo = memo {
            // 更新
            var updatedMemo = existingMemo
            updatedMemo.title = title.trimmingCharacters(in: .whitespaces)
            updatedMemo.content = content
            updatedMemo.tagType = tagType
            updatedMemo.priority = priority
            updatedMemo.courseLink = selectedCourseId
            updatedMemo.status = status
            updatedMemo.dueAt = hasDueDate ? dueDate : nil
            updatedMemo.planAt = hasPlanDate ? planDate : nil
            updatedMemo.updatedAt = now
            updatedMemo.reminderRules = reminderRules
            updatedMemo.disableAutoDueReminder = disableAutoDueReminder
            updatedMemo.disableAutoPlanReminder = disableAutoPlanReminder
            
            // 如果狀態改為完成，設定完成時間
            if status == .done && existingMemo.status != .done {
                updatedMemo.doneAt = now
            } else if status != .done {
                updatedMemo.doneAt = nil
            }
            
            memoManager.updateMemo(updatedMemo)
        } else {
            // 新增
            var newMemo = Memo.create(
                title: title.trimmingCharacters(in: .whitespaces),
                content: content,
                tagType: tagType,
                courseLink: selectedCourseId,
                priority: priority,
                dueAt: hasDueDate ? dueDate : nil,
                planAt: hasPlanDate ? planDate : nil
            )
            newMemo.reminderRules = reminderRules
            newMemo.disableAutoDueReminder = disableAutoDueReminder
            newMemo.disableAutoPlanReminder = disableAutoPlanReminder
            
            memoManager.addMemo(newMemo)
        }
        
        dismiss()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 新增提醒 Sheet
struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let dueDate: Date?
    let planDate: Date?
    let onAdd: (ReminderRule) -> Void
    
    @State private var kind: ReminderRule.ReminderKind = .custom
    @State private var customDate: Date = Date()
    @State private var beforeDueMinutes: Int = 30
    @State private var repeatType: ReminderRule.RepeatType = .none
    
    private let beforeOptions: [(Int, String)] = {
        return [
            (15, String(localized: "15_min_before")),
            (30, String(localized: "30_min_before")),
            (60, String(localized: "1_hour_before")),
            (120, String(localized: "2_hours_before")),
            (1440, String(localized: "1_day_before")),
            (2880, String(localized: "2_days_before"))
        ]
    }()
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "reminder_type_section")) {
                    Picker(String(localized: "picker_type"), selection: $kind) {
                        if dueDate != nil {
                            Text(String(localized: "before_due_option")).tag(ReminderRule.ReminderKind.beforeDue)
                        }
                        if planDate != nil {
                            Text(String(localized: "at_plan_option")).tag(ReminderRule.ReminderKind.atPlan)
                        }
                        Text(String(localized: "custom_time_option")).tag(ReminderRule.ReminderKind.custom)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(String(localized: "reminder_time_section")) {
                    switch kind {
                    case .beforeDue:
                        if let dueDate = dueDate {
                            Picker(String(localized: "advance_time"), selection: $beforeDueMinutes) {
                                ForEach(beforeOptions, id: \.0) { minutes, label in
                                    Text(label).tag(minutes)
                                }
                            }
                            
                            Text(String(localized: "will_remind_at_format", defaultValue: "Will remind at \(formatDate(calculateBeforeDueDate(dueDate)))"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                    case .atPlan:
                        if let planDate = planDate {
                            Text(String(localized: "will_remind_at_format", defaultValue: "Will remind at \(formatDate(planDate))"))
                                .foregroundColor(.secondary)
                        }
                        
                    case .custom:
                        DatePicker(
                            String(localized: "reminder_time"),
                            selection: $customDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                Section(String(localized: "repeat_settings_section")) {
                    Picker(String(localized: "picker_repeat"), selection: $repeatType) {
                        ForEach(ReminderRule.RepeatType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    if repeatType != .none {
                        Text(repeatDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "navigation_add_reminder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "add")) {
                        addReminder()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var repeatDescription: String {
        let triggerAt = calculateTriggerDate()
        let formatter = DateFormatter()
        
        switch repeatType {
        case .none:
            return ""
        case .daily:
            formatter.dateFormat = "HH:mm"
            return String(localized: "daily_at \(formatter.string(from: triggerAt))")
        case .weekly:
            formatter.dateFormat = "EEEE HH:mm"
            return String(localized: "weekly_at \(formatter.string(from: triggerAt))")
        case .monthly:
            let day = Calendar.current.component(.day, from: triggerAt)
            formatter.dateFormat = "HH:mm"
            return String(localized: "monthly_at \(day) \(formatter.string(from: triggerAt))")
        }
    }
    
    private func calculateTriggerDate() -> Date {
        switch kind {
        case .beforeDue:
            if let dueDate = dueDate {
                return calculateBeforeDueDate(dueDate)
            }
        case .atPlan:
            if let planDate = planDate {
                return planDate
            }
        case .custom:
            return customDate
        }
        return Date()
    }
    
    private func addReminder() {
        let triggerAt = calculateTriggerDate()
        
        var rule = ReminderRule(triggerAt: triggerAt, enabled: true, kind: kind)
        rule.repeatType = repeatType
        onAdd(rule)
        dismiss()
    }
    
    private func calculateBeforeDueDate(_ dueDate: Date) -> Date {
        return dueDate.addingTimeInterval(-Double(beforeDueMinutes * 60))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    MemoFormView(
        memoManager: MemoManager(),
        courseData: CourseData(),
        memo: nil
    )
}
