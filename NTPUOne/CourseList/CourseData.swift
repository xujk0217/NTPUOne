//
//  CourseData.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import Foundation
import CoreData
import UserNotifications
import SwiftUI

struct Course: Identifiable {
    var id: String
    var name: String
    var day: String
    var startTime: TimeStart
    var timeSlot: TimeSlot
    var location: String
    var teacher: String
    var isNotification: Bool

    enum TimeStart: String, CaseIterable, Identifiable {
        case none = "none"
        case eight = "8:10"
        case nine = "9:10"
        case ten = "10:10"
        case eleven = "11:10"
        case thirteen = "13:10"
        case fourteen = "14:10"
        case fifteen = "15:10"
        case sixteen = "16:10"
        case seventeen = "17:10"
        case eighteen = "18:30"

        var id: String { self.rawValue }
    }

    enum TimeSlot: String, CaseIterable, Identifiable {
        case morning1 = "Morning 1"
        case morning2 = "Morning 2"
        case morning3 = "Morning 3"
        case morning4 = "Morning 4"
        case afternoon1 = "Afternoon 1"
        case afternoon2 = "Afternoon 2"
        case afternoon3 = "Afternoon 3"
        case afternoon4 = "Afternoon 4"
        case afternoon5 = "Afternoon 5"
        case evening = "Evening"

        var id: String { self.rawValue }
    }
}

class CourseData: ObservableObject {
    @Published var courses: [Course] = []
    var viewContext: NSManagedObjectContext?

    init(context: NSManagedObjectContext? = nil) {
        self.viewContext = context
        if let viewContext = context {
            print("Context initialized successfully")
        } else {
            print("Context is nil during CourseData initialization")
        }
        loadCoursesFromCoreData()
    }

    func loadCoursesFromCoreData() {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot load courses from Core Data.")
            return
        }
        
        let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()

