//
//  TimeTableView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI
import CloudKit

struct TimeTableView: View {
    @StateObject var courseData = CourseData()
    @State var isEdit = false
    var body: some View {
        NavigationStack {
            ScrollView{
                VStack {
                    CourseGridView(courseData: courseData, isEdit: $isEdit)
                }
            }
            .navigationTitle("Course Schedule")
            .toolbar{
                if isEdit == false{
                    ToolbarItem {
                        Button {
                            isEdit = true
                        } label: {
                            Text("edit")
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
        }
    }
}

#Preview {
    TimeTableView()
}
