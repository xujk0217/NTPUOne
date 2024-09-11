//
//  CourseFormView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI
import CoreData

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
            VStack{
                Form {
                    // Form Fields
                    Section {
                        TextField("Course Name", text: $course.name)
                    } header: {
                        Text("Course Name")
                    } footer: {
                        Text("Course name is necessary")
                    }
                    Section {
                        TextField("Location", text: $course.location)
                    } header: {
                        Text("Location")
                    }
                    Section {
                        TextField("Teacher", text: $course.teacher)
                    } header: {
                        Text("Teacher")
                    }
                    Section{
                        Toggle("開啟上課通知", isOn: $course.isNotification)
                    } header: {
                        Text("上課通知")
                    } footer: {
                        Text("記得到設定開啟通知")
                    }
                    Section {
                        Picker("Day", selection: $course.day) {
                            ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                                Text(day).tag(day)
                            }
                        }
                        
                        if isNewCourse {
                            Picker("開始節數", selection: $course.timeSlot) {
                                ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                            
                            Picker("結束節數", selection: $endTimeSlot) {
                                ForEach(filteredTimeSlots, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                        } else {
                            Picker("節數", selection: $course.timeSlot) {
                                ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                        }
                    } header: {
                        Text("Time")
                    } footer: {
                        if isNewCourse {
                            Text("如課程節數大於一，建議資料填寫完整，否則創建後需一節一節更改")
                        }
                    }
                }
                .navigationTitle(isNewCourse ? "New Course" : "Edit Course")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if course.name != "" {
                                if isNewCourse {
                                    saveCoursesInTimeRange()
                                } else {
                                    checkForDuplicateCourse()
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onCancel()
                        }
                    }
                }
                if !isNewCourse{
                    Button {
                        onDelete?()
                    } label: {
                        Text("Delete this Course")
                            .foregroundStyle(Color.red)
                            .padding()
                    }
                }
            }
        }
        .onAppear {
            endTimeSlot = course.timeSlot
        }
        .alert(isPresented: $showingAlert) {
            switch showingAllowAlert {
            case true:
                Alert(
                    title: Text("Duplicate Course"),
                    message: Text("A course already exists on \(course.day) at \(course.timeSlot.rawValue) to \(endTimeSlot.rawValue). Do you want to overwrite it?"),
                    primaryButton: .destructive(Text("Overwrite")) {
                        allowOverwrite = true
                        showingAllowAlert = false
                        saveCoursesInTimeRange()
//                        performSaveCoursesInTimeRange()
                    },
                    secondaryButton: .cancel() {
                        showingAllowAlert = false
                    }
                )
            case false:
                Alert(
                    title: Text("Duplicate Course"),
                    message: Text("A course already exists on \(course.day) at \(course.timeSlot.rawValue). Do you want to overwrite it?"),
                    primaryButton: .destructive(Text("Overwrite")) {
                        if let overwriteCourse = overwriteCourse {
                            courseData.deleteCourse(overwriteCourse)
                            showingAlert = false
                            onSave()
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func saveCoursesInTimeRange() {
        guard let startIndex = Course.TimeSlot.allCases.firstIndex(of: course.timeSlot),
              let endIndex = Course.TimeSlot.allCases.firstIndex(of: endTimeSlot) else {
            return
        }

        let timeSlotsToCheck = Array(Course.TimeSlot.allCases[startIndex...endIndex])
        var isRepeat = false
        
        for slot in timeSlotsToCheck {
            if isTimeSlotOccupied(day: course.day, timeSlot: slot) {
                isRepeat = true
                if !allowOverwrite {
                    showingAllowAlert = true
                    showingAlert = true
                    return
                }
            }
        }
        
        if isRepeat {
            if allowOverwrite{
                for slot in timeSlotsToCheck {
                    guard let context = courseData.viewContext else {
                        print("viewContext is nil")
                        return
                    }
                    if let overwriteCourse = findDuplicateCourse(course.day, slot) {
                        courseData.deleteCourse(overwriteCourse)
                    }
                    // 使用 addCourse 方法添加课程
                    let newCourse = Course(id: UUID().uuidString,
                                            name: course.name ?? "",
                                            day: course.day ?? "",
                                            startTime: .none,
                                            timeSlot: slot,
                                            location: course.location ?? "",
                                           teacher: course.teacher ?? "",
                                           isNotification: course.isNotification)
                    
                    courseData.addCourse(newCourse)
                }
            } else{
                showingAllowAlert = false
                allowOverwrite = false
                isRepeat = false
                onCancel()
            }
        }else{
            for slot in timeSlotsToCheck {
                guard let context = courseData.viewContext else {
                    print("viewContext is nil")
                    return
                }
                
                // 使用 addCourse 方法添加课程
                let newCourse = Course(id: UUID().uuidString,
                                        name: course.name ?? "",
                                        day: course.day ?? "",
                                        startTime: .none,
                                        timeSlot: slot,
                                        location: course.location ?? "",
                                       teacher: course.teacher ?? "", 
                                       isNotification: course.isNotification)
                
                courseData.addCourse(newCourse)
            }
        }
        
        do {
            try courseData.viewContext?.save()
        } catch {
            print("Failed to save courses: \(error)")
        }
        
        showingAllowAlert = false
        allowOverwrite = false
        isRepeat = false
        onCancel()
    }

    private func isTimeSlotOccupied(day: String, timeSlot: Course.TimeSlot) -> Bool {
        return courseData.courses.contains { $0.day == day && $0.timeSlot == timeSlot }
    }

    private func checkForDuplicateCourse() {
        if let existingCourse = findDuplicateCourse() {
            if existingCourse.id != course.id {
                overwriteCourse = existingCourse
                showingAlert = true
            } else {
                onSave()
            }
        } else {
            onSave()
        }
    }

    private func findDuplicateCourse() -> Course? {
        return courseData.courses.first { $0.day == course.day && $0.timeSlot == course.timeSlot }
    }

    private func findDuplicateCourse(_ courseDay: String, _ courseTimeslot: Course.TimeSlot) -> Course? {
        return courseData.courses.first { $0.day == courseDay && $0.timeSlot == courseTimeslot }
    }

    private func getFilteredTimeSlots() -> [Course.TimeSlot] {
        guard let startIndex = Course.TimeSlot.allCases.firstIndex(of: course.timeSlot) else {
            return Course.TimeSlot.allCases
        }
        return Array(Course.TimeSlot.allCases[startIndex...])
    }
}

struct CourseGFormView: View {
    @Binding var course: Course
    var isNewCourse: Bool
    var onSave: () -> Void
    var onCancel: () -> Void
    var onDelete: (() -> Void)?
    var timeslotAfterStart = false
    @ObservedObject var courseData: CourseData
    
    @Binding var isShowCourseG: Bool

    @State private var showingAlert = false
    @State private var showingAllowAlert = false
    @State private var allowOverwrite = false
    @State private var overwriteCourse: Course? = nil
    @State var endTimeSlot: Course.TimeSlot

    var body: some View {
        let filteredTimeSlots = getFilteredTimeSlots()
        NavigationStack {
            VStack{
                Form {
                    // Form Fields
                    Section {
                        TextField("Course Name", text: $course.name)
                    } header: {
                        Text("Course Name")
                    } footer: {
                        Text("Course name is necessary")
                    }
                    Section {
                        TextField("Location", text: $course.location)
                    } header: {
                        Text("Location")
                    }
                    Section {
                        TextField("Teacher", text: $course.teacher)
                    } header: {
                        Text("Teacher")
                    }
                    Section{
                        Toggle("開啟上課通知", isOn: $course.isNotification)
                    } header: {
                        Text("上課通知")
                    } footer: {
                        Text("記得到設定開啟通知")
                    }
                    Section {
                        Picker("Day", selection: $course.day) {
                            ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                                Text(day).tag(day)
                            }
                        }
                        
                        if isNewCourse {
                            Picker("開始節數", selection: $course.timeSlot) {
                                ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                            
                            Picker("結束節數", selection: $endTimeSlot) {
                                ForEach(filteredTimeSlots, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                        } else {
                            Picker("節數", selection: $course.timeSlot) {
                                ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                        }
                    } header: {
                        Text("Time")
                    } footer: {
                        if isNewCourse {
                            Text("如課程節數大於一，建議資料填寫完整，否則創建後需一節一節更改")
                        }
                    }
                }
                .navigationTitle(isNewCourse ? "New Course" : "Edit Course")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if course.name != "" {
                                if isNewCourse {
                                    saveCoursesInTimeRange()
                                } else {
                                    checkForDuplicateCourse()
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onCancel()
                        }
                    }
                }
                if !isNewCourse{
                    Button {
                        onDelete?()
                    } label: {
                        Text("Delete this Course")
                            .foregroundStyle(Color.red)
                            .padding()
                    }
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            switch showingAllowAlert {
            case true:
                Alert(
                    title: Text("Duplicate Course"),
                    message: Text("A course already exists on \(course.day) at \(course.timeSlot.rawValue) to \(endTimeSlot.rawValue). Do you want to overwrite it?"),
                    primaryButton: .destructive(Text("Overwrite")) {
                        allowOverwrite = true
                        showingAllowAlert = false
                        saveCoursesInTimeRange()
//                        performSaveCoursesInTimeRange()
                    },
                    secondaryButton: .cancel() {
                        showingAllowAlert = false
                    }
                )
            case false:
                Alert(
                    title: Text("Duplicate Course"),
                    message: Text("A course already exists on \(course.day) at \(course.timeSlot.rawValue). Do you want to overwrite it?"),
                    primaryButton: .destructive(Text("Overwrite")) {
                        if let overwriteCourse = overwriteCourse {
                            courseData.deleteCourse(overwriteCourse)
                            showingAlert = false
                            onSave()
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onDisappear{
            isShowCourseG = false
        }
    }

    private func saveCoursesInTimeRange() {
        guard let startIndex = Course.TimeSlot.allCases.firstIndex(of: course.timeSlot),
              let endIndex = Course.TimeSlot.allCases.firstIndex(of: endTimeSlot) else {
            return
        }

        let timeSlotsToCheck = Array(Course.TimeSlot.allCases[startIndex...endIndex])
        var isRepeat = false
        
        for slot in timeSlotsToCheck {
            if isTimeSlotOccupied(day: course.day, timeSlot: slot) {
                isRepeat = true
                if !allowOverwrite {
                    showingAllowAlert = true
                    showingAlert = true
                    return
                }
            }
        }
        
        if isRepeat {
            if allowOverwrite{
                for slot in timeSlotsToCheck {
                    guard let context = courseData.viewContext else {
                        print("viewContext is nil")
                        return
                    }
                    if let overwriteCourse = findDuplicateCourse(course.day, slot) {
                        courseData.deleteCourse(overwriteCourse)
                    }
                    // 使用 addCourse 方法添加课程
                    let newCourse = Course(id: UUID().uuidString,
                                            name: course.name ?? "",
                                            day: course.day ?? "",
                                            startTime: .none,
                                            timeSlot: slot,
                                            location: course.location ?? "",
                                           teacher: course.teacher ?? "",
                                           isNotification: course.isNotification)
                    
                    courseData.addCourse(newCourse)
                }
            } else{
                showingAllowAlert = false
                allowOverwrite = false
                isRepeat = false
                onCancel()
            }
        }else{
            for slot in timeSlotsToCheck {
                guard let context = courseData.viewContext else {
                    print("viewContext is nil")
                    return
                }
                
                // 使用 addCourse 方法添加课程
                let newCourse = Course(id: UUID().uuidString,
                                        name: course.name ?? "",
                                        day: course.day ?? "",
                                        startTime: .none,
                                        timeSlot: slot,
                                        location: course.location ?? "",
                                       teacher: course.teacher ?? "",
                                       isNotification: course.isNotification)
                
                courseData.addCourse(newCourse)
            }
        }
        
        do {
            try courseData.viewContext?.save()
        } catch {
            print("Failed to save courses: \(error)")
        }
        
        showingAllowAlert = false
        allowOverwrite = false
        isRepeat = false
        onCancel()
    }

    private func isTimeSlotOccupied(day: String, timeSlot: Course.TimeSlot) -> Bool {
        return courseData.courses.contains { $0.day == day && $0.timeSlot == timeSlot }
    }

    private func checkForDuplicateCourse() {
        if let existingCourse = findDuplicateCourse() {
            if existingCourse.id != course.id {
                overwriteCourse = existingCourse
                showingAlert = true
            } else {
                onSave()
            }
        } else {
            onSave()
        }
    }

    private func findDuplicateCourse() -> Course? {
        return courseData.courses.first { $0.day == course.day && $0.timeSlot == course.timeSlot }
    }

    private func findDuplicateCourse(_ courseDay: String, _ courseTimeslot: Course.TimeSlot) -> Course? {
        return courseData.courses.first { $0.day == courseDay && $0.timeSlot == courseTimeslot }
    }

    private func getFilteredTimeSlots() -> [Course.TimeSlot] {
        guard let startIndex = Course.TimeSlot.allCases.firstIndex(of: course.timeSlot) else {
            return Course.TimeSlot.allCases
        }
        return Array(Course.TimeSlot.allCases[startIndex...])
    }
}
