import SwiftUI
import CoreData

/// Shared by single and batch previews. Chat IDs live for the same app session.
@MainActor
final class AIChangeExecutionLedger: ObservableObject {
    @Published private var state = AIChangeExecutionState()
    func contains(_ proposal: AIChangeProposal, account: String) -> Bool { state.contains(proposal, account: account) }
    func mark(_ proposals: [AIChangeProposal], account: String) { state.mark(proposals, account: account) }

}


/// Suggestions are never executed directly. This view resolves local targets,
/// lets the user edit every proposed field, and requires an explicit save/delete.
struct AIChangeReviewView: View {
    let proposal: AIChangeProposal
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    @EnvironmentObject private var academic: AcademicSyncStore
    @EnvironmentObject private var ledger: AIChangeExecutionLedger
    @Environment(\.dismiss) private var dismiss
    @State private var account = ""
    @State private var prepared = false
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
    @State private var plannedDate: Date?
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
                                ForEach(AICoursePickerOptions.unique(courseData.courses, selected: courseLink)) { Text($0.name).tag($0.id) }
                            }
                            Toggle("設定截止時間", isOn: $hasDeadline)
                            if hasDeadline { DatePicker("截止", selection: $deadline) }
                            AIPlanDateField(date: $plannedDate)
                            Text(AIMemoReminderPreview.text(due: hasDeadline ? deadline : nil, plan: plannedDate, status: memoStatus, original: originalMemo)).font(.caption).foregroundStyle(.secondary)
                            if courseLink.isEmpty { Text("尚未連結課程，可在上方選擇。").font(.caption).foregroundStyle(.secondary) }
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
                if !visible, proposal.operation == .delete, !courseData.courses.contains(where: { $0.id == targetID }) { ledger.mark([proposal], account: account); dismiss() }
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
        guard !prepared else { return }; prepared = true
        account = academic.uid
        title = proposal.title ?? ""; content = proposal.content ?? ""
        plannedDate = proposal.planAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        if proposal.kind == .memo, proposal.operation == .create {
            courseLink = AICourseLinkResolver.match(proposal, courses: courseData.courses)?.id ?? ""
        }
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
            plannedDate = proposal.planAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? memo.planAt
            title = proposal.title ?? memo.title; content = proposal.content ?? memo.content
            memoType = memo.tagType; memoPriority = memo.priority; memoStatus = memo.status; courseLink = proposal.course.flatMap { _ in AICourseLinkResolver.match(proposal, courses: courseData.courses)?.id } ?? memo.courseLink ?? ""
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
        guard !ledger.contains(proposal, account: account) else { error = "這筆變更已儲存，不會再次執行。"; return false }
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
                    dueAt: hasDeadline ? deadline : nil, planAt: plannedDate, doneAt: memoStatus == .done ? now : nil, reminderRules: [])
                memoManager.addMemo(memo)
                guard !context.hasChanges, memoManager.memos.contains(where: { $0.id == memo.id }) else { context.rollback(); error = "儲存未完成，請重試。"; return }
            } else {
                guard var old = originalMemo, let current = memoManager.memos.first(where: { $0.id == old.id }), current == old, AIChangeConsistency.memo(old, in: context) else { error = "備忘錄已變更，請重新預覽。"; return }
                old.title = cleaned; old.content = content; old.dueAt = hasDeadline ? deadline : nil; old.updatedAt = Date()
                old.planAt = plannedDate
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
        ledger.mark([proposal], account: account)
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
        ledger.mark([proposal], account: account)
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
        return entity.updatedAt == old.updatedAt && entity.title == old.title && entity.content == old.content && entity.courseLink == old.courseLink && entity.planAt == old.planAt && entity.status == old.status.rawValue
    }
}

struct AIChangeBatch: Identifiable {
    let id = UUID()
    let proposals: [AIChangeProposal]
    let onComplete: () -> Void
}

