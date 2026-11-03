import SwiftUI
import CoreData

/// Suggestions are never executed directly. This view resolves local targets,
/// lets the user edit every proposed field, and requires an explicit save/delete.
struct AIChangeReviewView: View {
    let proposal: AIChangeProposal
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    @EnvironmentObject private var academic: AcademicSyncStore
    @Environment(\.dismiss) private var dismiss
    @State private var account = ""
    @State private var targetID = ""
    @State private var originalMemo: Memo?
    @State private var originalCourse: Course?
    @State private var title = ""
    @State private var content = ""
    @State private var memoType: Memo.TagType = .other
    @State private var memoPriority: Memo.Priority = .medium
    @State private var memoStatus: Memo.MemoStatus = .todo
    @State private var courseLink = ""
    @State private var courseNotifications = false
    @State private var weekday = ""
    @State private var period = 0
    @State private var location = ""
    @State private var teacher = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var badDeadline = false
    @State private var showDelete = false
    @State private var showCourseEditor = false
    @State private var draftCourse = Course(id: "", name: "", day: "Monday", startTime: .none, timeSlot: .morning1, location: "", teacher: "", isNotification: false)
    @State private var dummyNew = false
    @State private var error: String?
    private let weekdays = [("Monday", "週一"), ("Tuesday", "週二"), ("Wednesday", "週三"), ("Thursday", "週四"), ("Friday", "週五"), ("Saturday", "週六")]
    private var needsTarget: Bool { proposal.operation != .create }
    private var operationTitle: String {
        switch proposal.operation { case .create: return "新增"; case .edit: return "修改"; case .delete: return "刪除" }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("AI 建議：\(operationTitle)\(proposal.kind == .memo ? "備忘錄" : "課程")", systemImage: "sparkles")
                    Text("請核對並編輯內容，只有按下確認後才會更改資料。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if needsTarget {
                    Section("選擇要\(operationTitle)的項目") {
                        Picker("項目", selection: $targetID) {
                            Text("請選擇").tag("")
                            if proposal.kind == .memo {
                                ForEach(memoManager.memos) { memo in Text(memo.title).tag(memo.id) }
                            } else {
                                ForEach(courseData.courses) { course in Text("\(course.name) · \(course.day) · \(course.timeSlot.rawValue)").tag(course.id) }
                            }
                        }
                        if let memo = originalMemo { Text("原內容：\(memo.title)\n\(memo.content)").font(.caption).foregroundStyle(.secondary) }
                        if let course = originalCourse { Text("原內容：\(course.name) · \(course.day) · \(course.timeSlot.rawValue)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if proposal.operation != .delete {
                    Section("確認或手動修改") {
                        TextField("名稱", text: $title)
                        if proposal.kind == .memo {
                            TextField("內容", text: $content, axis: .vertical).lineLimit(2...6)
                            Picker("類型", selection: $memoType) { ForEach(Memo.TagType.allCases) { Text($0.displayName).tag($0) } }
                            Picker("優先級", selection: $memoPriority) { ForEach(Memo.Priority.allCases) { Text($0.displayName).tag($0) } }
                            Picker("狀態", selection: $memoStatus) { ForEach(Memo.MemoStatus.allCases) { Text($0.displayName).tag($0) } }
                            Picker("連結課程", selection: $courseLink) {
                                Text("無").tag("")
                                ForEach(courseData.courses) { Text("\($0.name) · \($0.day)").tag($0.id) }
                            }
                            Toggle("設定截止時間", isOn: $hasDeadline)
                            if hasDeadline { DatePicker("截止", selection: $deadline) }
                            if badDeadline {
                                Text("建議的日期無法辨識，請手動選擇截止時間。").foregroundStyle(.orange).font(.caption)
                                Button("先不設定截止時間") { hasDeadline = false; badDeadline = false }
                            }
                        } else {
                            Picker("星期", selection: $weekday) {
                                Text("請選擇").tag("")
                                ForEach(weekdays.indices, id: \.self) { index in Text(weekdays[index].1).tag(weekdays[index].0) }
                            }
                            Picker("節次", selection: $period) {
                                Text("請選擇").tag(0)
                                ForEach(1...13, id: \.self) { Text("第 \($0) 節").tag($0) }
                            }
                            TextField("教室", text: $location)
                            TextField("教師", text: $teacher)
                            Toggle("課程通知", isOn: $courseNotifications)
                        }
                    }
                } else {
                    Section { Text(proposal.kind == .course ? "課程刪除會進入既有確認流程，並顯示對相關待辦的影響。" : "刪除只影響 App 的備忘錄；不會刪除 Moodle 上的作業。")
                        .font(.caption).foregroundStyle(.secondary) }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Section {
                    Button(proposal.operation == .delete ? "繼續刪除" : "確認儲存", role: proposal.operation == .delete ? .destructive : nil) {
                        if proposal.operation == .delete { prepareDelete() } else { save() }
                    }.disabled(needsTarget && targetID.isEmpty)
                }
            }
            .navigationTitle("預覽資料變更")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .onAppear(perform: prepare)
            .onChange(of: targetID) { _ in selectTarget() }
            .onChange(of: academic.uid) { _ in dismiss() }
            .onChange(of: deadline) { _ in badDeadline = false }
            .onChange(of: showCourseEditor) { visible in
                if !visible, proposal.operation == .delete, !courseData.courses.contains(where: { $0.id == targetID }) { dismiss() }
            }
            .confirmationDialog("確定刪除「\(originalMemo?.title ?? "此備忘錄")」？", isPresented: $showDelete, titleVisibility: .visible) {
                Button("確認刪除", role: .destructive) { deleteMemo() }
            }
            .sheet(isPresented: $showCourseEditor) {
                CourseFormSheet(isNewCourse: $dummyNew, selectedCourse: $draftCourse, newCourse: $draftCourse,
                                courseData: courseData, showingSheet: $showCourseEditor, memoManager: memoManager, expectedOriginalCourse: originalCourse)
            }
        }
    }
    private func prepare() {
        account = academic.uid
        title = proposal.title ?? ""; content = proposal.content ?? ""
        weekday = proposal.weekday ?? ""; period = proposal.period ?? 0
        location = proposal.location ?? ""; teacher = proposal.teacher ?? ""
        if let raw = proposal.deadline {
            if let date = ISO8601DateFormatter().date(from: raw) { hasDeadline = true; deadline = date }
            else { badDeadline = true }
        }
        if let target = proposal.target, needsTarget {
            if proposal.kind == .memo {
                let matches = memoManager.memos.filter { $0.title == target }
                if matches.count == 1 { targetID = matches[0].id }
            } else {
                let matches = courseData.courses.filter { $0.name == target }
                if matches.count == 1 { targetID = matches[0].id }
            }
        }
    }
    private func selectTarget() {
        originalMemo = memoManager.memos.first { $0.id == targetID }
        originalCourse = courseData.courses.first { $0.id == targetID }
        if let memo = originalMemo {
            title = proposal.title ?? memo.title; content = proposal.content ?? memo.content
            memoType = memo.tagType; memoPriority = memo.priority; memoStatus = memo.status; courseLink = memo.courseLink ?? ""
            if proposal.deadline == nil { hasDeadline = memo.dueAt != nil; deadline = memo.dueAt ?? Date() }
        }
        if let course = originalCourse {
            title = proposal.title ?? course.name; weekday = proposal.weekday ?? course.day
            period = proposal.period ?? ((Course.TimeSlot.allCases.firstIndex(of: course.timeSlot) ?? 0) + 1)
            location = proposal.location ?? course.location; teacher = proposal.teacher ?? course.teacher; courseNotifications = course.isNotification
        }
    }
    private func validAccount() -> Bool {
        guard academic.uid == account else { error = "帳號已變更，請重新提出要求。"; return false }
        return true
    }
    private func save() {
        guard validAccount() else { return }
        guard let context = proposal.kind == .memo ? memoManager.viewContext : courseData.viewContext, !context.hasChanges else {
            error = "資料正在儲存，請稍後重新預覽。"; return
        }
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 120, content.count <= 5000 else { error = "請輸入有效名稱與內容。"; return }
        guard !badDeadline else { error = "請手動選擇有效截止時間。"; return }
        if proposal.kind == .memo {
            guard courseLink.isEmpty || courseData.courses.contains(where: { $0.id == courseLink }) else { error = "連結的課程已不存在，請重新選擇。"; return }
            if proposal.operation == .create {
                let now = Date()
                let memo = Memo(id: UUID().uuidString, title: cleaned, content: content, tagType: memoType, courseLink: courseLink.isEmpty ? nil : courseLink,
                    status: memoStatus, priority: memoPriority, createdAt: now, updatedAt: now,
                    dueAt: hasDeadline ? deadline : nil, planAt: nil, doneAt: memoStatus == .done ? now : nil, reminderRules: [])
                memoManager.addMemo(memo)
                guard !context.hasChanges, memoManager.memos.contains(where: { $0.id == memo.id }) else { context.rollback(); error = "儲存未完成，請重試。"; return }
            } else {
                guard var old = originalMemo, let current = memoManager.memos.first(where: { $0.id == old.id }), current == old, AIChangeConsistency.memo(old, in: context) else { error = "備忘錄已變更，請重新預覽。"; return }
                old.title = cleaned; old.content = content; old.dueAt = hasDeadline ? deadline : nil; old.updatedAt = Date()
                old.tagType = memoType; old.priority = memoPriority; old.courseLink = courseLink.isEmpty ? nil : courseLink
                if old.status != memoStatus { old.doneAt = memoStatus == .done ? Date() : nil }; old.status = memoStatus
                memoManager.updateMemo(old)
                guard !context.hasChanges, memoManager.memos.contains(where: { $0 == old }) else { context.rollback(); error = "儲存未完成，請重試。"; return }
            }
        } else {
            guard weekdays.contains(where: { $0.0 == weekday }), (1...13).contains(period) else { error = "請選擇星期及節次。"; return }
            let slot = Course.TimeSlot.allCases[period - 1]
            guard !courseData.courses.contains(where: { $0.day == weekday && $0.timeSlot == slot && $0.id != targetID }) else { error = "此時段已有課程，請先檢查課表。"; return }
            let times: [Course.TimeStart] = [.eight,.nine,.ten,.eleven,.thirteen,.fourteen,.fifteen,.sixteen,.seventeen,.eighteen,.nineteen,.twenty,.twentyone]
            if proposal.operation == .create {
                let course = Course(id: UUID().uuidString, name: cleaned, day: weekday, startTime: times[period-1], timeSlot: slot, location: location, teacher: teacher, isNotification: courseNotifications)
                courseData.addCourse(course)
                guard !context.hasChanges, courseData.courses.contains(where: { $0.id == course.id }) else {
                    context.rollback(); courseData.cancelNotification(for: course); courseData.loadCoursesFromCoreData()
                    error = "儲存未完成，請重試。"; return
                }
            } else {
                guard var old = originalCourse, let current = courseData.courses.first(where: { $0.id == old.id }), AIChangeConsistency.course(old, current), AIChangeConsistency.course(old, in: context) else { error = "課程已變更，請重新預覽。"; return }
                old.name = cleaned; old.day = weekday; old.timeSlot = slot; old.startTime = times[period-1]; old.location = location; old.teacher = teacher; old.isNotification = courseNotifications
                courseData.updateCourse(old)
                guard !context.hasChanges, let updated = courseData.courses.first(where: { $0.id == old.id }), AIChangeConsistency.course(old, updated) else {
                    context.rollback(); courseData.cancelNotification(for: old); courseData.loadCoursesFromCoreData()
                    error = "儲存未完成，請重試。"; return
                }
            }
        }
        dismiss()
    }
    private func prepareDelete() {
        guard validAccount() else { return }
        if proposal.kind == .memo { showDelete = originalMemo != nil }
        else if let course = originalCourse, let context = courseData.viewContext, !context.hasChanges,
                let current = courseData.courses.first(where: { $0.id == course.id }), AIChangeConsistency.course(course, current), AIChangeConsistency.course(course, in: context) {
            draftCourse = current; dummyNew = false; showCourseEditor = true
        } else { error = "課程已變更，請重新預覽。" }
    }
    private func deleteMemo() {
        guard validAccount(), let context = memoManager.viewContext, !context.hasChanges, let old = originalMemo, let current = memoManager.memos.first(where: { $0.id == old.id }), current == old, AIChangeConsistency.memo(old, in: context) else { error = "備忘錄已變更，請重新預覽。"; return }
        memoManager.deleteMemo(old)
        guard !context.hasChanges, !memoManager.memos.contains(where: { $0.id == old.id }) else { context.rollback(); error = "刪除未完成，請重試。"; return }
        dismiss()
    }
}

/// Check both the view model and the persistent context, including CloudKit merges.
enum AIChangeConsistency {
    static func course(_ old: Course, _ current: Course) -> Bool {
        old.id == current.id && old.name == current.name && old.day == current.day && old.timeSlot == current.timeSlot && old.startTime == current.startTime && old.location == current.location && old.teacher == current.teacher && old.isNotification == current.isNotification
    }
    static func course(_ old: Course, in context: NSManagedObjectContext) -> Bool {
        let request: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", old.id); request.fetchLimit = 2
        guard let rows = try? context.fetch(request), rows.count == 1, let entity = rows.first else { return false }
        return entity.name == old.name && entity.day == old.day && entity.timeSlot == old.timeSlot.rawValue && entity.startTime == old.startTime.rawValue && entity.location == old.location && entity.teacher == old.teacher && entity.isNotification == old.isNotification
    }
    static func memo(_ old: Memo, in context: NSManagedObjectContext) -> Bool {
        let request: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", old.id); request.fetchLimit = 2
        guard let rows = try? context.fetch(request), rows.count == 1, let entity = rows.first else { return false }
        return entity.updatedAt == old.updatedAt && entity.title == old.title && entity.content == old.content && entity.courseLink == old.courseLink && entity.status == old.status.rawValue
    }
}
