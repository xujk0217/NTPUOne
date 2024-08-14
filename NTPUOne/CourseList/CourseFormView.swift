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
    var timeslotAfterStart = false
    @ObservedObject var courseData: CourseData
        
    @State private var showingAlert = false
    @State private var showingAllowAlert = false
    @State private var allowOverwrite = false
    @State private var overwriteCourse: Course? = nil
    @State private var endTimeSlot: Course.TimeSlot = .morning1
    
    var body: some View {
        let filteredTimeSlots = getFilteredTimeSlots()
        NavigationStack {
            Form {
                Section{
                    TextField("Course Name", text: $course.name)
                } header: {
                    Text("Course Name")
                } footer: {
                    Text("Course name is necessary")
                }
                Section{
                    TextField("Location", text: $course.location)
                } header: {
                    Text("Location")
                }
                Section{
                    TextField("Teacher", text: $course.teacher)
                }header: {
                    Text("Teacher")
                }
                
                Section{
                    Picker("Day", selection: $course.day) {
                        ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], id: \.self) { day in
                            Text(day).tag(day)
                        }
                    }
                    
                    if isNewCourse {
                        Picker("start Time Slot", selection: $course.timeSlot) {
                            ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                Text(slot.rawValue).tag(slot)
                            }
                        }
                        
                        Picker("End Time Slot", selection: $endTimeSlot) {
                            ForEach(filteredTimeSlots, id: \.self) { slot in
                                Text(slot.rawValue).tag(slot)
                            }
                        }
                    }else{
                        Picker("Time Slot", selection: $course.timeSlot) {
                            ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                Text(slot.rawValue).tag(slot)
                            }
                        }
                    }
                }header: {
                    Text("Time")
                }footer: {
                    if isNewCourse {
                        Text("如課程節數大於一，建議資料填寫完整，否則創建後需一節一節更改")
                    }
                }
                
//                Picker("Start Time", selection: $course.startTime) {
//                    Text(Course.TimeStart.none.rawValue).tag(Course.TimeStart.none)
//                            .foregroundColor(.gray)
//                    switch course.timeSlot {
//                    case .morning1:
//                        Text(Course.TimeStart.eight.rawValue).tag(Course.TimeStart.eight)
//                    case .morning2:
//                        Text(Course.TimeStart.nine.rawValue).tag(Course.TimeStart.nine)
//                    case .morning3:
//                        Text(Course.TimeStart.ten.rawValue).tag(Course.TimeStart.ten)
//                    case .morning4:
//                        Text(Course.TimeStart.eleven.rawValue).tag(Course.TimeStart.ten)
//                    case .afternoon1:
//                        Text(Course.TimeStart.thirteen.rawValue).tag(Course.TimeStart.thirteen)
//                    case .afternoon2:
//                        Text(Course.TimeStart.fourteen.rawValue).tag(Course.TimeStart.fourteen)
//                    case .afternoon3:
//                        Text(Course.TimeStart.fifteen.rawValue).tag(Course.TimeStart.fifteen)
//                    case .afternoon4:
//                        Text(Course.TimeStart.sixteen.rawValue).tag(Course.TimeStart.sixteen)
//                    case .afternoon5:
//                        Text(Course.TimeStart.seventeen.rawValue).tag(Course.TimeStart.seventeen)
//                    case .evening:
//                        Text(Course.TimeStart.eightteen.rawValue).tag(Course.TimeStart.eightteen)
//                    }
//                }
            }
            .navigationTitle(isNewCourse ? "New Course" : "Edit Course")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if course.name != ""{
                            if isNewCourse{
                                saveCoursesInTimeRange()
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
        .alert(isPresented: $showingAllowAlert) {
            Alert(
                title: Text("Duplicate Course"),
                message: Text("A course already exists on \(course.day) at \(course.timeSlot.rawValue) to \(endTimeSlot.rawValue). Do you want to overwrite it?"),
                primaryButton: .destructive(Text("Overwrite")) {
                    allowOverwrite = true
                    performSaveCoursesInTimeRange()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            endTimeSlot = course.timeSlot
        }
    }
    
    private func saveCoursesInTimeRange() {
        guard let startIndex = Course.TimeSlot.allCases.firstIndex(of: course.timeSlot),
                let endIndex = Course.TimeSlot.allCases.firstIndex(of: endTimeSlot) else {
            return
        }

        let timeSlotsToCheck = Array(Course.TimeSlot.allCases[startIndex...endIndex])
        
        for (index, slot) in timeSlotsToCheck.enumerated() {
            var newCourse = course
            newCourse.timeSlot = slot
            if isTimeSlotOccupied(day: course.day, timeSlot: slot) {
                // 有重复课程，设置覆盖课程提示
                if allowOverwrite == false{
                    showingAllowAlert = true
                    return
                }
            } else {
                // 没有重复课程，直接保存
                courseData.addCourse(newCourse)
            }
        }
        showingAllowAlert = false
        allowOverwrite = false
        onCancel()
    }
    
    private func performSaveCoursesInTimeRange() {
            // Perform saving operations after overwrite is confirmed
            guard let startIndex = Course.TimeSlot.allCases.firstIndex(of: course.timeSlot),
                  let endIndex = Course.TimeSlot.allCases.firstIndex(of: endTimeSlot) else {
                return
            }

            let timeSlotsToCheck = Array(Course.TimeSlot.allCases[startIndex...endIndex])
            
            for (index, slot) in timeSlotsToCheck.enumerated() {
                var newCourse = course
                newCourse.timeSlot = slot
                if let overwriteCourse = findDuplicateCourse(course.day, slot) {
                    courseData.deleteCourse(overwriteCourse)
                }
                courseData.addCourse(newCourse)
            }
            // Reset state
            showingAllowAlert = false
            allowOverwrite = false
            onCancel()
        }
    
    private func isTimeSlotOccupied(day: String, timeSlot: Course.TimeSlot) -> Bool {
            return courseData.courses.contains { $0.day == day && $0.timeSlot == timeSlot }
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
    private func findDuplicateCourse(_ courseDay: String,_ courseTimeslot: Course.TimeSlot) -> Course? {
        return courseData.courses.first { $0.day == courseDay && $0.timeSlot == courseTimeslot }
    }
    
    private func getFilteredTimeSlots() -> [Course.TimeSlot] {
        // 仅返回在当前选择的 timeSlot 之后的时间段
        guard let startIndex = Course.TimeSlot.allCases.firstIndex(of: course.timeSlot) else {
            return Course.TimeSlot.allCases
        }
        return Array(Course.TimeSlot.allCases[startIndex...])
    }
}
