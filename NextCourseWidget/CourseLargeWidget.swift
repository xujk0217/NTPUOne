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
    let allMemos: [MemoEntity]
}

struct CourseLargeProvider: TimelineProvider {
    func placeholder(in context: Context) -> CourseLargeEntry {
        CourseLargeEntry(date: Date(), allCourses: [], allMemos: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (CourseLargeEntry) -> ()) {
        let entry = CourseLargeEntry(date: Date(), allCourses: fetchAllCourses(), allMemos: fetchAllMemos())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseLargeEntry>) -> ()) {
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? Date()
        let entry = CourseLargeEntry(date: currentDate, allCourses: fetchAllCourses(), allMemos: fetchAllMemos())
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
    
    private func fetchAllMemos() -> [MemoEntity] {
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
        let request: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
        
        // 只獲取未完成的備忘錄
        request.predicate = NSPredicate(format: "status != %@", "已完成")
        
        do {
            let result = try context.fetch(request)
            print("Fetched \(result.count) memos from Core Data.")
            return result
        } catch {
            print("Error fetching memos: \(error)")
            return []
        }
    }
}


import SwiftUI

struct CourseLargeView: View {
    let entry: CourseLargeProvider.Entry

    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    let daysChinese = ["一", "二", "三", "四", "五"]
    
    // 根據是否有晚上課程動態調整顯示的時段
    var displayedTimeSlots: [Course.TimeSlot] {
        let baseSlots: [Course.TimeSlot] = [
            .morning1, .morning2, .morning3, .morning4,
            .afternoon1, .afternoon2, .afternoon3, .afternoon4, .afternoon5
        ]
        
        // 檢查是否有晚上的課程
        let hasEveningCourses = entry.allCourses.contains { course in
            if let timeSlot = course.timeSlot {
                return timeSlot.hasPrefix("Evening")
            }
            return false
        }
        
        if hasEveningCourses {
            return baseSlots + [.evening1, .evening2, .evening3, .evening4]
        } else {
            return baseSlots
        }
    }
    
