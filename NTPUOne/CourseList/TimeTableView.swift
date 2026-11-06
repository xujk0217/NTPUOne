//
//  TimeTableView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI
import CloudKit

struct TimeTableView: View {
    @EnvironmentObject var courseData: CourseData
    @EnvironmentObject var adFree: AdFreeService
    @ObservedObject var memoManager: MemoManager
    @State var isEdit = false
    @State var isShowingGetCourseSheet = false
    @State private var isSaturday: Bool = UserDefaults.standard.bool(forKey: "isSaturday")
    @State private var includeNight: Bool = UserDefaults.standard.bool(forKey: "includeNight")
    
    @State var showDeleteAllAlert = false
    @State private var totalMemoCount = 0

    @State private var refreshTrigger: Bool = false
    
    init(memoManager: MemoManager) {
        self.memoManager = memoManager
    }
    
    @State private var clearFailed = false
    @State private var selectedConflict: CourseData.SyncConflict?
    @State private var conflictDay = "Monday"
    @State private var conflictSlot: Course.TimeSlot = .morning1
    @State private var confirmRemoveConflict = false
    @State private var showConflicts = false
    private let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private var conflictNotice: some View {
        DisclosureGroup(isExpanded: $showConflicts) {
            ForEach(courseData.syncConflicts) { conflict in
                Button {
                    conflictDay = weekdays.contains(conflict.course.day) ? conflict.course.day : "Monday"
                    conflictSlot = conflict.course.timeSlot
                    selectedConflict = conflict
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(conflict.course.name)
                            Text("\(NSLocalizedString(conflict.course.day, comment: "")) · \(NSLocalizedString(conflict.course.timeSlot.rawValue, comment: ""))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.vertical, 6)
            }
        } label: {
            Label("課表有 \(courseData.syncConflicts.count) 筆同步衝突", systemImage: "exclamationmark.triangle")
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func conflictEditor(_ conflict: CourseData.SyncConflict) -> some View {
        NavigationStack {
            Form {
                Section {
                    Text("這筆課程已保留，請選擇空的時段，或移除這筆課程。")
                    Picker("星期", selection: $conflictDay) {
                        ForEach(weekdays, id: \.self) { day in Text(LocalizedStringKey(day)).tag(day) }
                    }
                    Picker("節次", selection: $conflictSlot) {
                        ForEach(Course.TimeSlot.allCases) { slot in Text(LocalizedStringKey(slot.rawValue)).tag(slot) }
                    }
                    Button("移到選擇的時段") {
                        if courseData.resolveConflict(conflict.id, day: conflictDay, slot: conflictSlot) {
                            selectedConflict = nil
                        }
                    }
                    .disabled(conflictDay == conflict.course.day && conflictSlot == conflict.course.timeSlot)
                }
                Button("移除這筆課程", role: .destructive) { confirmRemoveConflict = true }
            }
            .navigationTitle(conflict.course.name)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { selectedConflict = nil } } }
            .confirmationDialog("移除這筆衝突課程？", isPresented: $confirmRemoveConflict, titleVisibility: .visible) {
                Button("移除", role: .destructive) {
                    if courseData.removeConflict(conflict.id) {
                        memoManager.loadMemosFromCoreData()
                        selectedConflict = nil
                    }
                }
            } message: {
                Text("已連結的備忘錄會保留。如果同一課程 ID 還有其他紀錄，原有連結也會保留。")
            }
        }
    }
    private func clearSchedule(deleteMemos: Bool) {
        let oldMemos = memoManager.memos
        guard courseData.clearSchedule(deleteLinkedMemos: deleteMemos) else { clearFailed = true; return }
        for memo in oldMemos { memoManager.cancelNotification(for: memo) }
        memoManager.loadMemosFromCoreData()
        memoManager.scheduleNotificationsForAllMemos()
    }
    var body: some View {
        NavigationStack {
            ScrollView{
                VStack {
                    if !courseData.syncConflicts.isEmpty { conflictNotice }
                    if isEdit{
                        Toggle("Saturday", isOn: $isSaturday)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                            .padding(.horizontal)
                            .padding(.top)
                            .onChange(of: isSaturday) { newValue in
                                // Save the new value to UserDefaults
                                UserDefaults.standard.set(newValue, forKey: "isSaturday")
                            }
                        Toggle("Night", isOn: $includeNight)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                            .padding(.horizontal)
                            .padding(.bottom)
                            .onChange(of: includeNight) { newValue in
                                // Save the new value to UserDefaults
                                UserDefaults.standard.set(newValue, forKey: "includeNight")
                            }

                    }
//                    if isSaturday == false{
//                        CourseGridView(courseData: courseData, isEdit: $isEdit)
//                    } else{
//                        CourseGridSatView(courseData: courseData, isEdit: $isEdit)
//                    }
                    UnifiedCourseGridView(courseData: courseData, isEdit: $isEdit, includeSaturday: $isSaturday, includeNight: $includeNight, memoManager: memoManager)

                    // Native 廣告
                    if !adFree.isAdFree {
                        NativeAdSectionView(style: .compact)
                            .frame(height: 140)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemGray5))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal)
                    }

                    if isEdit {
                        Button(role: .destructive) {
                            // 計算有連結課程的任務數量（courseLink 存的是課程 ID）
                            let allCourseIds = Set(courseData.courses.map(\.id) + courseData.syncConflicts.map { $0.course.id })
                            totalMemoCount = memoManager.memos.filter { memo in
                                guard let courseLink = memo.courseLink, !courseLink.isEmpty else { return false }
                                return allCourseIds.contains(courseLink)
                            }.count
                            showDeleteAllAlert = true
                        } label: {
                            Label(String(localized: "delete_all_courses"), systemImage: "trash")
                                .padding()
                        }
                        .alert(String(localized: "alert_confirm_delete_all"), isPresented: $showDeleteAllAlert) {
                            Button("清空課表，保留備忘錄", role: .destructive) { clearSchedule(deleteMemos: false) }
                            if totalMemoCount > 0 {
                                Button("連同 \(totalMemoCount) 筆備忘錄一起刪除", role: .destructive) { clearSchedule(deleteMemos: true) }
                            }
                            Button("取消", role: .cancel) { }
                        } message: {
                            if totalMemoCount > 0 {
                                Text("有 \(totalMemoCount) 筆連結的備忘錄。保留時只會解除課程連結；選擇一起刪除則無法復原。")
                            } else {
                                Text(String(localized: "delete_all_courses_confirm"))
                            }
                        }
                    }
                }
            }
            .alert("無法清空課表", isPresented: $clearFailed) { Button("好", role: .cancel) {} } message: { Text("資料未變更，請稍後重試。") }
            .sheet(item: $selectedConflict) { conflictEditor($0) }
            .navigationTitle("Course Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement: .principal) {
                    Text("Course Schedule")
                        .font(.headline.bold())
                }
                ToolbarItem{
                    Button {
                        isShowingGetCourseSheet.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }

                }
                if isEdit {
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink { AcademicCourseImportView() } label: {
                            Image(systemName: "arrow.clockwise")
                        }.accessibilityLabel("更新校務課表")
                    }
                }
                if isEdit == false{
                    ToolbarItem {
                        Button {
                            isEdit = true
                        } label: {
                            Text("Edit")
                        }
                    }
                } else {
                    ToolbarItem {
                        Button {
                            isEdit = false
                        } label: {
                            Text("Done")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingGetCourseSheet, content: {
                CourseGetView(courseData: courseData, isPresented: $isShowingGetCourseSheet)
                    .presentationDetents([.medium])
            })
        }
        .onAppear {
            // 每次顯示時重新加載備忘錄數據，確保點點是最新的
            memoManager.loadMemosFromCoreData()
        }
        .onDisappear {
            isEdit = false
        }
    }
}

#Preview {
    let context = CoreDataManager.shared.persistentContainer.viewContext
    TimeTableView(memoManager: MemoManager(context: context))
}
