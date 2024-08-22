//
//  NextCourseWidget.swift
//  NextCourseWidget
//
//  Created by 許君愷 on 2024/8/21.
//

import WidgetKit
import SwiftUI
import CoreData
import CloudKit

import WidgetKit
import SwiftUI
import CoreData

struct NextCourseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextCourseEntry {
        NextCourseEntry(date: Date(), course: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NextCourseEntry) -> ()) {
        let entry = NextCourseEntry(date: Date(), course: fetchNextCourse())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextCourseEntry>) -> ()) {
        var entries: [NextCourseEntry] = []
        
        // Update the widget every 30 minutes
        let currentDate = Date()
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 10, to: currentDate)!
        
        let entry = NextCourseEntry(date: currentDate, course: fetchNextCourse())
        entries.append(entry)
        
        let timeline = Timeline(entries: entries, policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    func fetchNextCourse() -> CourseEntity? {
        let currentDate = Date()
        let calendar = Calendar.current
        print("Finding next course...")

        var nextCourse: CourseEntity?
        var smallestTimeDifference: TimeInterval = .greatestFiniteMagnitude
        
        // 获取 CourseEntity 数据
        let courses = fetchAllCourses() // 获取所有课程
        print("Fetched \(courses.count) courses.")

        for course in courses {
            if let courseDate = getCourseDate(for: course) {
                let timeDifference = courseDate.timeIntervalSince(currentDate)
                print("Course: \(course.name ?? "Unknown"), Start Date: \(courseDate), Time Difference: \(timeDifference)")
                
                if timeDifference > 0 && timeDifference < smallestTimeDifference {
                    smallestTimeDifference = timeDifference
                    nextCourse = course
                    print("New next course found: \(course.name ?? "Unknown") with time difference \(smallestTimeDifference)")
                }
            } else {
                print("Course \(course.name ?? "Unknown") has an invalid date.")
            }
        }
        
        if let nextCourse = nextCourse {
            print("Next course: \(nextCourse.name ?? "Unknown") at \(getCourseDate(for: nextCourse) ?? Date())")
        } else {
            print("No upcoming course found.")
        }
        
        return nextCourse
    }
    
    private func getCourseDate(for course: CourseEntity) -> Date? {
        let currentDate = Date()
        let calendar = Calendar.current
        
        // 将 day 转换为星期几的整数
        let weekday = weekday(from: course.day ?? "Monday")
        print("Course Day: \(course.day ?? "Unknown"), Weekday: \(weekday)")
        
        // 获取当前日期的 DateComponents
        var dateComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: currentDate)
        
        // 检查课程是否是今天的
        if dateComponents.weekday == weekday {
            // 获取课程的时间
            let hour = hour(from: course.startTime ?? "eight")
            print("Course Start Time: \(course.startTime ?? "Unknown"), Hour: \(hour)")
            
            dateComponents.hour = hour
            dateComponents.minute = 15 // 根据需要设置分钟
            
            return calendar.date(from: dateComponents)
        }
        
        return nil
    }
    
    func weekday(from day: String) -> Int {
        switch day.lowercased() {
        case "monday": return 2
        case "tuesday": return 3
        case "wednesday": return 4
        case "thursday": return 5
        case "friday": return 6
        default: return 1
        }
    }

    func hour(from startTime: String) -> Int {
        switch startTime.lowercased() {
        case "8:10": return 8
        case "9:10": return 9
        case "10:10": return 10
        case "11:10": return 11
        case "13:10": return 13
        case "14:10": return 14
        case "15:10": return 15
        case "16:10": return 16
        case "17:10": return 17
        case "18:30": return 18
        default: return 8 // 默认值
        }
    }
    
    private func fetchAllCourses() -> [CourseEntity] {
        let container = NSPersistentCloudKitContainer(name: "CourseModel")
        let appGroupIdentifier = "group.NTPUOne.NextCourseWidget"
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("shared.sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL!)
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("Persistent store loaded: \(storeDescription)")
            }
        }
        
        let context = container.viewContext
        let request: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        
        do {
            let result = try context.fetch(request)
            print("Fetched \(result.count) courses from Core Data.")
            return result
        } catch {
            print("Error fetching courses: \(error)")
            return []
        }
    }
    
}

struct NextCourseEntry: TimelineEntry {
    let date: Date
    let course: CourseEntity?
}

struct NextCourseWidgetEntryView : View {
    var entry: NextCourseWidgetProvider.Entry

    var body: some View {
        VStack {
            if let course = entry.course {
                HStack{
                    VStack(alignment: .leading){
                        Text("下一堂課:")
                            .font(.caption.bold())
                        Text(course.name ?? "Unknown")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.blue)
                            .padding(.bottom, 3)
                        Text("開始時間:")
                            .font(.caption.bold())
                        Text(course.startTime ?? "Unknown")
                            .foregroundStyle(Color.red)
                            .font(.subheadline.bold())
                            .padding(.bottom, 3)
                        Text("教授： \(course.teacher ?? "Unknown")")
                            .font(.caption.bold())
                        Text("教室： \(course.location ?? "Unknown")")
                            .font(.caption.bold())
                    }
                    .padding(.vertical)
                    Spacer()
                }
            } else {
                Text("No upcoming course")
                    .font(.subheadline.bold())
                Text("資料未刷新時，可點擊進App或連上網路試試")
                    .font(.caption2)
                    .padding()
                    .foregroundStyle(Color.gray)
            }
        }
    }
}

struct NextCourseAccessoryRectangularView: View {
    var entry: NextCourseWidgetProvider.Entry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if let course = entry.course {
                    Text("下一堂課:")
                        .font(.body)
                    Text(course.name ?? "Unknown")
                        .font(.body.bold())
                        .lineLimit(1)
                    Text("開始時間: \(course.startTime ?? "Unknown")")
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text("下一堂課:")
                        .font(.body)
                    Text("No upcoming course")
                        .font(.body.bold())
                        .lineLimit(1)
                    Text("時間: 無")
                        .font(.body)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

struct WidgetView: View {
    var entry: NextCourseWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            if #available(iOS 17.0, *) {
                NextCourseWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                NextCourseWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color.gray)
            }
        case .accessoryRectangular:
            if #available(iOS 17.0, *) {
                NextCourseAccessoryRectangularView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                NextCourseAccessoryRectangularView(entry: entry)
                    .padding()
                    .background(Color.gray)
            }
        default:
            Text("Unsupported")
        }
    }
}

struct NextCourseWidget: Widget {
    let kind: String = "NextCourseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextCourseWidgetProvider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Next Course Widget")
        .description("Shows the next upcoming course.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
//
//#Preview(as: .systemSmall) {
//    NextCourseWidget()
//} timeline: {
//    SimpleEntry(date: .now, emoji: "😀")
//    SimpleEntry(date: .now, emoji: "🤩")
//}
