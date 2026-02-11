//
//  NextTaskWidget.swift
//  NextCourseWidget
//
//  Created by AI Assistant on 2026/2/11.
//

import WidgetKit
import SwiftUI
import CoreData

struct NextTaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextTaskEntry {
        NextTaskEntry(date: Date(), task: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NextTaskEntry) -> ()) {
        let entry = NextTaskEntry(date: Date(), task: fetchNextTask())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextTaskEntry>) -> ()) {
        var entries: [NextTaskEntry] = []
        
        // Update the widget every 10 minutes
        let currentDate = Date()
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 10, to: currentDate)!
        
        let entry = NextTaskEntry(date: currentDate, task: fetchNextTask())
        entries.append(entry)
        
        let timeline = Timeline(entries: entries, policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    func fetchNextTask() -> MemoEntity? {
        let currentDate = Date()
        print("Finding next task...")

        var nextTask: MemoEntity?
        
        // 获取 MemoEntity 数据
        let tasks = fetchAllTasks()
        print("Fetched \(tasks.count) tasks.")

        // 排序邏輯：
        // 1. 先找有計劃時間(planAt)且未來的
        // 2. 再找有截止時間(dueAt)且未來的
        // 3. 都沒有的話按優先級排序
        
        // 1. 有計劃時間且是未來的任務
        let tasksWithPlan = tasks
            .filter { $0.planAt != nil && $0.planAt! >= currentDate }
            .sorted { ($0.planAt ?? Date.distantFuture) < ($1.planAt ?? Date.distantFuture) }
        
        if let firstTask = tasksWithPlan.first {
            print("Next task (by plan): \(firstTask.title ?? "Unknown")")
            return firstTask
        }
        
        // 2. 有截止時間且是未來的任務
        let tasksWithDue = tasks
            .filter { $0.dueAt != nil && $0.dueAt! >= currentDate }
            .sorted { ($0.dueAt ?? Date.distantFuture) < ($1.dueAt ?? Date.distantFuture) }
        
        if let firstTask = tasksWithDue.first {
            print("Next task (by due): \(firstTask.title ?? "Unknown")")
            return firstTask
        }
        
        // 3. 都沒有的話，按優先級排序
        let tasksWithoutDate = tasks
            .filter { $0.planAt == nil && $0.dueAt == nil }
            .sorted { task1, task2 in
                let priority1 = task1.priority ?? "中"
                let priority2 = task2.priority ?? "中"
                let priorityOrder = ["高": 0, "中": 1, "低": 2]
                return (priorityOrder[priority1] ?? 1) < (priorityOrder[priority2] ?? 1)
            }
        
        if let firstTask = tasksWithoutDate.first {
            print("Next task (by priority): \(firstTask.title ?? "Unknown")")
            return firstTask
        }
        
        print("No next task found.")
        return nextTask
    }
    
    private func fetchAllTasks() -> [MemoEntity] {
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
        
        // 只獲取未完成的任務
        request.predicate = NSPredicate(format: "status != %@", "已完成")
        
        do {
            let result = try context.fetch(request)
            print("Fetched \(result.count) tasks from Core Data.")
            return result
        } catch {
            print("Error fetching tasks: \(error)")
            return []
        }
    }
}

struct NextTaskEntry: TimelineEntry {
    let date: Date
    let task: MemoEntity?
}

struct NextTaskWidgetEntryView: View {
    var entry: NextTaskProvider.Entry

    var body: some View {
        VStack {
            if let task = entry.task {
                HStack{
                    VStack(alignment: .leading){
                        Text("下一個任務:")
                            .font(.caption.bold())
                        Text(task.title ?? "Unknown")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.blue)
                            .padding(.bottom, 3)
                        
                        if let planAt = task.planAt {
                            Text("計劃時間:")
                                .font(.caption.bold())
                            Text(formatDateTime(planAt))
                                .foregroundStyle(Color.red)
                                .font(.subheadline.bold())
                                .padding(.bottom, 3)
                        } else if let dueAt = task.dueAt {
                            Text("截止時間:")
                                .font(.caption.bold())
                            Text(formatDateTime(dueAt))
                                .foregroundStyle(Color.red)
                                .font(.subheadline.bold())
                                .padding(.bottom, 3)
                        }
                        
                        Text("類型： \(task.tagType ?? "其他")")
                            .font(.caption.bold())
                        Text("優先級： \(task.priority ?? "中")")
                            .font(.caption.bold())
                    }
                    .padding(.vertical)
                    Spacer()
                }
            } else {
                Text("No upcoming task")
                    .font(.subheadline.bold())
                Text("資料未刷新時，可點擊進App或連上網路試試")
                    .font(.caption2)
                    .padding()
                    .foregroundStyle(Color.gray)
            }
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct NextTaskAccessoryRectangularView: View {
    var entry: NextTaskProvider.Entry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if let task = entry.task {
                    Text("下一個任務:")
                        .font(.body)
                    Text(task.title ?? "Unknown")
                        .font(.body.bold())
                        .lineLimit(1)
                    
                    if let planAt = task.planAt {
                        Text("\(formatTime(planAt))")
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else if let dueAt = task.dueAt {
                        Text("\(formatTime(dueAt))")
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("優先級: \(task.priority ?? "中")")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("下一個任務:")
                        .font(.body)
                    Text("No upcoming task")
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct NextTaskWidgetView: View {
    var entry: NextTaskProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            if #available(iOS 17.0, *) {
                NextTaskWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                NextTaskWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color.gray)
            }
        case .accessoryRectangular:
            if #available(iOS 17.0, *) {
                NextTaskAccessoryRectangularView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                NextTaskAccessoryRectangularView(entry: entry)
                    .padding()
                    .background(Color.gray)
            }
        default:
            Text("Unsupported")
        }
    }
}

struct NextTaskWidget: Widget {
    let kind: String = "NextTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextTaskProvider()) { entry in
            NextTaskWidgetView(entry: entry)
                .widgetURL(URL(string: "ntpuone://memo")!)
        }
        .configurationDisplayName("Next Task Widget")
        .description("Shows the next upcoming task.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
