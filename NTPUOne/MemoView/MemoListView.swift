//
//  MemoListView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//

import SwiftUI

struct MemoListView: View {
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    
    @State private var showAddMemo = false
    @State private var selectedMemo: Memo? = nil
    @State private var showFilterSheet = false
    @State private var viewMode: ViewMode = .all  // 新增：顯示模式
    @State private var statusPickerMemo: Memo? = nil
    
    enum ViewMode {
        case all        // 全部列表
        case byCourse   // 依課程分類
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 統計卡片
                statisticsCard
                
                // 篩選標籤
                filterTagsView
                
                // 備忘錄列表
                if memoManager.filteredMemos.isEmpty && viewMode == .all {
                    emptyStateView
                } else {
                    if viewMode == .all {
                        memoListContent
                    } else {
                        memoByCourseContent
                    }
                }
            }
            .navigationTitle("備忘錄")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddMemo = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        // 顯示模式切換
                        Menu {
                            Button {
                                viewMode = .all
                            } label: {
                                HStack {
                                    Text("全部列表")
                                    if viewMode == .all {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Button {
                                viewMode = .byCourse
                            } label: {
                                HStack {
                                    Text("依課程分類")
                                    if viewMode == .byCourse {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: viewMode == .all ? "list.bullet" : "folder")
                        }
                        
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
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddMemo) {
                MemoFormView(memoManager: memoManager, courseData: courseData, memo: nil)
            }
            .sheet(item: $statusPickerMemo) { memo in
                StatusPickerSheet(memo: memo) { status in
                    memoManager.updateStatus(memo, to: status)
                }
            }
            .sheet(item: $selectedMemo) { memo in
                MemoFormView(memoManager: memoManager, courseData: courseData, memo: memo)
            }
        }
    }
    
    // MARK: - 統計卡片
    private var statisticsCard: some View {
        let stats = memoManager.statistics()
        
        return HStack(spacing: 12) {
            StatCard(title: "總計", value: "\(stats.total)", color: .blue, icon: "list.bullet")
            StatCard(title: "已完成", value: "\(stats.completed)", color: .green, icon: "checkmark.circle")
            StatCard(title: "逾期", value: "\(stats.overdue)", color: .red, icon: "exclamationmark.triangle")
            StatCard(title: "今日", value: "\(stats.todayDue)", color: .orange, icon: "calendar")
        }
        .padding()
    }
    
    // MARK: - 篩選標籤
    private var filterTagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 狀態篩選
                FilterChip(
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
                
                FilterChip(
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
                
                FilterChip(
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
                
                FilterChip(
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
                
                FilterChip(
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
                
                // 逾期篩選
                FilterChip(
                    title: "逾期",
                    isSelected: memoManager.showOverdueOnly,
                    color: .red
                ) {
                    memoManager.showOverdueOnly.toggle()
                    memoManager.applyFiltersAndSort()
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - 空狀態
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("沒有備忘錄")
                .font(.headline)
                .foregroundColor(.gray)
            Text("點擊右上角 + 新增")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
            Spacer()
        }
    }
    
    // MARK: - 備忘錄列表
    private var memoListContent: some View {
        List {
            ForEach(memoManager.filteredMemos) { memo in
                MemoRowView(
                    memo: memo,
                    courseName: getCourseName(for: memo.courseLink),
                    onStatusTap: {
                        statusPickerMemo = memo
                    },
                    onTap: {
                        selectedMemo = memo
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        memoManager.deleteMemo(memo)
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                    
                    Button {
                        selectedMemo = memo
                    } label: {
                        Label("編輯", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        memoManager.toggleCompletion(memo)
                    } label: {
                        Label(
                            memo.status == .done ? "取消完成" : "完成",
                            systemImage: memo.status == .done ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    .tint(memo.status == .done ? .orange : .green)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - 依課程分類的備忘錄列表
    private var memoByCourseContent: some View {
        List {
            // 未連結課程的備忘錄
            let unlinkedMemos = memoManager.memos.filter { $0.courseLink == nil && $0.status != .done }
            if !unlinkedMemos.isEmpty {
                Section {
                    ForEach(unlinkedMemos) { memo in
                        memoRowWithActions(memo: memo)
                    }
                } header: {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(.gray)
                        Text("未分類")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(unlinkedMemos.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 依課程分組
            ForEach(uniqueCourses, id: \.name) { course in
                let courseMemos = memoManager.memos.filter { 
                    $0.courseLink == course.id && $0.status != .done 
                }
                if !courseMemos.isEmpty {
                    Section {
                        ForEach(courseMemos) { memo in
                            memoRowWithActions(memo: memo)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.blue)
                            Text(course.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(courseMemos.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 已完成的備忘錄（摺疊）
            let completedMemos = memoManager.memos.filter { $0.status == .done }
            if !completedMemos.isEmpty {
                Section {
                    ForEach(completedMemos) { memo in
                        memoRowWithActions(memo: memo)
                    }
                } header: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已完成")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(completedMemos.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // 去重複的課程列表
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
    
    // 帶有滑動操作的備忘錄列
    @ViewBuilder
    private func memoRowWithActions(memo: Memo) -> some View {
        MemoRowView(
            memo: memo,
            courseName: nil,  // 已在 Section 標題顯示課程名稱
            onStatusTap: {
                statusPickerMemo = memo
            },
            onTap: {
                selectedMemo = memo
            }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                memoManager.deleteMemo(memo)
            } label: {
                Label("刪除", systemImage: "trash")
            }
            
            Button {
                selectedMemo = memo
            } label: {
                Label("編輯", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                memoManager.toggleCompletion(memo)
            } label: {
                Label(
                    memo.status == .done ? "取消完成" : "完成",
                    systemImage: memo.status == .done ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(memo.status == .done ? .orange : .green)
        }
    }
    
    private func getCourseName(for courseId: String?) -> String? {
        guard let courseId = courseId else { return nil }
        return courseData.courses.first { $0.id == courseId }?.name
    }
}

// MARK: - 備忘錄列
struct MemoRowView: View {
    let memo: Memo
    let courseName: String?
    let onStatusTap: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // 完成按鈕
                Button(action: onStatusTap) {
                    Image(systemName: memo.status.icon)
                        .font(.title2)
                        .foregroundColor(memo.status.color)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    // 標題
                    HStack {
                        Text(memo.title)
                            .font(.headline)
                            .strikethrough(memo.status == .done)
                            .foregroundColor(memo.status == .done ? .gray : .primary)
                        
                        // 優先級標記
                        if memo.priority == .high {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    // 標籤和課程
                    HStack(spacing: 8) {
                        // 標籤
                        Label(memo.tagType.rawValue, systemImage: memo.tagType.icon)
                            .font(.caption)
                            .foregroundColor(memo.tagType.color)
                        
                        // 連結的課程
                        if let courseName = courseName {
                            Text("• \(courseName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 截止時間
                    if let description = memo.dueDateDescription {
                        HStack {
                            Image(systemName: memo.isOverdue ? "exclamationmark.triangle.fill" : "clock")
                                .font(.caption)
                            Text(description)
                                .font(.caption)
                        }
                        .foregroundColor(memo.isOverdue ? .red : .secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 統計卡片
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 篩選標籤
struct FilterChip: View {
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
                .background(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? color : .secondary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MemoListView(
        memoManager: MemoManager(),
        courseData: CourseData()
    )
}
