//
//  CourseGridView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI

struct CourseGridView: View {
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @State private var showingAlert = false
    @State private var showingSheet = false
    @State private var selectedCourse = Course(id: "", name: "", day: "Friday", startTime: .none, timeSlot: .morning1, location: "", teacher: "")
    @State private var newCourse = Course(id: "", name: "", day: "Monday", startTime: .none, timeSlot: .morning1, location: "", teacher: "")
    @State private var isNewCourse = false

    var body: some View {
        LazyVGrid(columns: columns) {
            // Headers
            ForEach(["Mon", "Tue", "Wed", "Thur", "Fri"], id: \.self) { day in
                Text(day)
            }
            // Courses
            ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], id: \.self) { day in
                CourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showingSheet) {
            CourseFormSheet(isNewCourse: $isNewCourse, selectedCourse: $selectedCourse, newCourse: $newCourse, courseData: courseData, showingSheet: $showingSheet)
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(selectedCourse.name),
                message: Text("教授：\(selectedCourse.teacher == "" ? "..." : selectedCourse.teacher) 教授\n時間：\(selectedCourse.day), \(selectedCourse.startTime.rawValue)\n地點：\(selectedCourse.location == "" ? "..." : selectedCourse.location)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    var columns: [GridItem] {
        return Array(repeating: .init(.flexible()), count: 5)
    }
}

struct CourseColumnView: View {
    var day: String
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @Binding var showingSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var selectedCourse: Course
    @Binding var isNewCourse: Bool
    @Binding var newCourse: Course

    var body: some View {
        VStack {
            ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
                if slot == .morning4 {
                    LunchButtonView()
                } else if slot == .afternoon5 {
                    DinnerButtonView()
                }
            }
        }
    }
}

struct CourseSlotView: View {
    var day: String
    var slot: Course.TimeSlot
    var filteredCourses: [Course]
    @Binding var isEdit: Bool
    @Binding var showingSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var selectedCourse: Course
    @Binding var isNewCourse: Bool
    @Binding var newCourse: Course

    var body: some View {
        VStack {
            if filteredCourses.isEmpty {
                if isEdit {
                    Button(action: addNewCourse) {
                        Text("+")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                    }
                } else {
                    EmptySlotView()
                }
            } else {
                ForEach(filteredCourses) { course in
                    if isEdit {
                        Button(action: { editCourse(course) }) {
                            Text(course.name)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: { viewCourseDetails(course) }) {
                            Text(course.name)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .frame(height: 80)
        .frame(minWidth: 50, maxWidth: 70)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    func addNewCourse() {
        newCourse = Course(id: UUID().uuidString, name: "", day: day, startTime: .none, timeSlot: slot, location: "", teacher: "")
        isNewCourse = true
        showingSheet = true
    }

    func editCourse(_ course: Course) {
        selectedCourse = course
        isNewCourse = false
        showingSheet = true
    }

    func viewCourseDetails(_ course: Course) {
        selectedCourse = course
        showingAlert = true
    }

}

struct EmptySlotView: View {
    var body: some View {
        Text("")
            .font(.largeTitle)
            .foregroundColor(.green)
    }
}

struct CourseFormSheet: View {
    @Binding var isNewCourse: Bool
    @Binding var selectedCourse: Course
    @Binding var newCourse: Course
    var courseData: CourseData
    @Binding var showingSheet: Bool
    
    var body: some View {
        if !isNewCourse {
            CourseFormView(course: $selectedCourse, isNewCourse: false, onSave: {
                if let index = courseData.courses.firstIndex(where: { $0.id == selectedCourse.id }) {
                    courseData.courses[index] = selectedCourse
                    courseData.updateCourse(selectedCourse)
                }
                showingSheet = false
            }, onCancel: {
                showingSheet = false
            }, onDelete: {
                courseData.deleteCourse(selectedCourse)
                showingSheet = false
            }, courseData: courseData)
        } else {
            CourseFormView(course: $newCourse, isNewCourse: true, onSave: {
                courseData.addCourse(newCourse)
                showingSheet = false
            }, onCancel: {
                showingSheet = false
            }, courseData: courseData)
        }
    }
}
// 分离出来的午餐按钮视图
struct LunchButtonView: View {
    var body: some View {
        VStack {
            NavigationLink {
                LunchView()
            } label: {
                Text("午餐")
                    .font(.caption)
            }
        }
        .frame(width: 60, height: 30)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// 分离出来的晚餐按钮视图
struct DinnerButtonView: View {
    var body: some View {
        VStack {
            NavigationLink {
                dinnerView()
            } label: {
                Text("晚餐")
                    .font(.caption)
            }
        }
        .frame(width: 60, height: 30)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}