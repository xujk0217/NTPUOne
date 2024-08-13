////
////  ScheduleView.swift
////  NTPUOne
////
////  Created by 許君愷 on 2024/8/12.
////
//
//import SwiftUI
//
//struct CourseView: View {
//    var course: Course
//    @ObservedObject var courseData: CourseData
//    @State private var showingSheet = false
//    var totalMinutesInDay: CGFloat = 840 // 8:00 AM 到 10:00 PM 的总分钟数
//
//    var body: some View {
//        GeometryReader { geometry in
//            let dayHeight = CGFloat(840)
//            let courseHeight = (CGFloat(120) / totalMinutesInDay) * dayHeight
//            let courseYPosition = (CGFloat(startTimeInMinutes(course.timeSlot)) / totalMinutesInDay) * dayHeight
//            Text(course.name)
//                .font(.caption2)
//                .foregroundStyle(Color.black)
//                .frame(width: 70, height: courseHeight)
//                .background(Color.blue.opacity(0.7))
//                .cornerRadius(8)
//                .position(x: geometry.size.width / 2, y: (courseYPosition + courseHeight / 2))
//        }
//    }
//
//    private func startTimeInMinutes(_ timeSlot: Course.TimeSlot) -> Int {
//        switch timeSlot {
//        case .morning1:
//            return 0 // 8:00 AM
//        case .morning2:
//            return 120 // 10:00 AM
//        case .afternoon1:
//            return 300 // 1:00 PM
//        case .afternoon2:
//            return 420 // 3:00 PM
//        case .evening:
//            return 600 // 6:00 PM
//        case .afternoon3:
//            return 00
//        }
//    }
//}
//
//struct WeekScheduleView: View {
//    @ObservedObject var courseData: CourseData
//    @State private var selectedCourse = Course(id: "", name: "", day: "Monday", startTime: .eight, timeSlot: .morning1, location: "", teacher: "")
//    @State private var isNewCourse = true
//    @State private var showingSheet = false
//    @State private var newCourse = Course(id: "", name: "", day: "Monday", startTime: .eight, timeSlot: .morning1, location: "", teacher: "")
//
//    var body: some View {
//        VStack{
//            HStack {
//                // 每天的课程安排
//                ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"], id: \.self) { day in
//                    VStack {
//                        // 顶部星期的标签
//                        Text(day.prefix(3))
//                            .font(.headline)
//                            .frame(width: 77, height: 50)
//                        ZStack {
//                            ForEach(courseData.courses.filter { $0.day == day }) { course in
//                                CourseView(course: course, courseData: courseData)
//                                    .frame(width: 70)
//                            }
//                        }.frame(height: 840)
//                    }
//                }
//            }
//            Button(action: {
//                newCourse = Course(id: "", name: "", day: "Monday", timeSlot: .morning1, location: "", teacher: "")
//                showingSheet = true
//                isNewCourse = true
//            }) {
//                Text("+")
//                    .padding(5)
//                    .frame(width: 60, height: 60)
//                    .background(Color.green)
//                    .foregroundColor(.white)
//                    .cornerRadius(8)
//            }.padding()
//        }
//        .background(Color.gray.opacity(0.1))
//        .cornerRadius(8)
//        .frame(width: (UIScreen.main.bounds.width)) // 固定高度100
//        .sheet(isPresented: $showingSheet) {
//            if !isNewCourse {
//                CourseFormView(course: $selectedCourse, isNewCourse: false, onSave: {
//                    if let index = courseData.courses.firstIndex(where: { $0.id == selectedCourse.id }) {
//                        courseData.courses[index] = selectedCourse
//                        courseData.updateCourse(selectedCourse)
//                    }
//                    showingSheet = false
//                }, onCancel: {
//                    showingSheet = false
//                }, onDelete: {
//                    courseData.deleteCourse(selectedCourse)
//                    showingSheet = false
//                }, courseData: courseData)
//            } else {
//                CourseFormView(course: $newCourse, isNewCourse: true, onSave: {
//                    courseData.addCourse(newCourse)
//                    showingSheet = false
//                }, onCancel: {
//                    showingSheet = false
//                }, courseData: courseData)
//            }
//        }
//    }
//}
