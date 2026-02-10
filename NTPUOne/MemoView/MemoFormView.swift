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
                Section("基本資訊") {
                    TextField("標題", text: $title)
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if content.isEmpty {
                                    Text("備註內容（選填）")
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
                        Text("標籤類型")
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
                                            Text(tag.rawValue)
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
                        Text("優先級")
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
                                        Text(p.rawValue)
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
                    Text("分類")
                }
                
                // 連結課程
                Section("連結課程") {
                    Picker("選擇課程", selection: $selectedCourseId) {
                        Text("不連結課程")
                            .tag(nil as String?)
                        
                        ForEach(uniqueCourses, id: \.name) { course in
                            Text(course.name)
                                .tag(course.id as String?)
                        }
                    }
                }
                
                // 時間設定
                Section("時間設定") {
                    Toggle("設定計劃時間", isOn: $hasPlanDate)
                    
                    if hasPlanDate {
                        DatePicker(
                            "計劃時間",
                            selection: $planDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                    
                    Toggle("設定截止時間", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            "截止時間",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                // 狀態設定（編輯模式）
                if isEditing {
                    Section("狀態") {
                        Picker("目前狀態", selection: $status) {
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
                    ForEach(reminderRules) { rule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(rule.kind.rawValue)
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
                    
                    Button {
                        showAddReminder = true
                    } label: {
                        Label("新增提醒", systemImage: "bell.badge.plus")
                    }
                } header: {
                    Text("提醒設定")
                } footer: {
                    Text("提醒會在指定時間推送通知")
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
                                Text("刪除備忘錄")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "編輯備忘錄" : "新增備忘錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
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
    
    private let beforeOptions = [
        (15, "15 分鐘前"),
        (30, "30 分鐘前"),
        (60, "1 小時前"),
        (120, "2 小時前"),
        (1440, "1 天前"),
        (2880, "2 天前")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("提醒類型") {
                    Picker("類型", selection: $kind) {
                        if dueDate != nil {
                            Text("截止前").tag(ReminderRule.ReminderKind.beforeDue)
                        }
                        if planDate != nil {
                            Text("計劃時間").tag(ReminderRule.ReminderKind.atPlan)
                        }
                        Text("自訂時間").tag(ReminderRule.ReminderKind.custom)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("提醒時間") {
                    switch kind {
                    case .beforeDue:
                        if let dueDate = dueDate {
                            Picker("提前時間", selection: $beforeDueMinutes) {
                                ForEach(beforeOptions, id: \.0) { minutes, label in
                                    Text(label).tag(minutes)
                                }
                            }
                            
                            Text("將在 \(formatDate(calculateBeforeDueDate(dueDate))) 提醒")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                    case .atPlan:
                        if let planDate = planDate {
                            Text("將在 \(formatDate(planDate)) 提醒")
                                .foregroundColor(.secondary)
                        }
                        
                    case .custom:
                        DatePicker(
                            "提醒時間",
                            selection: $customDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                Section("重複設定") {
                    Picker("重複", selection: $repeatType) {
                        ForEach(ReminderRule.RepeatType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    if repeatType != .none {
                        Text(repeatDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("新增提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
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
            return "每天 \(formatter.string(from: triggerAt)) 提醒"
        case .weekly:
            formatter.dateFormat = "EEEE HH:mm"
            formatter.locale = Locale(identifier: "zh_TW")
            return "每週\(formatter.string(from: triggerAt)) 提醒"
        case .monthly:
            let day = Calendar.current.component(.day, from: triggerAt)
            formatter.dateFormat = "HH:mm"
            return "每月 \(day) 日 \(formatter.string(from: triggerAt)) 提醒"
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
