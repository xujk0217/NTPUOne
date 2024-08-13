//
//  CourseFormView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI

struct CourseFormView: View {
    @Binding var course: Course
    var isNewCourse: Bool
    var onSave: () -> Void
    var onCancel: () -> Void
    var onDelete: (() -> Void)?
    @ObservedObject var courseData: CourseData
        
    @State private var showingAlert = false
    @State private var overwriteCourse: Course? = nil
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Course Name", text: $course.name)
                TextField("Location", text: $course.location)
                TextField("Teacher", text: $course.teacher)
                
                Picker("Day", selection: $course.day) {
                    ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], id: \.self) { day in
                        Text(day).tag(day)
                    }
                }
                
                Picker("Time Slot", selection: $course.timeSlot) {
                    ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                        Text(slot.rawValue).tag(slot)
                    }
                }
                Picker("Start Time", selection: $course.startTime) {
                    Text(Course.TimeStart.none.rawValue).tag(Course.TimeStart.none)
                            .foregroundColor(.gray)
                    switch course.timeSlot {
                    case .morning1:
                        Text(Course.TimeStart.eight.rawValue).tag(Course.TimeStart.eight)
                    case .morning2:
                        Text(Course.TimeStart.nine.rawValue).tag(Course.TimeStart.nine)
                        Text(Course.TimeStart.ten.rawValue).tag(Course.TimeStart.ten)
                    case .afternoon1:
                        Text(Course.TimeStart.thirteen.rawValue).tag(Course.TimeStart.thirteen)
                    case .afternoon2:
                        Text(Course.TimeStart.fourteen.rawValue).tag(Course.TimeStart.fourteen)
                        Text(Course.TimeStart.fifteen.rawValue).tag(Course.TimeStart.fifteen)
                    case .afternoon3:
                        Text(Course.TimeStart.sixteen.rawValue).tag(Course.TimeStart.sixteen)
                        Text(Course.TimeStart.seventeen.rawValue).tag(Course.TimeStart.seventeen)
                    case .evening:
                        Text(Course.TimeStart.eightteen.rawValue).tag(Course.TimeStart.eightteen)
                    }
                }
                Text("name and start time is necessary")
            }
            .navigationTitle(isNewCourse ? "New Course" : "Edit Course")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if course.name != "", course.startTime != .none{
                            if isNewCourse{
                                checkForDuplicateCourse()
                            }else{
                                onSave()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                if !isNewCourse {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Delete") {
                            onDelete?()
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Duplicate Course"),
                message: Text("A course already exists on \(course.day) at \(course.timeSlot.rawValue). Do you want to overwrite it?"),
                primaryButton: .destructive(Text("Overwrite")) {
                    if let overwriteCourse = overwriteCourse {
                        // 删除现有课程
                        print("start ondeletefromid")
                        courseData.deleteCourseById(overwriteCourse.id)
                        // 保存新课程
                        print("save")
                        onSave()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    private func checkForDuplicateCourse() {
            if let existingCourse = findDuplicateCourse() {
                // 如果找到重复课程，显示提示框
                overwriteCourse = existingCourse
                showingAlert = true
            } else {
                // 没有重复课程，直接保存
                onSave()
            }
        }
        
        private func findDuplicateCourse() -> Course? {
            return courseData.courses.first { $0.day == course.day && $0.timeSlot == course.timeSlot }
        }
}