/// Batch changes are committed through one Core Data save after resolving all targets.
struct AIChangeBatchReviewView: View {
    let batch: AIChangeBatch
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    @EnvironmentObject private var academic: AcademicSyncStore
    @EnvironmentObject private var ledger: AIChangeExecutionLedger
    @Environment(\.dismiss) private var dismiss
    @State private var proposals: [AIChangeProposal]
    @State private var originalMemos: [Int: Memo] = [:]
    @State private var originalCourses: [Int: Course] = [:]
    @State private var plannedDates: [Int: Date] = [:]
    @State private var memoLinks: [Int: String] = [:]
    @State private var clearedDeadlines: Set<Int> = []
    @State private var account = ""
    @State private var prepared = false
    @State private var error: String?
    @State private var confirming = false
    private let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private let times: [Course.TimeStart] = [.eight,.nine,.ten,.eleven,.thirteen,.fourteen,.fifteen,.sixteen,.seventeen,.eighteen,.nineteen,.twenty,.twentyone]

    init(batch: AIChangeBatch, memoManager: MemoManager, courseData: CourseData) {
        self.batch = batch; self.memoManager = memoManager; self.courseData = courseData
        _proposals = State(initialValue: batch.proposals)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("所有項目會一起儲存；若有衝突或失敗，整批不會變更。刪除 Moodle 待辦不會刪除校方作業。") .font(.caption) }
                ForEach(proposals.indices, id: \.self) { i in
                    Section("\(i + 1). \(title(proposals[i]))") {
                        if let target = proposals[i].target { Text("目標：\(target)").font(.caption) }
                        if let memo = originalMemos[i] {
                            Text("原內容：\(memo.content.isEmpty ? "（空白）" : memo.content)").font(.caption).foregroundStyle(.secondary)
                        }
                        if let course = originalCourses[i] {
                            Text("原時段：\(course.day) · \(course.timeSlot.rawValue) · \(course.location)").font(.caption).foregroundStyle(.secondary)
                        }
                        if proposals[i].operation != .create && originalMemos[i] == nil && originalCourses[i] == nil {
                            Text("找不到唯一目標；請改用逐筆預覽選擇。") .foregroundStyle(.red)
                        }
                        if proposals[i].operation != .delete {
                            TextField("名稱（留空保留原值）", text: field(i, \.title))
                            if proposals[i].kind == .memo {
                                TextField("內容（留空保留原值）", text: field(i, \.content), axis: .vertical)
                                Picker("截止時間", selection: deadlineMode(i)) {
                                    Text(originalMemos[i] == nil ? "不設定" : "保留原時間").tag(0)
                                    Text("設定時間").tag(1)
                                    if originalMemos[i] != nil { Text("移除時間").tag(2) }
                                }
                                if proposals[i].deadline != nil {
                                    DatePicker("截止", selection: deadlineDate(i))
                                    if ISO8601DateFormatter().date(from: proposals[i].deadline ?? "") == nil {
                                        Text("日期無法辨識，請重新選擇。").font(.caption).foregroundStyle(.orange)
                                    }
                                } else if !clearedDeadlines.contains(i), let date = originalMemos[i]?.dueAt {
                                    LabeledContent("原截止", value: date.formatted(date: .abbreviated, time: .shortened))
                                }
                                AIPlanDateField(date: Binding(
                                    get: { plannedDates[i] },
                                    set: { plannedDates[i] = $0 }
                                ))
                                Text(memoReminderSummary(for: i))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("連結課程", selection: Binding(get: { memoLinks[i] ?? "" }, set: { memoLinks[i] = $0 })) {
                                    Text("無").tag("")
                                    ForEach(AICoursePickerOptions.unique(courseData.courses, selected: memoLinks[i] ?? "")) { Text($0.name).tag($0.id) }
                                }
                            } else {
                                Picker("星期（未指定保留原值）", selection: field(i, \.weekday)) {
                                    Text("未指定").tag("")
                                    ForEach(weekdays, id: \.self) { Text($0).tag($0) }
                                }
                                Picker("節次（未指定保留原值）", selection: Binding(get: { proposals[i].period ?? 0 }, set: { proposals[i].period = $0 == 0 ? nil : $0 })) {
                                    Text("未指定").tag(0)
                                    ForEach(1...13, id: \.self) { Text("第 \($0) 節").tag($0) }
                                }
                                TextField("教室（留空保留原值）", text: field(i, \.location))
                                TextField("教師（留空保留原值）", text: field(i, \.teacher))
                            }
                        }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Section { Button("確認全部變更") { confirming = true }.disabled(proposals.isEmpty) }
            }
            .navigationTitle("預覽全部變更")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .onAppear(perform: prepare)
            .onChange(of: academic.uid) { _ in dismiss() }
            .confirmationDialog("確定執行全部 \(proposals.count) 項變更？", isPresented: $confirming, titleVisibility: .visible) {
                Button("確認全部", role: proposals.contains(where: { $0.operation == .delete }) ? .destructive : nil) { apply() }
            }
        }
    }
    private func title(_ p: AIChangeProposal) -> String {
        let action = p.operation == .create ? "新增" : p.operation == .edit ? "修改" : "刪除"
        return action + (p.kind == .memo ? "備忘錄" : "課程")
    }
    private func field(_ i: Int, _ key: WritableKeyPath<AIChangeProposal, String?>) -> Binding<String> {
        Binding(get: { proposals[i][keyPath: key] ?? "" }, set: { proposals[i][keyPath: key] = $0.isEmpty ? nil : $0 })
    }
    private func deadlineMode(_ i: Int) -> Binding<Int> {
        Binding(get: { clearedDeadlines.contains(i) ? 2 : proposals[i].deadline == nil ? 0 : 1 }, set: { mode in
            clearedDeadlines.remove(i)
            if mode == 1 {
                proposals[i].deadline = ISO8601DateFormatter().string(from: originalMemos[i]?.dueAt ?? Date().addingTimeInterval(86400))
            } else {
                proposals[i].deadline = nil
                if mode == 2 { clearedDeadlines.insert(i) }
            }
        })
    }
    private func deadlineDate(_ i: Int) -> Binding<Date> {
        Binding(get: { proposals[i].deadline.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date() },
                set: { proposals[i].deadline = ISO8601DateFormatter().string(from: $0) })
    }
    private func memoReminderSummary(for index: Int) -> String {
        let due = clearedDeadlines.contains(index) ? nil : proposals[index].deadline.flatMap { ISO8601DateFormatter().date(from: $0) } ?? originalMemos[index]?.dueAt
        return AIMemoReminderPreview.text(due: due, plan: plannedDates[index], status: originalMemos[index]?.status ?? .todo, original: originalMemos[index])
    }
    private func prepare() {
        guard !prepared else { return }
        prepared = true; account = academic.uid
        proposals.removeAll { ledger.contains($0, account: account) }
        for i in proposals.indices where proposals[i].kind == .memo && proposals[i].operation == .create {
            memoLinks[i] = AICourseLinkResolver.match(proposals[i], courses: courseData.courses)?.id
        }
        for i in proposals.indices where proposals[i].operation != .create {
            let target = proposals[i].target ?? ""
            if proposals[i].kind == .memo {
                let matches = memoManager.memos.filter { $0.title == target }
                if matches.count == 1 { originalMemos[i] = matches[0]; memoLinks[i] = proposals[i].course.flatMap { _ in AICourseLinkResolver.match(proposals[i], courses: courseData.courses)?.id } ?? matches[0].courseLink ?? "" }
            } else {
                let matches = courseData.courses.filter { $0.name == target }
                if matches.count == 1 { originalCourses[i] = matches[0] }
            }
        }
        for i in proposals.indices where proposals[i].kind == .memo {
            plannedDates[i] = proposals[i].planAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? originalMemos[i]?.planAt
        }
    }
    private func fail(_ message: String) { error = message }
    private func apply() {
        guard academic.uid == account else { fail("帳號已變更，請重新預覽。"); return }
        guard !proposals.isEmpty, !proposals.contains(where: { ledger.contains($0, account: account) }) else {
            fail("部分變更已套用，請關閉後重新預覽剩餘項目。"); return
        }
        guard let context = memoManager.viewContext, context === courseData.viewContext, !context.hasChanges else { fail("資料正在儲存，請稍後重試。"); return }
        var memoIDs = Set<String>(), courseIDs = Set<String>()
        var finalCourses = courseData.courses
        for i in proposals.indices {
            let p = proposals[i]
            if p.operation != .create {
                if p.kind == .memo {
                    guard let old = originalMemos[i], memoIDs.insert(old.id).inserted,
                          memoManager.memos.first(where: { $0.id == old.id }) == old,
                          AIChangeConsistency.memo(old, in: context) else { fail("第 \(i + 1) 筆備忘錄找不到、重複或已變更；請重新預覽。"); return }
                } else {
                    guard let old = originalCourses[i], courseIDs.insert(old.id).inserted,
                          let current = courseData.courses.first(where: { $0.id == old.id }),
                          AIChangeConsistency.course(old, current), AIChangeConsistency.course(old, in: context) else { fail("第 \(i + 1) 筆課程找不到、重複或已變更；請重新預覽。"); return }
                    if p.operation == .delete {
                        let linked: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
                        linked.predicate = NSPredicate(format: "courseLink == %@", old.id); linked.fetchLimit = 1
                        guard let count = try? context.count(for: linked), count == 0,
                              !memoManager.memos.contains(where: { $0.courseLink == old.id }) else {
                            fail("第 \(i + 1) 筆課程有關聯備忘錄或無法確認關聯，請逐筆處理。 "); return
                        }
                    }
                    finalCourses.removeAll { $0.id == old.id }
                }
            }
        }
        var newMemoKeys = Set<String>()
        for i in proposals.indices {
            let p = proposals[i]
            guard p.operation != .delete else { continue }
            let proposedTitle = (p.title ?? (p.kind == .memo ? originalMemos[i]?.title : originalCourses[i]?.name) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !proposedTitle.isEmpty, proposedTitle.count <= 120, (p.content?.count ?? 0) <= 5000 else { fail("第 \(i + 1) 筆名稱或內容不正確。"); return }
            if let deadline = p.deadline, ISO8601DateFormatter().date(from: deadline) == nil { fail("第 \(i + 1) 筆截止時間格式錯誤。"); return }
            if p.kind == .memo, let link = memoLinks[i], !link.isEmpty,
               (!courseData.courses.contains(where: { $0.id == link }) || proposals.indices.contains(where: { proposals[$0].kind == .course && proposals[$0].operation == .delete && originalCourses[$0]?.id == link })) {
                fail("第 \(i + 1) 筆連結的課程不存在或將被刪除。"); return
            }
            if p.kind == .memo && p.operation == .create {
                let key = proposedTitle + "\u{0}" + (p.content ?? "")
                let duplicates: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest()
                duplicates.predicate = NSPredicate(format: "title == %@ AND content == %@", proposedTitle, p.content ?? ""); duplicates.fetchLimit = 1
                guard let count = try? context.count(for: duplicates), count == 0,
                      newMemoKeys.insert(key).inserted, !memoManager.memos.contains(where: { $0.title == proposedTitle && $0.content == (p.content ?? "") }) else {
                    fail("第 \(i + 1) 筆已有相同名稱及內容的備忘錄；如需重複新增請逐筆處理。"); return
                }
            }
            if p.kind == .course {
                let day = p.weekday ?? originalCourses[i]?.day ?? ""
                let period = p.period ?? originalCourses[i].flatMap { Course.TimeSlot.allCases.firstIndex(of: $0.timeSlot).map { $0 + 1 } } ?? 0
                guard weekdays.contains(day), (1...13).contains(period) else { fail("第 \(i + 1) 筆請選擇星期及節次。"); return }
                let slot = Course.TimeSlot.allCases[period - 1]
                guard !finalCourses.contains(where: { $0.day == day && $0.timeSlot == slot }) else { fail("第 \(i + 1) 筆課程時段衝突。"); return }
                finalCourses.append(Course(id: originalCourses[i]?.id ?? UUID().uuidString, name: proposedTitle, day: day, startTime: times[period - 1], timeSlot: slot, location: p.location ?? originalCourses[i]?.location ?? "", teacher: p.teacher ?? originalCourses[i]?.teacher ?? "", isNotification: originalCourses[i]?.isNotification ?? false))
            }
        }
        do {
            for i in proposals.indices {
                let p = proposals[i]
                if p.kind == .memo {
                    let entity: MemoEntity
                    if let old = originalMemos[i] {
                        let request: NSFetchRequest<MemoEntity> = MemoEntity.fetchRequest(); request.predicate = NSPredicate(format: "id == %@", old.id); request.fetchLimit = 1
                        guard let found = try context.fetch(request).first else { throw BatchError.changed }; entity = found
                    } else { entity = MemoEntity(context: context); entity.id = UUID().uuidString; entity.createdAt = Date(); entity.tagType = Memo.TagType.other.rawValue; entity.status = Memo.MemoStatus.todo.rawValue; entity.priority = Memo.Priority.medium.rawValue; entity.reminderRulesData = try JSONEncoder().encode([ReminderRule]()) }
                    if p.operation == .delete { context.delete(entity); continue }
                    entity.title = p.title ?? originalMemos[i]?.title
                    entity.content = p.content ?? originalMemos[i]?.content ?? ""
                    entity.courseLink = (memoLinks[i] ?? "").isEmpty ? nil : memoLinks[i]
                    entity.planAt = plannedDates[i]
                    if clearedDeadlines.contains(i) { entity.dueAt = nil }
                    else if let raw = p.deadline { entity.dueAt = ISO8601DateFormatter().date(from: raw) }
                    entity.updatedAt = Date()
                } else {
                    let entity: CourseEntity
                    if let old = originalCourses[i] {
                        let request: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest(); request.predicate = NSPredicate(format: "id == %@", old.id); request.fetchLimit = 1
                        guard let found = try context.fetch(request).first else { throw BatchError.changed }; entity = found
                    } else { entity = CourseEntity(context: context); entity.id = UUID().uuidString }
                    if p.operation == .delete { context.delete(entity); continue }
                    let day = p.weekday ?? originalCourses[i]?.day ?? ""
                    let period = p.period ?? originalCourses[i].flatMap { Course.TimeSlot.allCases.firstIndex(of: $0.timeSlot).map { $0 + 1 } } ?? 0
                    entity.name = p.title ?? originalCourses[i]?.name; entity.day = day; entity.timeSlot = Course.TimeSlot.allCases[period - 1].rawValue; entity.startTime = times[period - 1].rawValue
                    entity.location = p.location ?? originalCourses[i]?.location ?? ""; entity.teacher = p.teacher ?? originalCourses[i]?.teacher ?? ""; entity.isNotification = originalCourses[i]?.isNotification ?? false
                }
            }
            try context.save()
        } catch { context.rollback(); fail("儲存失敗，所有變更都已取消。請重新預覽。"); return }
        for old in originalMemos.values { memoManager.cancelNotification(for: old) }
        for old in originalCourses.values { courseData.cancelNotification(for: old) }
        memoManager.loadMemosFromCoreData(); courseData.loadCoursesFromCoreData(); memoManager.scheduleNotificationsForAllMemos()
        ledger.mark(proposals, account: account)
        batch.onComplete(); dismiss()
    }
    private enum BatchError: Error { case changed }
}


