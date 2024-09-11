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
    @State private var selectedCourse = Course(id: "", name: "", day: "Friday", startTime: .none, timeSlot: .morning1, location: "", teacher: "", isNotification: true)
    @State private var newCourse = Course(id: "", name: "", day: "Monday", startTime: .none, timeSlot: .morning1, location: "", teacher: "", isNotification: true)
    @State private var isNewCourse = false

    var body: some View {
        VStack{
            LazyVGrid(columns: columns) {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri"], id: \.self) { day in
                    Text(day)
                }
                ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], id: \.self) { day in
                    MorningCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
                }
            }
            LunchButtonView()
            LazyVGrid(columns: columns) {
                ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], id: \.self) { day in
                    AfternoonCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
                }
            }
            DinnerButtonView()
            LazyVGrid(columns: columns) {
                ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], id: \.self) { day in
                    EveningCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
                }
            }
        }
        .padding()
        //        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showingSheet) {
            CourseFormSheet(isNewCourse: $isNewCourse, selectedCourse: $selectedCourse, newCourse: $newCourse, courseData: courseData, showingSheet: $showingSheet)
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(selectedCourse.name),
                message: Text("教授：\(selectedCourse.teacher.isEmpty ? "..." : selectedCourse.teacher) 教授\n時間：\(selectedCourse.day), \(selectedCourse.startTime.rawValue)\n地點：\(selectedCourse.location.isEmpty ? "..." : selectedCourse.location)\n通知：\(selectedCourse.isNotification ? "開啟" : "關閉")"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    var columns: [GridItem] {
        Array(repeating: .init(.flexible()), count: 5)
    }
}

struct CourseGridSatView: View {
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @State private var showingAlert = false
    @State private var showingSheet = false
    @State private var selectedCourse = Course(id: "", name: "", day: "Friday", startTime: .none, timeSlot: .morning1, location: "", teacher: "", isNotification: true)
    @State private var newCourse = Course(id: "", name: "", day: "Monday", startTime: .none, timeSlot: .morning1, location: "", teacher: "", isNotification: true)
    @State private var isNewCourse = false

    var body: some View {
        VStack{
            LazyVGrid(columns: columns) {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                }
                ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                    MorningCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
                }
            }
            LunchButtonView()
            LazyVGrid(columns: columns) {
                ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                    AfternoonCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
                }
            }
            DinnerButtonView()
            LazyVGrid(columns: columns) {
                ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                    EveningCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
                }
            }
        }
        .padding()
        //        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showingSheet) {
            CourseFormSheet(isNewCourse: $isNewCourse, selectedCourse: $selectedCourse, newCourse: $newCourse, courseData: courseData, showingSheet: $showingSheet)
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(selectedCourse.name),
                message: Text("教授：\(selectedCourse.teacher.isEmpty ? "..." : selectedCourse.teacher) 教授\n時間：\(selectedCourse.day), \(selectedCourse.startTime.rawValue)\n地點：\(selectedCourse.location.isEmpty ? "..." : selectedCourse.location)\n通知：\(selectedCourse.isNotification ? "開啟" : "關閉")"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    var columns: [GridItem] {
        Array(repeating: .init(.flexible()), count: 6)
    }
}

struct MorningCourseColumnView: View {
    var day: String
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @Binding var showingSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var selectedCourse: Course
    @Binding var isNewCourse: Bool
    @Binding var newCourse: Course

    var body: some View {
        VStack{
            ForEach(Course.TimeSlot.allCases.prefix(4), id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
                
            }
        }
    }
}

struct AfternoonCourseColumnView: View {
    var day: String
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @Binding var showingSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var selectedCourse: Course
    @Binding var isNewCourse: Bool
    @Binding var newCourse: Course

    var body: some View {
        VStack{
            ForEach(Course.TimeSlot.allCases[4..<9], id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
            }
        }
    }
}

struct EveningCourseColumnView: View {
    var day: String
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @Binding var showingSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var selectedCourse: Course
    @Binding var isNewCourse: Bool
    @Binding var newCourse: Course

    var body: some View {
        VStack{
            ForEach(Course.TimeSlot.allCases[9..<13], id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse)
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
                                .foregroundColor(.black)
                        }
                    }
                }
            }
        }
        .frame(height: 100)
        .frame(minWidth: 35, maxWidth: 80)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    func addNewCourse() {
        newCourse = Course(id: UUID().uuidString, name: "", day: day, startTime: .none, timeSlot: slot, location: "", teacher: "", isNotification: true)
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
                Text("午餐時間")
                    .font(.caption)
                    .frame(minWidth: 300, maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

// 分离出来的晚餐按钮视图
struct DinnerButtonView: View {
    var body: some View {
        VStack {
            NavigationLink {
                dinnerView()
            } label: {
                Text("晚餐時間")
                    .font(.caption)
                    .frame(minWidth: 300, maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}
