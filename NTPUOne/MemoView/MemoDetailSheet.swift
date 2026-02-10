//
//  MemoDetailSheet.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//

import SwiftUI

struct MemoDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    
    let memo: Memo
    @State private var showEditSheet = false
    @State private var currentStatus: Memo.MemoStatus
    
    init(memoManager: MemoManager, courseData: CourseData, memo: Memo) {
        self.memoManager = memoManager
        self.courseData = courseData
        self.memo = memo
        self._currentStatus = State(initialValue: memo.status)
    }
    
    var body: some View {
        NavigationStack {
            List {
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
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.blue)
                            Text(courseName)
                                .font(.subheadline)
                        }
                    }
                }
                
                // 時間資訊
                Section("時間") {
                    if let planAt = memo.planAt {
                        HStack {
                            Label("計劃時間", systemImage: "calendar")
                            Spacer()
                            Text(formatDate(planAt))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let dueAt = memo.dueAt {
                        HStack {
                            Label("截止時間", systemImage: "clock.badge.exclamationmark")
                            Spacer()
                            Text(formatDate(dueAt))
                                .foregroundColor(memo.isOverdue ? .red : .secondary)
                        }
                    }
                    
                    if memo.isOverdue {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(memo.dueDateDescription ?? "已逾期")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // 狀態設定
                Section("狀態") {
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
                Section("提醒") {
                    // 過濾已過期的非重複提醒
                    let activeRules = memo.reminderRules.filter { rule in
                        rule.repeatType != .none || rule.triggerAt > Date()
                    }
                    
                    // 顯示現有提醒
                    if activeRules.isEmpty {
                        Text("尚未設定提醒")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(activeRules) { rule in
                            HStack {
                                Image(systemName: rule.enabled ? "bell.fill" : "bell.slash")
                                    .foregroundColor(rule.enabled ? .blue : .gray)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatDate(rule.triggerAt))
                                        .font(.subheadline)
                                    if rule.repeatType != .none {
                                        Text(rule.repeatType.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                Spacer()
                                Text(rule.kind.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 提示
                    Text("如需修改提醒，請點擊下方編輯")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 編輯按鈕
                Section {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("編輯詳細資料", systemImage: "pencil")
                    }
                }
            }
            .navigationTitle("備忘錄詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
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