/// Both preview paths resolve course text to a local ID before saving.
private enum AICourseLinkResolver {
    static func match(_ proposal: AIChangeProposal, courses: [Course]) -> Course? {
        // Timetable records represent periods. Match logical courses, then pick
        // a stable period ID just as the memo editor deduplicates its picker.
        let groups = Dictionary(grouping: courses) { normalized($0.name) + "|" + normalized($0.teacher) }
        let candidates = groups.values.compactMap { $0.sorted { $0.id < $1.id }.first }
        let requested = normalized(proposal.course ?? "")
        if !requested.isEmpty {
            let exact = candidates.filter { normalized($0.name) == requested }
            if exact.count == 1 { return exact[0] }
            if exact.count > 1 { return nil }
            let partial = candidates.filter { nameMatches(requested, normalized($0.name)) }
            if partial.count == 1 { return partial[0] }
            if partial.count > 1 { return nil }
        }
        let text = normalized("\(proposal.course ?? "") \(proposal.title ?? "") \(proposal.content ?? "")")
        let ranked = candidates.compactMap { course -> (Course, Double)? in
            let name = normalized(course.name)
            guard name.count >= 2 else { return nil }
            let score = text.contains(name) ? 1 : similarity(text, name)
            return score >= 0.55 ? (course, score) : nil
        }.sorted { $0.1 > $1.1 }
        guard let best = ranked.first,
              ranked.dropFirst().first.map({ best.1 - $0.1 >= 0.15 }) ?? true else { return nil }
        return best.0
    }
    private static func nameMatches(_ keyword: String, _ name: String) -> Bool {
        keyword.count >= 2 && (keyword.contains(name) || name.contains(keyword))
    }
    private static func similarity(_ text: String, _ name: String) -> Double {
        let a = Array(text), b = Array(name)
        let textGrams = Set(zip(a, a.dropFirst()).map { String([$0, $1]) })
        let nameGrams = Set(zip(b, b.dropFirst()).map { String([$0, $1]) })
        guard !nameGrams.isEmpty else { return 0 }
        return Double(textGrams.intersection(nameGrams).count) / Double(nameGrams.count)
    }
    private static func normalized(_ value: String) -> String {
        value.folding(options: [.widthInsensitive, .caseInsensitive], locale: Locale(identifier: "zh_TW"))
            .filter { !$0.isWhitespace && !$0.isPunctuation }
    }
}

