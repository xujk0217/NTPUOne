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

                    if isEdit{
                        Button(role: .destructive) {
                            // 計算有連結課程的任務數量（courseLink 存的是課程 ID）
                            let allCourseIds = Set(courseData.courses.map { $0.id })
                            totalMemoCount = memoManager.memos.filter { memo in
                                guard let courseLink = memo.courseLink, !courseLink.isEmpty else { return false }
                                return allCourseIds.contains(courseLink)
                            }.count
                            showDeleteAllAlert = true
                        } label: {
                            Label("刪除所有課程", systemImage: "trash")
                                .padding()
                        }
                        .alert("確認刪除所有課程", isPresented: $showDeleteAllAlert) {
                            Button("刪除", role: .destructive) {
                                // 先刪除所有有連結課程的任務（courseLink 存的是課程 ID）
                                let allCourseIds = Set(courseData.courses.map { $0.id })
                                let memosToDelete = memoManager.memos.filter { memo in
                                    guard let courseLink = memo.courseLink, !courseLink.isEmpty else { return false }
                                    return allCourseIds.contains(courseLink)
                                }
                                for memo in memosToDelete {
                                    memoManager.deleteMemo(memo)
                                }
                                // 再刪除所有課程
                                courseData.deleteAllCourses()
                                // 刷新備忘錄數據
                                memoManager.loadMemosFromCoreData()
                            }
                            Button("取消", role: .cancel) { }
                        } message: {
                            if totalMemoCount > 0 {
                                Text("刪除所有課程後，將同時刪除 \(totalMemoCount) 個連結到課程的任務。此操作無法復原。")
                            } else {
                                Text("確定要刪除所有課程嗎？此操作無法復原。")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Course Schedule")
            .toolbar{
                ToolbarItem{
                    Button {
                        isShowingGetCourseSheet.toggle()
                    } label: {
                        Image(systemName: "plus")
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
            if !adFree.isAdFree{
                // 廣告標記
                Section {
                    BannerAdView()
                        .frame(height: 50)
                }
            }
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
