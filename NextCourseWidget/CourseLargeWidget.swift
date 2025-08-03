//
//  CourseLargeWidget.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/3.
//


import WidgetKit
import SwiftUI
import CoreData

struct CourseLargeEntry: TimelineEntry {
    let date: Date
    let allCourses: [CourseEntity]
}

struct CourseLargeProvider: TimelineProvider {
    func placeholder(in context: Context) -> CourseLargeEntry {
        CourseLargeEntry(date: Date(), allCourses: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (CourseLargeEntry) -> ()) {
        let entry = CourseLargeEntry(date: Date(), allCourses: fetchAllCourses())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseLargeEntry>) -> ()) {
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? Date()
        let entry = CourseLargeEntry(date: currentDate, allCourses: fetchAllCourses())
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
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


import SwiftUI

struct CourseLargeView: View {
    let entry: CourseLargeProvider.Entry

    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    let timeSlots: [Course.TimeSlot] = [
        .morning1, .morning2, .morning3, .morning4,
        .afternoon1, .afternoon2, .afternoon3, .afternoon4, .afternoon5
    ]
    let timeTexts: [String] = ["08.", "09.", "10.", "11.", "13.", "14.", "15.", "16.", "17."]

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width - 12 // subtracting horizontal padding (6 + 6)
            let columnWidth = (totalWidth - 30 - (CGFloat(days.count - 1) * 2)) / CGFloat(days.count)

            VStack(alignment: .leading, spacing: 2) {
                // Header Row
                HStack(spacing: 2) {
                    Text("") // Top-left blank corner
                        .frame(width: 30, height: 30)

                    ForEach(days, id: \.self) { day in
                        Text(day.prefix(3))
                            .font(.caption.bold())
                            .frame(width: columnWidth, height: 30)
                    }
                }

                // Course Rows
                ForEach(timeSlots.indices, id: \.self) { index in
                    let slot = timeSlots[index]
                    let timeText = timeTexts[index]

                    if index == 4 {
                        Divider().padding(.vertical, 2)
                    }

                    HStack(spacing: 2) {
                        // 時間欄
                        Text(timeText)
                            .font(.caption2)
                            .frame(width: 30, height: 30)
                            .background(Color.gray.opacity(0.1))

                        // 各天的課程格子
                        ForEach(days, id: \.self) { day in
                            let course = entry.allCourses.first { $0.day == day && $0.timeSlot == slot.rawValue }

                            ZStack {
                                Rectangle()
                                    .fill(highlightCell(day: day, slot: slot) ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.1))

                                Text(course?.name ?? "")
                                    .font(.system(size: 10))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.5)
                                    .padding(2)
                            }
                            .frame(width: columnWidth, height: 30)
                        }
                    }
                }
            }
            .padding(6)
        }
    }

    func highlightCell(day: String, slot: Course.TimeSlot) -> Bool {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US")

        let currentDay = formatter.string(from: now)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)

        guard day == currentDay else { return false }

        switch slot {
            case .morning1: return hour == 8
            case .morning2: return hour == 9
            case .morning3: return hour == 10
            case .morning4: return hour == 11
            case .afternoon1: return hour == 13
            case .afternoon2: return hour == 14
            case .afternoon3: return hour == 15
            case .afternoon4: return hour == 16
            case .afternoon5: return hour == 17
            default: return false
        }
    }
}

struct CourseLargeWidget: Widget {
    let kind: String = "CourseLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CourseLargeProvider()) { entry in
            if #available(iOS 17.0, *) {
                CourseLargeView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                CourseLargeView(entry: entry)
                    .background(Color(.systemBackground))
            }
        }
        .configurationDisplayName("課表總覽")
        .description("顯示週一至週五課表")
        .supportedFamilies([.systemLarge])
    }
}

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