/// Keep one course choice while preserving the exact existing link ID.
enum AICoursePickerOptions {
    static func unique(_ courses: [Course], selected: String) -> [Course] {
        let groups = Dictionary(grouping: courses) { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) + "|" + $0.teacher }
        return groups.values.compactMap { group in
            group.first(where: { $0.id == selected }) ?? group.sorted { $0.id < $1.id }.first
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

enum AIMemoReminderPreview {
    static func text(due: Date?, plan: Date?, status: Memo.MemoStatus, original: Memo?) -> String {
        if status == .done { return "已完成，不會發送提醒。" }
        let now = Date()
        let custom = original?.reminderRules.filter { $0.enabled } ?? []
        var parts: [String] = []
        let pendingCustom = custom.filter { $0.repeatType != .none || $0.triggerAt > now }
        if !pendingCustom.isEmpty {
            parts.append("自訂提醒：" + pendingCustom.prefix(3).map { $0.triggerAt.formatted(date: .abbreviated, time: .shortened) }.joined(separator: "、") + (pendingCustom.count > 3 ? "等 \(pendingCustom.count) 項" : ""))
        }
        if let due, original?.disableAutoDueReminder != true, !custom.contains(where: { $0.kind == .beforeDue }) {
            let dates = [due.addingTimeInterval(-86400), due.addingTimeInterval(-1800)].filter { $0 > now }
            if !dates.isEmpty { parts.append("截止提醒：" + dates.map { $0.formatted(date: .abbreviated, time: .shortened) }.joined(separator: "、")) }
        }
        if let plan, plan > now, original?.disableAutoPlanReminder != true,
           !custom.contains(where: { $0.kind == .atPlan }) {
            parts.append("計劃提醒：" + plan.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.isEmpty ? "沒有待發送的提醒，可儲存後在備忘錄中設定。" : parts.joined(separator: "\n") + "。需允許 App 通知。"

    }
}

private struct AIPlanDateField: View {
    @Binding var date: Date?

    var body: some View {
        Toggle("安排計劃時間", isOn: Binding(
            get: { date != nil },
            set: { date = $0 ? (date ?? Date()) : nil }
        ))
        if let value = date {
            DatePicker("計劃時間", selection: Binding(
                get: { date ?? value },
                set: { date = $0 }
            ))
        }
    }
}