        do {
            let courseEntities = try viewContext.fetch(fetchRequest)
            print("Success: Fetched \(courseEntities.count) courses from Core Data.")
            self.courses = courseEntities.map { courseEntity in
                Course(
                    id: courseEntity.id ?? UUID().uuidString,
                    name: courseEntity.name ?? "",
                    day: courseEntity.day ?? "",
                    startTime: Course.TimeStart(rawValue: courseEntity.startTime ?? Course.TimeStart.none.rawValue) ?? .none,
                    timeSlot: Course.TimeSlot(rawValue: courseEntity.timeSlot ?? Course.TimeSlot.morning1.rawValue) ?? .morning1,
                    location: courseEntity.location ?? "",
                    teacher: courseEntity.teacher ?? "", 
                    isNotification: courseEntity.isNotification
                )
            }
            scheduleNotificationsForAllCourses()
        } catch {
            print("Error: Failed to fetch courses from Core Data - \(error.localizedDescription)")
        }
        checkNotificationAuthorizationStatus()
//        scheduleDailyReminderNotification() //測試
        listAllPendingNotifications() //列通知
//        scheduleNotificationTest() //測試
    }
    
    func scheduleNotificationsForAllCourses() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for course in courses {
            if course.isNotification {
                scheduleNotification(for: course)
            } else {
                cancelNotification(for: course)
            }
        }
    }

    func addCourse(_ course: Course) {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot add course \(course.name).")
            return
        }
        
        let newCourse = CourseEntity(context: viewContext)
        newCourse.id = course.id
        newCourse.name = course.name
        newCourse.day = course.day
        var startTime = Course.TimeStart.none
        switch course.timeSlot {
        case .morning1:
            startTime = Course.TimeStart.eight
        case .morning2:
            startTime = Course.TimeStart.nine
        case .morning3:
            startTime = Course.TimeStart.ten
        case .morning4:
            startTime = Course.TimeStart.eleven
        case .afternoon1:
            startTime = Course.TimeStart.thirteen
        case .afternoon2:
            startTime = Course.TimeStart.fourteen
        case .afternoon3:
            startTime = Course.TimeStart.fifteen
        case .afternoon4:
            startTime = Course.TimeStart.sixteen
        case .afternoon5:
            startTime = Course.TimeStart.seventeen
        case .evening:
            startTime = Course.TimeStart.eighteen
        }
        newCourse.startTime = startTime.rawValue
        newCourse.timeSlot = course.timeSlot.rawValue
        newCourse.location = course.location
        newCourse.teacher = course.teacher
        newCourse.isNotification = course.isNotification
        
        var NCourse = course
        NCourse.startTime = startTime
        
        if NCourse.isNotification {
            scheduleNotification(for: NCourse)
        }
        
        saveContext()
        courses.append(NCourse)
        print("Success: Added new course with id \(course.id) and name \(course.name) and startTime \(startTime.rawValue ?? "ooo").")
        listAllPendingNotifications()
    }

    func deleteCourse(_ course: Course) {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot delete course with id \(course.id).")
            return
        }
        cancelNotification(for: course)
        
        let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", course.id)

        do {
            let courseEntities = try viewContext.fetch(fetchRequest)
            print("Info: Found \(courseEntities.count) course(s) matching id \(course.id) for deletion.")
            for courseEntity in courseEntities {
                viewContext.delete(courseEntity)
            }
            saveContext()
            if let index = courses.firstIndex(where: { $0.id == course.id }) {
                courses.remove(at: index)
                print("Success: Deleted course with id \(course.id).")
            }
        } catch {
            print("Error: Failed to delete course with id \(course.id) - \(error.localizedDescription)")
        }
    }
    
    func deleteCourseById(_ courseId: String) {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot delete course with id \(courseId).")
            return
        }
        cancelNotification(withId: courseId)
        
        let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", courseId)

        do {
            if let courseEntity = try viewContext.fetch(fetchRequest).first {
                viewContext.delete(courseEntity)
                saveContext()
                if let index = courses.firstIndex(where: { $0.id == courseId }) {
                    courses.remove(at: index)
                    print("Success: Deleted course with id \(courseId).")
                }
            } else {
                print("Info: No course found with id \(courseId) to delete.")
            }
        } catch {
            print("Error: Failed to delete course by id \(courseId) - \(error.localizedDescription)")
        }
    }

    func updateCourse(_ course: Course) {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot update course with id \(course.id).")
            return
        }
        
        if course.isNotification {
            scheduleNotification(for: course)
        } else {
            cancelNotification(for: course)
        }
        
        let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", course.id)

        do {
            let courseEntities = try viewContext.fetch(fetchRequest)
            if let courseEntity = courseEntities.first {
                courseEntity.name = course.name
                courseEntity.day = course.day
                courseEntity.startTime = course.startTime.rawValue
                courseEntity.timeSlot = course.timeSlot.rawValue
                courseEntity.location = course.location
                courseEntity.teacher = course.teacher
                courseEntity.isNotification = course.isNotification

                saveContext()

                if let index = courses.firstIndex(where: { $0.id == course.id }) {
                    courses[index] = course
                    print("Success: Updated course with id \(course.id) and name \(course.name).")
                }
            } else {
                print("Info: No course found with id \(course.id) to update.")
            }
        } catch {
            print("Error: Failed to update course with id \(course.id) - \(error.localizedDescription)")
        }
    }

    private func saveContext() {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot save context.")
            return
        }
        
        do {
            try viewContext.save()
            print("Success: Context saved successfully.")
        } catch {
            print("Error: Failed to save context - \(error.localizedDescription)")
        }
    }
}