    var displayedTimeTexts: [String] {
        let baseTexts = ["08", "09", "10", "11", "13", "14", "15", "16", "17"]
        
        let hasEveningCourses = entry.allCourses.contains { course in
            if let timeSlot = course.timeSlot {
                return timeSlot.hasPrefix("Evening")
            }
            return false
        }
        
        if hasEveningCourses {
            return baseTexts + ["18", "19", "20", "21"]
        } else {
            return baseTexts
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width - 16
            let columnWidth = (totalWidth - 32 - (CGFloat(days.count - 1) * 3)) / CGFloat(days.count)
            let hasEvening = displayedTimeSlots.count > 9
            
            // 動態計算格子高度，確保所有內容都能顯示
            let headerHeight: CGFloat = 28
            let vPadding: CGFloat = hasEvening ? 4 : 6
            let hPadding: CGFloat = 8
            let rowSpacing: CGFloat = hasEvening ? 2 : 3
            let dividerHeight: CGFloat = 1
            let dividerPadding: CGFloat = hasEvening ? 0.5 : 1
            
            let numDividers = hasEvening ? 2 : 1
            let totalDividerSpace = CGFloat(numDividers) * (dividerHeight + dividerPadding * 2)
            let totalRowSpacing = CGFloat(displayedTimeSlots.count - 1) * rowSpacing
            
            let availableHeight = geometry.size.height - vPadding * 2 - headerHeight - totalDividerSpace - totalRowSpacing - rowSpacing
            let cellHeight = availableHeight / CGFloat(displayedTimeSlots.count)

            VStack(spacing: rowSpacing) {
                // Header Row
                HStack(spacing: 3) {
                    // 左上角時間圖標
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.15))
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 32, height: headerHeight)

                    ForEach(Array(zip(days, daysChinese)), id: \.0) { day, dayChar in
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isToday(day: day) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            
                            VStack(spacing: 0) {
                                Text(dayChar)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isToday(day: day) ? .blue : .primary)
                            }
                        }
                        .frame(width: columnWidth, height: headerHeight)
                    }
                }

                // Course Rows
                ForEach(displayedTimeSlots.indices, id: \.self) { index in
                    let slot = displayedTimeSlots[index]
                    let timeText = displayedTimeTexts[index]

                    // 上下午分隔線
                    if index == 4 {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: dividerHeight)
                            .padding(.vertical, dividerPadding)
                    }
                    
                    // 下午和晚上的分隔線
                    if index == 9 && hasEvening {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: dividerHeight)
                            .padding(.vertical, dividerPadding)
                    }

                    HStack(spacing: 3) {
                        // 時間欄
                        ZStack {
                            RoundedRectangle(cornerRadius: hasEvening ? 4 : 6)
                                .fill(Color.gray.opacity(0.08))
                            Text(timeText)
                                .font(.system(size: hasEvening ? 9 : 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 32, height: cellHeight)

                        // 各天的課程格子
                        ForEach(days, id: \.self) { day in
                            let course = entry.allCourses.first { $0.day == day && $0.timeSlot == slot.rawValue }
                            let memos = getMemosForCourse(course: course, day: day, allCourses: entry.allCourses, allMemos: entry.allMemos)
                            let isCurrentSlot = highlightCell(day: day, slot: slot)

                            ZStack(alignment: .topTrailing) {
                                // 背景
                                RoundedRectangle(cornerRadius: hasEvening ? 4 : 6)
                                    .fill(getCellBackground(course: course, isCurrentSlot: isCurrentSlot))
                                
                                // 當前時段邊框
                                if isCurrentSlot {
                                    RoundedRectangle(cornerRadius: hasEvening ? 4 : 6)
                                        .strokeBorder(Color.blue.opacity(0.6), lineWidth: hasEvening ? 1.5 : 2)
                                }
                                
                                // 課程名稱
                                if let courseName = course?.name, !courseName.isEmpty {
                                    Text(courseName)
                                        .font(.system(size: hasEvening ? 7.5 : 9, weight: .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .foregroundColor(isCurrentSlot ? .blue : .primary)
                                        .padding(.horizontal, hasEvening ? 2 : 3)
                                        .padding(.vertical, 1)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                }
                                
                                // 備忘錄點點
                                if !memos.isEmpty {
                                    HStack(spacing: 1) {
                                        ForEach(memos.prefix(3), id: \.id) { memo in
                                            Circle()
                                                .fill(colorForTagType(memo.tagType ?? "其他"))
                                                .frame(width: hasEvening ? 3 : 4, height: hasEvening ? 3 : 4)
                                                .shadow(color: .black.opacity(0.2), radius: 0.5)
                                        }
                                    }
                                    .padding(hasEvening ? 1.5 : 2)
                                }
                            }
                            .frame(width: columnWidth, height: cellHeight)
                        }
                    }
                }
            }
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
        }
    }
    
    // 判斷是否為今天
    func isToday(day: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: Date()) == day
    }
    
    // 獲取格子背景色
    func getCellBackground(course: CourseEntity?, isCurrentSlot: Bool) -> Color {
        if course != nil {
            if isCurrentSlot {
                return Color.blue.opacity(0.25)
            } else {
                return Color.blue.opacity(0.12)
            }
        } else {
            return Color.gray.opacity(0.06)
        }
    }

    // 獲取與課程相關的備忘錄（根據同名且同一天的課程）
    func getMemosForCourse(course: CourseEntity?, day: String, allCourses: [CourseEntity], allMemos: [MemoEntity]) -> [MemoEntity] {
        guard let courseName = course?.name, !courseName.isEmpty else { return [] }
        
        // 找出同一天所有同名課程的 ID
        let sameNameSameDayCourseIds = allCourses
            .filter { $0.name == courseName && $0.day == day }
            .compactMap { $0.id }
        
        // 返回與這些課程關聯的所有未完成備忘錄
        return allMemos.filter { memo in
            guard let courseLink = memo.courseLink else { return false }
            return sameNameSameDayCourseIds.contains(courseLink)
        }
    }
    
    // 根據標籤類型返回對應的顏色
    func colorForTagType(_ tagType: String) -> Color {
        switch tagType {
        case "活動": return .orange
        case "作業": return .blue
        case "考試": return .red
        case "會議": return .purple
        case "提醒": return .yellow
        default: return .gray
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
            case .evening1: return hour == 18
            case .evening2: return hour == 19
            case .evening3: return hour == 20
            case .evening4: return hour == 21
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
