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
    @State var isEdit = false
    @State var isShowingGetCourseSheet = false
    @State private var isSaturday: Bool = UserDefaults.standard.bool(forKey: "isSaturday")
    @State private var includeNight: Bool = UserDefaults.standard.bool(forKey: "includeNight")
    
    @State var showDeleteAllAlert = false

    @State private var refreshTrigger: Bool = false
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
                    UnifiedCourseGridView(courseData: courseData, isEdit: $isEdit, includeSaturday: $isSaturday, includeNight: $includeNight)

                    if isEdit{
                        Button(role: .destructive) {
                            showDeleteAllAlert = true
                        } label: {
                            Label("刪除所有課程", systemImage: "trash")
                                .padding()
                        }
                        .alert("你確定要刪除所有課程嗎？", isPresented: $showDeleteAllAlert) {
                            Button("刪除", role: .destructive) {
                                courseData.deleteAllCourses()
                            }
                            Button("取消", role: .cancel) { }
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
            // 廣告標記
            Section {
                BannerAdView()
                        .frame(height: 50) // 橫幅廣告的高度通常是 50
            }
        }.onDisappear {
            isEdit = false
        }
    }
}

#Preview {
    TimeTableView()
}