extension CourseData {
    // 调度通知的方法
    func scheduleNotification(for course: Course) {
        let content = UNMutableNotificationContent()
        content.title = course.name
        content.body = "Your class is about to start!"
        content.sound = .default
        
        // 创建触发器
        let triggerDate = calculateTriggerDate(for: course) // 根据课程时间计算触发时间
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        
        // 创建通知请求
        let request = UNNotificationRequest(identifier: course.id, content: content, trigger: trigger)
        
        // 添加通知请求
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for course \(course.name).")
            }
        }
    }
    
    
    // 取消通知的方法
    func cancelNotification(for course: Course) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [course.id])
        print("Notification cancelled for course \(course.name).")
    }
    
    func cancelNotification(withId courseId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [courseId])
        print("Notification cancelled for course with id \(courseId).")
    }
    
    // 计算触发时间的方法
    private func calculateTriggerDate(for course: Course) -> DateComponents {
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday(from: course.day) // 曜日
        dateComponents.hour = hour(from: course.startTime) // 小时
        dateComponents.minute = 0 // 分钟
        return dateComponents
    }
    
    // 将课程的 day 转换为 DateComponents 中的 weekday
    func weekday(from day: String) -> Int {
        // 示例实现，需要根据你的需求来实现具体逻辑
        switch day.lowercased() {
        case "monday": return 2
        case "tuesday": return 3
        case "wednesday": return 4
        case "thursday": return 5
        case "friday": return 6
        default: return 1
        }
    }
    
    // 将课程的 startTime 转换为小时
    func hour(from startTime: Course.TimeStart) -> Int {
        // 示例实现，需要根据你的时间格式来实现具体逻辑
        switch startTime {
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .eleven: return 11
        case .thirteen: return 13
        case .fourteen: return 14
        case .fifteen: return 15
        case .sixteen: return 16
        case .seventeen: return 17
        case .eighteen: return 18
        case .none: return 8
        }
    }
    
    func checkNotificationAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                print("Notification permission is granted.")
            case .denied:
                print("Notification permission is denied.")
            case .notDetermined:
                print("Notification permission has not been requested yet.")
            case .provisional:
                print("Notification permission is provisional.")
            @unknown default:
                print("Unknown notification authorization status.")
            }
        }
    }
    func listAllPendingNotifications() {
        let center = UNUserNotificationCenter.current()
        
        center.getPendingNotificationRequests { requests in
            if requests.isEmpty {
                print("No pending notifications.")
            } else {
                print("Pending notifications:")
                for request in requests {
                    print("Identifier: \(request.identifier)")
                    print("Title: \(request.content.title)")
                    print("Body: \(request.content.body)")
                    print("Sound: \(String(describing: request.content.sound))")
                    print("Badge: \(String(describing: request.content.badge))")
                    
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        let dateComponents = trigger.dateComponents
                        print("Trigger Date Components: \(dateComponents)")
                    } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                        print("Trigger Time Interval: \(trigger.timeInterval)")
                    }
                    
                    print("--------")
                }
            }
        }
    }
}

//測試Notification
extension CourseData {
//    func scheduleNotificationTest() {
//        let content = UNMutableNotificationContent()
//        content.title = "測試課程"
//        content.body = "Your class is about to start!"
//        content.sound = .default
//        var dateComponents = DateComponents()
//        dateComponents.weekday = 3
//        dateComponents.hour = 15
//        dateComponents.minute = 37
//        // 创建触发器
//        let triggerDate = dateComponents // 根据课程时间计算触发时间
//        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
//        
//        // 创建通知请求
//        let request = UNNotificationRequest(identifier: "1", content: content, trigger: trigger)
//        
//        // 添加通知请求
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("Error scheduling notification: \(error.localizedDescription)")
//            } else {
//                print("Notification scheduled for course 測試課程.")
//            }
//        }
//    }
    
//    func scheduleDailyReminderNotification() {
//        let content = UNMutableNotificationContent()
//        content.title = "Reminder"
//        content.body = "It's 10 PM! Don't forget to check your courses."
//        content.sound = .default
//
//        // 创建触发器
//        var dateComponents = DateComponents()
//        dateComponents.hour = 22  // 10 PM
//        dateComponents.minute = 0
//        
//        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
//        
//        // 创建通知请求
//        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
//        
//        // 添加通知请求
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("Error scheduling daily reminder notification: \(error.localizedDescription)")
//            } else {
//                print("Daily reminder notification scheduled for 10 PM.")
//            }
//        }
//    }
}
