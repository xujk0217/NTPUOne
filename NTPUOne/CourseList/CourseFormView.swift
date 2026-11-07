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
    @EnvironmentObject var adFree: AdFreeService
    var isNewCourse: Bool
    var onSave: () -> Void
    var onCancel: () -> Void
    var onDelete: (() -> Void)?
    var timeslotAfterStart = false
    var contiguousEditCount = 1
    @ObservedObject var courseData: CourseData

    @State private var showingAlert = false
    @State private var showingAllowAlert = false
    @State private var pendingOverwrite: [Course] = []
    @State private var overwriteCourse: Course? = nil
    @State private var endTimeSlot: Course.TimeSlot = .morning1
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    

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
                        if contiguousEditCount > 1 {
                            Text("這是 \(contiguousEditCount) 節連堂，儲存或刪除會一起套用。")
                        } else {
                            Text("Course name is necessary")
                        }
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
                        Toggle(String(localized: "enable_course_notification"), isOn: $course.isNotification)
                    } header: {
                        Text(String(localized: "course_notification"))
                    } footer: {
                        Text(String(localized: "remember_enable_notification_in_settings"))
                    }
                    Section {
                        Picker("Day", selection: $course.day) {
                            ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                                Text(day).tag(day)
                            }
                        }
                        
                        if isNewCourse {
                            Picker(String(localized: "start_period"), selection: $course.timeSlot) {
                                ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                            .onChange(of: course.timeSlot) { newStart in
                                if let si = Course.TimeSlot.allCases.firstIndex(of: newStart),
                                   let ei = Course.TimeSlot.allCases.firstIndex(of: endTimeSlot),
                                   ei < si {
                                    endTimeSlot = newStart
                                }
                            }
                            
                            Picker(String(localized: "end_period"), selection: $endTimeSlot) {
                                ForEach(filteredTimeSlots, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                        } else {
                            Picker(String(localized: "period"), selection: $course.timeSlot) {
                                ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                        }
                    } header: {
                        Text("Time")
                    } footer: {
                        if isNewCourse {
                            Text(String(localized: "course_multiple_period_tip"))
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
                if !adFree.isAdFree{
                    // 廣告標記
                    Section {
                        BannerAdView()
                            .frame(height: 50)
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
                        showingAllowAlert = false
                        saveCoursesInTimeRange(confirmedReplacement: pendingOverwrite)
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
                            showingAlert = false
                            if courseData.saveCourses([course], replacing: [overwriteCourse], updating: !isNewCourse) {
                                onCancel()
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func saveCoursesInTimeRange(confirmedReplacement: [Course]? = nil) {
        let slots = Course.TimeSlot.allCases
        guard let start = slots.firstIndex(of: course.timeSlot),
              let end = slots.firstIndex(of: endTimeSlot), start <= end else { return }
        let selectedSlots = slots[start...end]
        let previous = confirmedReplacement ?? selectedSlots.compactMap { findDuplicateCourse(course.day, $0) }
        if !previous.isEmpty && confirmedReplacement == nil {
            pendingOverwrite = previous
            showingAllowAlert = true
            showingAlert = true
            return
        }
        let proposed = selectedSlots.enumerated().map { offset, slot in
            Course(id: UUID().uuidString, name: course.name, day: course.day, startTime: .none,
                   timeSlot: slot, location: course.location, teacher: course.teacher,
                   isNotification: offset == 0 && course.isNotification)
        }
        showingAllowAlert = false
        pendingOverwrite = []
        if courseData.saveCourses(proposed, replacing: previous) { onCancel() }
    }

    private func checkForDuplicateCourse() {
        guard contiguousEditCount == 1 else { onSave(); return }
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

// 從課程代碼新增
struct CourseGFormView: View {
    @Binding var course: Course
    @EnvironmentObject var adFree: AdFreeService
    var isNewCourse: Bool
    var onSave: () -> Void
    var onCancel: () -> Void
    var onDelete: (() -> Void)?
    var timeslotAfterStart = false
    @ObservedObject var courseData: CourseData
    
    @Binding var isShowCourseG: Bool

    @State private var showingAlert = false
    @State private var showingAllowAlert = false
    @State private var pendingOverwrite: [Course] = []
    @State private var overwriteCourse: Course? = nil
    @State var endTimeSlot: Course.TimeSlot
    
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    

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
                        Toggle(String(localized: "enable_course_notification"), isOn: $course.isNotification)
                    } header: {
                        Text(String(localized: "course_notification"))
                    } footer: {
                        Text(String(localized: "remember_enable_notification_in_settings"))
                    }
                    Section {
                        Picker("Day", selection: $course.day) {
                            ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                                Text(day).tag(day)
                            }
                        }
                        
                        if isNewCourse {
                            Picker(String(localized: "start_period"), selection: $course.timeSlot) {
                                ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                            .onChange(of: course.timeSlot) { newStart in
                                if let si = Course.TimeSlot.allCases.firstIndex(of: newStart),
                                   let ei = Course.TimeSlot.allCases.firstIndex(of: endTimeSlot),
                                   ei < si {
                                    endTimeSlot = newStart
                                }
                            }
                            
                            Picker(String(localized: "end_period"), selection: $endTimeSlot) {
                                ForEach(filteredTimeSlots, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                        } else {
                            Picker(String(localized: "period"), selection: $course.timeSlot) {
                                ForEach(Course.TimeSlot.allCases, id: \.self) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }
                        }
                    } header: {
                        Text("Time")
                    } footer: {
                        if isNewCourse {
                            Text(String(localized: "course_multiple_period_tip"))
                        }
                    }
//                    // 廣告標記
//                    Section {
//                        NativeAdBoxView(
//                            style: .compact(media: 120),
//                            height: $adHeight
//                        )
//                        .frame(height: adHeight)
//                        .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
//                        .listRowSeparator(.hidden)
//                        .listRowBackground(Color.white)
//                        .padding(.horizontal, 8)
//                    } header: {
//                        Text("廣告")
//                    }
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
                if !adFree.isAdFree{
                    // 廣告標記
                    Section {
                        BannerAdView()
                            .frame(height: 50)
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
                        showingAllowAlert = false
                        saveCoursesInTimeRange(confirmedReplacement: pendingOverwrite)
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
                            showingAlert = false
                            if courseData.saveCourses([course], replacing: [overwriteCourse], updating: !isNewCourse) {
                                onCancel()
                            }
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

    private func saveCoursesInTimeRange(confirmedReplacement: [Course]? = nil) {
        let slots = Course.TimeSlot.allCases
        guard let start = slots.firstIndex(of: course.timeSlot),
              let end = slots.firstIndex(of: endTimeSlot), start <= end else { return }
        let selectedSlots = slots[start...end]
        let previous = confirmedReplacement ?? selectedSlots.compactMap { findDuplicateCourse(course.day, $0) }
        if !previous.isEmpty && confirmedReplacement == nil {
            pendingOverwrite = previous
            showingAllowAlert = true
            showingAlert = true
            return
        }
        let proposed = selectedSlots.enumerated().map { offset, slot in
            Course(id: UUID().uuidString, name: course.name, day: course.day, startTime: .none,
                   timeSlot: slot, location: course.location, teacher: course.teacher,
                   isNotification: offset == 0 && course.isNotification)
        }
        showingAllowAlert = false
        pendingOverwrite = []
        if courseData.saveCourses(proposed, replacing: previous) { onCancel() }
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
