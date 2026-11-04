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
                            let allCourseIds = Set(courseData.courses.map { $0.id })
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
