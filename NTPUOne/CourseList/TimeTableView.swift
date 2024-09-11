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
                            .padding()
                            .onChange(of: isSaturday) { newValue in
                                // Save the new value to UserDefaults
                                UserDefaults.standard.set(newValue, forKey: "isSaturday")
                            }
                    }
                    if isSaturday == false{
                        CourseGridView(courseData: courseData, isEdit: $isEdit)
                    } else{
                        CourseGridSatView(courseData: courseData, isEdit: $isEdit)
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
        }.onDisappear {
            isEdit = false
        }
    }
}

#Preview {
    TimeTableView()
}
