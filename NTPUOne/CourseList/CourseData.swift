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
import WidgetKit

struct Course: Identifiable, Equatable {
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
        case nineteen = "19:25"
        case twenty = "20:25"
        case twentyone = "21:20"

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
        case evening1 = "Evening"
        case evening2 = "Evening 2"
        case evening3 = "Evening 3"
        case evening4 = "Evening 4"

        var id: String { self.rawValue }
    }
}

class CourseData: ObservableObject {
    @Published var courses: [Course] = []
    struct SyncConflict: Identifiable {
        let id: NSManagedObjectID
        let course: Course
    }

    struct ConflictSlot: Identifiable {
        let id: NSManagedObjectID
        let choices: [SyncConflict]
        let activeID: NSManagedObjectID?
    }

    @Published private(set) var conflictSlots: [ConflictSlot] = []
    @Published private(set) var syncConflicts: [SyncConflict] = []
    var viewContext: NSManagedObjectContext?
    private var remoteChanges: NSObjectProtocol?

    init(context: NSManagedObjectContext? = nil) {
        self.viewContext = context
        if let coordinator = context?.persistentStoreCoordinator {
            remoteChanges = NotificationCenter.default.addObserver(
                forName: .NSPersistentStoreRemoteChange, object: coordinator, queue: nil
            ) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.loadCoursesFromCoreData() }
            }
        }
        loadCoursesFromCoreData()
    }

    deinit {
        if let remoteChanges { NotificationCenter.default.removeObserver(remoteChanges) }
    }

    private func course(from row: CourseEntity) -> Course {
        Course(id: row.id ?? row.objectID.uriRepresentation().absoluteString,
               name: row.name ?? "", day: row.day ?? "",
               startTime: Course.TimeStart(rawValue: row.startTime ?? "") ?? .none,
               timeSlot: Course.TimeSlot(rawValue: row.timeSlot ?? "") ?? .morning1,
               location: row.location ?? "", teacher: row.teacher ?? "",
               isNotification: row.isNotification)
    }

    func loadCoursesFromCoreData() {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot load courses from Core Data.")
            return
        }
        
        let fetchRequest: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()

        do {
            fetchRequest.shouldRefreshRefetchedObjects = !viewContext.hasChanges
            var rows = try viewContext.fetch(fetchRequest)
            let fetchedIDs = Set(rows.compactMap(\.id))
            if !viewContext.hasChanges {
                do {
                    if try mergeDuplicateCourses(rows, in: viewContext) {
                        rows = try viewContext.fetch(fetchRequest)
                    }
                } catch {
                    viewContext.rollback()
                    rows = try viewContext.fetch(fetchRequest)
                }
            }
            let selection = CourseScheduleStorage.partition(rows)
            let previousIDs = Set(courses.map(\.id))
            let visible = selection.visible.map(course(from:))
            courses = visible
            syncConflicts = selection.conflicts.map { SyncConflict(id: $0.objectID, course: course(from: $0)) }
            let activeIDs = Set(selection.visible.map(\.objectID))
            var groupedIDs = Set<NSManagedObjectID>()
            conflictSlots = selection.conflicts.compactMap { row in
                guard !groupedIDs.contains(row.objectID) else { return nil }
                let matches = rows.filter { $0 === row || CourseScheduleStorage.sameSlot(row, $0) }
                groupedIDs.formUnion(matches.map(\.objectID))
                let active = matches.first { activeIDs.contains($0.objectID) }
                let choices = matches.map { SyncConflict(id: $0.objectID, course: course(from: $0)) }
                    .sorted { ($0.course.name, $0.course.id) < ($1.course.name, $1.course.id) }
                return ConflictSlot(id: active?.objectID ?? row.objectID, choices: choices, activeID: active?.objectID)
            }.sorted {
                guard let lhs = $0.choices.first?.course, let rhs = $1.choices.first?.course else { return false }
                let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                let slots = Course.TimeSlot.allCases
                return (days.firstIndex(of: lhs.day) ?? 7, slots.firstIndex(of: lhs.timeSlot) ?? 13)
                    < (days.firstIndex(of: rhs.day) ?? 7, slots.firstIndex(of: rhs.timeSlot) ?? 13)
            }
            let visibleIDs = Set(courses.map(\.id))
            for id in previousIDs.union(fetchedIDs).subtracting(visibleIDs) {
                cancelNotification(withId: id)
            }
            scheduleNotificationsForAllCourses()
        } catch {
            print("Error: Failed to fetch courses from Core Data - \(error.localizedDescription)")
        }
        checkNotificationAuthorizationStatus()
//        scheduleDailyReminderNotification() //測試
        listAllPendingNotifications() //列通知
//        scheduleNotificationTest() //測試
        refreshNextCourseLiveActivity()
    }
    
    private func mergeDuplicateCourses(_ rows: [CourseEntity], in context: NSManagedObjectContext) throws -> Bool {
        var merged = false
        for group in CourseScheduleStorage.duplicateGroups(rows) {
            let ids = group.compactMap(\.id)
            // A local Core Data object ID is different on each device. A repeated
            // logical ID must be resolved explicitly to avoid mutual deletion.
            guard ids.count == group.count, ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count,
                  let winner = group.first, let winnerID = winner.id,
                  rows.filter({ $0.id == winnerID }).count == 1,
                  ids.allSatisfy({ id in rows.filter { $0.id == id }.count == 1 }) else { continue }
            for duplicate in group.dropFirst() {
                if winner.teacher?.isEmpty != false { winner.teacher = duplicate.teacher }
                if winner.location?.isEmpty != false { winner.location = duplicate.location }
                winner.isNotification = winner.isNotification || duplicate.isNotification
                try updateMemoLinks(from: duplicate.id, to: winnerID, in: context)
                context.delete(duplicate)
            }
            merged = true
        }
        if merged { try context.save() }
        return merged
    }

    private func updateMemoLinks(from id: String?, to replacement: String?, in context: NSManagedObjectContext) throws {
        guard let id, !id.isEmpty else { return }
        let request = MemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "courseLink == %@", id)
        for memo in try context.fetch(request) {
            memo.courseLink = replacement
            memo.updatedAt = Date()
        }
    }

    func keepCourse(_ choice: SyncConflict, in group: ConflictSlot) -> Bool {
        guard let context = viewContext, !context.hasChanges else { return false }
        do {
            let request = CourseEntity.fetchRequest()
            request.shouldRefreshRefetchedObjects = true
            let rows = try context.fetch(request)
            guard let kept = rows.first(where: { $0.objectID == choice.id }) else { throw CourseScheduleStorage.Conflict() }
            let candidates = rows.filter { $0 === kept || CourseScheduleStorage.sameSlot(kept, $0) }
            guard candidates.count > 1, Set(candidates.map(\.objectID)) == Set(group.choices.map(\.id)),
                  candidates.allSatisfy({ row in group.choices.contains { $0.id == row.objectID && $0.course == course(from: row) } }) else {
                throw CourseScheduleStorage.Conflict()
            }
            if let id = kept.id, rows.contains(where: { $0.id == id && !candidates.contains($0) }) {
                kept.id = UUID().uuidString
            }
            for row in candidates where row !== kept {
                if let id = row.id, !rows.contains(where: { $0.id == id && ($0 === kept || !candidates.contains($0)) }) {
                    try updateMemoLinks(from: id, to: nil, in: context)
                }
                context.delete(row)
            }
            try context.save()
            loadCoursesFromCoreData()
            return true
        } catch {
            context.rollback()
            loadCoursesFromCoreData()
            CoreDataManager.shared.reportOperationError(error)
            return false
        }
    }

    func contiguousCourses(around course: Course) -> [Course] {
        let slots = Course.TimeSlot.allCases
        guard let index = slots.firstIndex(of: course.timeSlot) else { return [course] }
        let name = course.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = courses.filter {
            $0.day == course.day && $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == name
        }
        func at(_ offset: Int) -> Course? {
            guard slots.indices.contains(offset) else { return nil }
            return matching.first { $0.timeSlot == slots[offset] }
        }
        var first = index, last = index
        while at(first - 1) != nil { first -= 1 }
        while at(last + 1) != nil { last += 1 }
        return (first...last).compactMap { $0 == index ? course : at($0) }
    }

    func updateBlock(_ original: [Course], selected: Course, edited: Course) -> Bool {
        let slots = Course.TimeSlot.allCases
        guard let offset = original.firstIndex(where: { $0.id == selected.id }),
              let index = slots.firstIndex(of: edited.timeSlot) else { return false }
        let start = index - offset
        guard start >= 0, start + original.count <= slots.count else {
            CoreDataManager.shared.reportOperationError(CourseScheduleStorage.Conflict())
            return false
        }
        let replacement = original.enumerated().map { position, old in
            var course = old
            course.name = edited.name
            course.teacher = edited.teacher
            course.location = edited.location
            course.day = edited.day
            course.timeSlot = slots[start + position]
            if old.id == edited.id { course.isNotification = edited.isNotification }
            return course
        }
        return saveCourses(replacement, updating: true, expected: original)
    }

    func scheduleNotificationsForAllCourses() {
        // 只移除課程通知，避免清掉 Memo 通知
        let courseIds = courses.map { $0.id }
        if !courseIds.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: courseIds)
        }
        for course in courses {
            if course.isNotification {
                scheduleNotification(for: course)
            } else {
                cancelNotification(for: course)
            }
        }
    }

    @discardableResult
    func addCourse(_ course: Course) -> Bool {
        saveCourses([course])
    }

    @discardableResult
    func updateCourse(_ course: Course) -> Bool {
        saveCourses([course], updating: true)
    }

    func saveCourses(_ newCourses: [Course], replacing previousCourses: [Course] = [], updating: Bool = false, expected: [Course] = []) -> Bool {
        guard let context = viewContext, !context.hasChanges else { return false }
        do {
            let request = CourseEntity.fetchRequest()
            request.shouldRefreshRefetchedObjects = true
            let rows = try context.fetch(request)
            for original in expected {
                let matches = rows.filter { $0.id == original.id }
                guard matches.count == 1, let row = matches.first, course(from: row) == original else {
                    throw CourseScheduleStorage.Conflict()
                }
            }
            for previous in previousCourses {
                let matches = rows.filter { $0.id == previous.id }
                guard matches.count == 1, let old = matches.first, course(from: old) == previous else {
                    throw CourseScheduleStorage.Conflict()
                }
                context.delete(old)
            }
            for course in newCourses {
                let row: CourseEntity
                if updating {
                    let matches = rows.filter { !$0.isDeleted && $0.id == course.id }
                    guard matches.count == 1, let existing = matches.first else { throw CourseScheduleStorage.Conflict() }
                    row = existing
                } else {
                    row = CourseEntity(context: context)
                    row.id = course.id
                }
                row.name = course.name
                row.day = course.day
                row.timeSlot = course.timeSlot.rawValue
                row.startTime = Self.startTime(for: course.timeSlot).rawValue
                row.location = course.location
                row.teacher = course.teacher
                row.isNotification = course.isNotification
            }
            try CourseScheduleStorage.validatePendingChanges(in: context)
            try context.save()
            loadCoursesFromCoreData()
            return true
        } catch {
            context.rollback()
            CoreDataManager.shared.reportOperationError(error)
            return false
        }
    }

    private static func startTime(for slot: Course.TimeSlot) -> Course.TimeStart {
        let times: [Course.TimeStart] = [.eight, .nine, .ten, .eleven, .thirteen, .fourteen, .fifteen,
                                         .sixteen, .seventeen, .eighteen, .nineteen, .twenty, .twentyone]
        return times[Course.TimeSlot.allCases.firstIndex(of: slot)!]
    }

    func deleteCourse(_ course: Course) -> Bool {
        deleteBlock([course])
    }

    func deleteBlock(_ block: [Course]) -> Bool {
        guard let context = viewContext, !context.hasChanges else { return false }
        do {
            let request = CourseEntity.fetchRequest()
            request.shouldRefreshRefetchedObjects = true
            let rows = try context.fetch(request)
            for course in block {
                let matches = rows.filter { $0.id == course.id }
                guard matches.count == 1, let row = matches.first, self.course(from: row) == course else {
                    throw CourseScheduleStorage.Conflict()
                }
                context.delete(row)
            }
            try context.save()
            loadCoursesFromCoreData()
            return true
        } catch {
            context.rollback()
            CoreDataManager.shared.reportOperationError(error)
            return false
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
                loadCoursesFromCoreData()
            } else {
                print("Info: No course found with id \(courseId) to delete.")
            }
        } catch {
            print("Error: Failed to delete course by id \(courseId) - \(error.localizedDescription)")
        }
    }

    @discardableResult
    func resolveConflict(_ id: NSManagedObjectID, day: String, slot: Course.TimeSlot) -> Bool {
        guard let context = viewContext, !context.hasChanges else { return false }
        do {
            let request = CourseEntity.fetchRequest()
            request.shouldRefreshRefetchedObjects = true
            let rows = try context.fetch(request)
            guard let row = CourseScheduleStorage.partition(rows).conflicts.first(where: { $0.objectID == id }) else {
                throw CourseScheduleStorage.Conflict()
            }
            if row.id == nil || row.id?.isEmpty == true || rows.contains(where: { $0 !== row && $0.id == row.id }) {
                row.id = UUID().uuidString
            }
            row.day = day
            row.timeSlot = slot.rawValue
            row.startTime = Self.startTime(for: slot).rawValue
            try CourseScheduleStorage.validatePendingChanges(in: context)
            try context.save()
            loadCoursesFromCoreData()
            return true
        } catch {
            context.rollback()
            CoreDataManager.shared.reportOperationError(error)
            return false
        }
    }

    func removeConflict(_ id: NSManagedObjectID) -> Bool {
        guard let context = viewContext, !context.hasChanges else { return false }
        do {
            let request = CourseEntity.fetchRequest()
            request.shouldRefreshRefetchedObjects = true
            let rows = try context.fetch(request)
            guard let row = CourseScheduleStorage.partition(rows).conflicts.first(where: { $0.objectID == id }) else {
                throw CourseScheduleStorage.Conflict()
            }
            if let courseID = row.id, !rows.contains(where: { $0 !== row && $0.id == courseID }) {
                let request: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
                request.predicate = NSPredicate(format: "courseLink == %@", courseID)
                for memo in try context.fetch(request) {
                    memo.courseLink = nil
                    memo.updatedAt = Date()
                }
            }
            context.delete(row)
            try context.save()
            loadCoursesFromCoreData()
            return true
        } catch {
            context.rollback()
            CoreDataManager.shared.reportOperationError(error)
            return false
        }
    }

    @discardableResult
    func clearSchedule(deleteLinkedMemos: Bool) -> Bool {
        guard let context = viewContext, !context.hasChanges else { return false }
        do {
            let rows = try context.fetch(CourseEntity.fetchRequest())
            let ids = rows.compactMap(\.id)
            let memoRequest: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
            memoRequest.predicate = NSPredicate(format: "courseLink IN %@", ids)
            let linked = try context.fetch(memoRequest)
            for memo in linked {
                if deleteLinkedMemos { context.delete(memo) }
                else { memo.courseLink = nil; memo.updatedAt = Date() }
            }
            for row in rows { context.delete(row) }
            try context.save()
            for course in courses { cancelNotification(for: course) }
            loadCoursesFromCoreData()
            refreshNextCourseLiveActivity()
            return true
        } catch {
            context.rollback()
            CoreDataManager.shared.reportOperationError(error)
            return false
        }
    }

    func deleteAllCourses() {
        guard let viewContext = viewContext else {
            print("Error: View context is nil. Cannot delete all courses.")
            return
        }

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CourseEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            // 執行批次刪除
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            
            // 清空記憶體中的課程
            let courseIds = courses.map { $0.id }
            courses.removeAll()
            syncConflicts.removeAll()
            conflictSlots.removeAll()
            
            // 只取消課程通知，避免清掉 Memo 通知
            if !courseIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: courseIds)
            }

            print("Success: All courses deleted from Core Data and notifications cleared.")
            refreshNextCourseLiveActivity()
        } catch {
            CoreDataManager.shared.reportOperationError(error)
            print("Error: Failed to delete all courses - \(error.localizedDescription)")
        }
    }

    func refreshNextCourseLiveActivity() {
        let currentCourses = courses
        Task { @MainActor in
            NextCourseLiveActivityManager.shared.sync(with: currentCourses)
            WidgetCenter.shared.reloadTimelines(ofKind: "NextCourseWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "CourseLargeWidget")
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
            CoreDataManager.shared.reportOperationError(error)
            print("Error: Failed to save context - \(error.localizedDescription)")
        }
    }
}



extension CourseData {
    // 调度通知的方法
    func scheduleNotification(for course: Course) {
        let content = UNMutableNotificationContent()
        let location = course.location.isEmpty ? String(localized: "not_filled") : course.location
        let teacher = course.teacher.isEmpty ? String(localized: "not_filled") : course.teacher
        content.title = "📚 \(course.name)"
        content.subtitle = String(localized: "class_reminder")
        content.body = String(localized: "notification_class_body \(course.day) \(course.startTime.rawValue) \(location) \(teacher)")
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
            }
        }
    }
    
    
    // 取消通知的方法
    func cancelNotification(for course: Course) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [course.id])
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
        if dateComponents.hour == 18{
            dateComponents.minute = 20
        } else if dateComponents.hour == 19{
            dateComponents.minute = 15
        } else if dateComponents.hour == 20{
            dateComponents.minute = 10
        }else if dateComponents.hour == 21{
            dateComponents.minute = 5
        }
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
        case "saturday": return 7
        case "sunday": return 1
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
        case .nineteen:
            return 19
        case .twenty:
            return 20
        case .twentyone:
            return 21
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
