import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class NextCourseLiveActivityManager {
    static let shared = NextCourseLiveActivityManager()

    nonisolated static let isEnabledKey = "nextCourseLiveActivityEnabled"
    /// 目前先不對一般使用者開放即時課表；保留實作以便日後重新啟用。
    nonisolated static let isFeatureAvailable = false

    private let activityID = "next-course"
    private let calendar = Calendar.current
    private let rolloverLeeway: TimeInterval = 1
    private let periodicRefreshInterval: TimeInterval = 5 * 60
    private var syncGeneration = 0
    private var syncTask: Task<Void, Never>?
    private var rolloverTask: Task<Void, Never>?
    private var periodicRefreshTask: Task<Void, Never>?
    private var adminLiveActivityTest: AdminLiveActivityTest?
    private var adminLiveActivityTestCompletionTask: Task<Void, Never>?
    private var latestCourses: [Course] = []
    private var latestMemos: [Memo] = []
    private var isApplicationActive = true

    private init() {}

    private var isEnabled: Bool {
        Self.isFeatureAvailable
            && (UserDefaults.standard.object(forKey: Self.isEnabledKey) as? Bool ?? false)
    }

    /// 僅供管理後台驗證 Live Activity 的跨課切換；不會寫入使用者課表或通知。
    var isAdminLiveActivityTestRunning: Bool {
        guard let test = adminLiveActivityTest else { return false }
        return Date() < test.endsAt
    }

    var adminLiveActivityTestStartsAt: Date? {
        guard isAdminLiveActivityTestRunning else { return nil }
        return adminLiveActivityTest?.startsAt
    }

    var adminLiveActivityTestEndsAt: Date? {
        guard isAdminLiveActivityTestRunning else { return nil }
        return adminLiveActivityTest?.endsAt
    }

    /// 五分鐘後開始，共五堂，每堂十分鐘、堂間間隔五分鐘。
    func startAdminLiveActivityTest() {
        guard Self.isFeatureAvailable else { return }
        clearAdminLiveActivityTest(restoreLiveActivitySetting: true)

        let now = Date()
        let firstStart = now.addingTimeInterval(5 * 60)
        let courseDuration: TimeInterval = 10 * 60
        let interval: TimeInterval = 15 * 60
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let snapshots = (0..<5).map { index in
            let startsAt = firstStart.addingTimeInterval(TimeInterval(index) * interval)
            let endsAt = startsAt.addingTimeInterval(courseDuration)
            return NextCourseLiveActivitySnapshot(
                courseID: "admin-live-activity-test-\(index + 1)",
                name: "測試課程 \(index + 1)",
                day: "Live Activity 測試",
                startTime: formatter.string(from: startsAt),
                location: "測試教室",
                teacher: "系統測試",
                startsAt: startsAt,
                endsAt: endsAt,
                isInProgress: false
            )
        }

        guard let endsAt = snapshots.last?.endsAt else { return }
        let wasEnabled = isEnabled
        if !wasEnabled {
            UserDefaults.standard.set(true, forKey: Self.isEnabledKey)
        }

        adminLiveActivityTest = AdminLiveActivityTest(
            snapshots: snapshots,
            startsAt: firstStart,
            endsAt: endsAt,
            restoreLiveActivitySetting: !wasEnabled
        )
        syncIfNeeded()

        adminLiveActivityTestCompletionTask = Task { [weak self] in
            guard let self else { return }
            let delay = max(0, endsAt.timeIntervalSinceNow + self.rolloverLeeway)
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }
            self.completeAdminLiveActivityTestIfNeeded()
        }
    }

    func stopAdminLiveActivityTest() {
        guard adminLiveActivityTest != nil else { return }
        clearAdminLiveActivityTest(restoreLiveActivitySetting: true)
        syncIfNeeded()
    }

    func sync(with courses: [Course]) {
        latestCourses = courses
        syncIfNeeded()
    }

    func sync(courses: [Course], memos: [Memo]) {
        latestCourses = courses
        latestMemos = memos
        syncIfNeeded()
    }

    func syncMemos(_ memos: [Memo]) {
        latestMemos = memos
        syncIfNeeded()
    }

    /// Live Activity 不使用遠端推播；App 在前景時才執行本機更新排程。
    func setApplicationActive(_ isActive: Bool) {
        isApplicationActive = isActive

        if isActive {
            syncIfNeeded()
        } else {
            syncGeneration += 1
            syncTask?.cancel()
            syncTask = nil
            rolloverTask?.cancel()
            rolloverTask = nil
            periodicRefreshTask?.cancel()
            periodicRefreshTask = nil
        }
    }

    func setEnabled(_ isEnabled: Bool, courses: [Course], memos: [Memo]) {
        clearAdminLiveActivityTest(restoreLiveActivitySetting: false)
        UserDefaults.standard.set(Self.isFeatureAvailable && isEnabled, forKey: Self.isEnabledKey)
        latestCourses = courses
        latestMemos = memos

        if Self.isFeatureAvailable && isEnabled {
            syncIfNeeded()
        } else {
            stop()
        }
    }

    private func syncIfNeeded() {
        if adminLiveActivityTest != nil, !isAdminLiveActivityTestRunning {
            completeAdminLiveActivityTestIfNeeded()
            return
        }

        guard isEnabled else {
            stop()
            return
        }
        guard isApplicationActive else { return }
        ensurePeriodicRefresh()

        let timeline = adminLiveActivityTest
            .map { adminLiveActivityTestTimeline(from: $0) }
            ?? nextCourseTimeline(from: latestCourses)
        let todos = urgentTodayTodos(from: latestMemos)
        syncGeneration += 1
        let generation = syncGeneration
        let previousSyncTask = syncTask

        syncTask?.cancel()
        rolloverTask?.cancel()

        guard #available(iOS 16.1, *) else { return }

        syncTask = Task { [weak self] in
            await previousSyncTask?.value
            await self?.syncActivity(timeline: timeline, todos: todos, generation: generation)
        }
    }

    private func stop() {
        syncGeneration += 1
        syncTask?.cancel()
        rolloverTask?.cancel()
        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil

        guard #available(iOS 16.1, *) else { return }

        Task { [weak self] in
            guard let self else { return }
            await self.end(Activity<NextCourseLiveActivityAttributes>.activities)
        }
    }

    private func completeAdminLiveActivityTestIfNeeded() {
        guard adminLiveActivityTest != nil else { return }
        clearAdminLiveActivityTest(restoreLiveActivitySetting: true)
        syncIfNeeded()
    }

    private func clearAdminLiveActivityTest(restoreLiveActivitySetting: Bool) {
        let test = adminLiveActivityTest
        adminLiveActivityTest = nil
        adminLiveActivityTestCompletionTask?.cancel()
        adminLiveActivityTestCompletionTask = nil

        if restoreLiveActivitySetting, test?.restoreLiveActivitySetting == true {
            UserDefaults.standard.set(false, forKey: Self.isEnabledKey)
        }
    }

    private func ensurePeriodicRefresh() {
        guard isApplicationActive, periodicRefreshTask == nil else { return }
        let interval = periodicRefreshInterval

        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    return
                }

                guard !Task.isCancelled else { return }
                self?.periodicRefreshTick()
            }
        }
    }

    private func periodicRefreshTick() {
        guard isEnabled, isApplicationActive else {
            periodicRefreshTask?.cancel()
            periodicRefreshTask = nil
            return
        }

        syncIfNeeded()
    }

    @available(iOS 16.1, *)
    private func syncActivity(
        timeline: NextCourseTimeline,
        todos: [NextCourseLiveActivityTodoSnapshot],
        generation: Int
    ) async {
        let activities = Activity<NextCourseLiveActivityAttributes>.activities

        guard generation == syncGeneration, !Task.isCancelled else { return }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await end(activities)
            return
        }

        let state = NextCourseLiveActivityAttributes.ContentState(
            course: timeline.course,
            nextCourse: timeline.nextCourse,
            upcomingCourses: timeline.upcomingCourses,
            todos: todos,
            updatedAt: Date()
        )
        let staleDate = timeline.nextRefreshAt

        if let activity = activities.first {
            guard generation == syncGeneration, !Task.isCancelled else { return }
            await update(activity, with: state, staleDate: staleDate)
        } else {
            guard generation == syncGeneration, !Task.isCancelled else { return }
            request(with: state, staleDate: staleDate)
        }

        guard generation == syncGeneration, !Task.isCancelled else { return }

        for extraActivity in activities.dropFirst() {
            await end(extraActivity, finalState: state, staleDate: staleDate)
        }

        guard generation == syncGeneration, !Task.isCancelled else { return }
        scheduleRollover(after: staleDate, generation: generation)
    }

    @available(iOS 16.1, *)
    private func end(_ activities: [Activity<NextCourseLiveActivityAttributes>]) async {
        for activity in activities {
            await end(activity, finalState: nil, staleDate: nil)
        }
    }

    @available(iOS 16.1, *)
    private func update(
        _ activity: Activity<NextCourseLiveActivityAttributes>,
        with state: NextCourseLiveActivityAttributes.ContentState,
        staleDate: Date
    ) async {
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: state, staleDate: staleDate, relevanceScore: 1.0)
            await activity.update(content)
        } else {
            await activity.update(using: state)
        }
    }

    @available(iOS 16.1, *)
    private func request(with state: NextCourseLiveActivityAttributes.ContentState, staleDate: Date) {
        do {
            let activity: Activity<NextCourseLiveActivityAttributes>
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: staleDate, relevanceScore: 1.0)
                activity = try Activity.request(
                    attributes: NextCourseLiveActivityAttributes(activityID: activityID),
                    content: content,
                    pushType: nil
                )
            } else {
                activity = try Activity.request(
                    attributes: NextCourseLiveActivityAttributes(activityID: activityID),
                    contentState: state,
                    pushType: nil
                )
            }
        } catch {
            print("Failed to start next course Live Activity: \(error.localizedDescription)")
        }
    }

    @available(iOS 16.1, *)
    private func end(
        _ activity: Activity<NextCourseLiveActivityAttributes>,
        finalState: NextCourseLiveActivityAttributes.ContentState?,
        staleDate: Date?
    ) async {
        if #available(iOS 16.2, *) {
            let content = finalState.map { ActivityContent(state: $0, staleDate: staleDate, relevanceScore: 0) }
            await activity.end(content, dismissalPolicy: .immediate)
        } else {
            await activity.end(using: finalState, dismissalPolicy: .immediate)
        }
    }

    @available(iOS 16.1, *)
    private func scheduleRollover(after boundary: Date, generation: Int) {
        guard isApplicationActive else { return }
        rolloverTask = Task { [weak self] in
            guard let self else { return }
            let refreshDate = boundary.addingTimeInterval(self.rolloverLeeway)
            let delay = max(0, refreshDate.timeIntervalSinceNow)

            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }

            guard generation == self.syncGeneration, self.isApplicationActive else { return }
            self.syncIfNeeded()
        }
    }

    private func nextDayStart(after date: Date = Date()) -> Date {
        let today = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? Date().addingTimeInterval(24 * 60 * 60)
    }

    private struct NextCourseTimeline {
        let course: NextCourseLiveActivitySnapshot?
        let nextCourse: NextCourseLiveActivitySnapshot?
        let upcomingCourses: [NextCourseLiveActivitySnapshot]
        let nextRefreshAt: Date
    }

    private struct AdminLiveActivityTest {
        let snapshots: [NextCourseLiveActivitySnapshot]
        let startsAt: Date
        let endsAt: Date
        let restoreLiveActivitySetting: Bool
    }

    private func adminLiveActivityTestTimeline(from test: AdminLiveActivityTest, now: Date = Date()) -> NextCourseTimeline {
        let remaining = test.snapshots.filter { $0.endsAt > now }
        let snapshots = remaining.map { snapshot in
            snapshot.withProgress(snapshot.startsAt <= now && now < snapshot.endsAt)
        }

        return NextCourseTimeline(
            course: snapshots.first,
            nextCourse: snapshots.dropFirst().first,
            upcomingCourses: snapshots,
            nextRefreshAt: nextRefreshBoundary(for: snapshots, now: now)
        )
    }

    private func nextCourseTimeline(from courses: [Course], now: Date = Date()) -> NextCourseTimeline {
        let candidates = courseCandidates(from: courses, now: now)
            .sorted { $0.startsAt < $1.startsAt }

        let remaining = candidates.filter { $0.endsAt > now }
        if !remaining.isEmpty {
            // 讓 Widget 在 App 進入背景後仍能依日期自行切換每一堂課，而不是只帶第一、二堂。
            let snapshots = remaining.map { candidate in
                snapshot(from: candidate, isInProgress: candidate.startsAt <= now && now < candidate.endsAt)
            }
            return NextCourseTimeline(
                course: snapshots.first,
                nextCourse: snapshots.dropFirst().first,
                upcomingCourses: snapshots,
                nextRefreshAt: nextRefreshBoundary(for: snapshots, now: now)
            )
        }

        return NextCourseTimeline(
            course: nil,
            nextCourse: nil,
            upcomingCourses: [],
            nextRefreshAt: nextDayStart(after: now)
        )
    }

    private func nextRefreshBoundary(
        for snapshots: [NextCourseLiveActivitySnapshot],
        now: Date
    ) -> Date {
        guard let current = snapshots.first else { return nextDayStart(after: now) }
        if now < current.startsAt { return current.startsAt }
        if now < current.endsAt { return current.endsAt }
        return nextDayStart(after: now)
    }

    private func courseCandidates(from courses: [Course], now: Date) -> [(course: Course, startsAt: Date, endsAt: Date)] {
        courses.compactMap { course -> (course: Course, startsAt: Date, endsAt: Date)? in
            guard let timeRange = timeRange(for: course, on: now) else { return nil }
            return (course, timeRange.startsAt, timeRange.endsAt)
        }
    }

    private func snapshot(
        from candidate: (course: Course, startsAt: Date, endsAt: Date),
        isInProgress: Bool
    ) -> NextCourseLiveActivitySnapshot {
        NextCourseLiveActivitySnapshot(
            courseID: candidate.course.id,
            name: candidate.course.name,
            day: candidate.course.day,
            startTime: candidate.course.startTime.rawValue,
            location: candidate.course.location,
            teacher: candidate.course.teacher,
            startsAt: candidate.startsAt,
            endsAt: candidate.endsAt,
            isInProgress: isInProgress
        )
    }

    private func timeRange(for course: Course, on currentDate: Date) -> (startsAt: Date, endsAt: Date)? {
        guard let weekday = weekday(from: course.day),
              let start = time(from: course.startTime, timeSlot: course.timeSlot),
              let end = endTime(from: course.timeSlot) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day, .weekday], from: currentDate)
        guard components.weekday == weekday else { return nil }

        components.hour = start.hour
        components.minute = start.minute
        components.second = 0
        guard let startsAt = calendar.date(from: components) else { return nil }

        components.hour = end.hour
        components.minute = end.minute
        components.second = 0
        guard let endsAt = calendar.date(from: components), endsAt > startsAt else { return nil }

        return (startsAt, endsAt)
    }

    private func urgentTodayTodos(from memos: [Memo]) -> [NextCourseLiveActivityTodoSnapshot] {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(24 * 60 * 60)

        return memos.filter { memo in
            guard memo.status != .done else { return false }
            if memo.isOverdue { return true }
            if let dueAt = memo.dueAt, dueAt >= today && dueAt < tomorrow { return true }
            if let planAt = memo.planAt, planAt >= today && planAt < tomorrow { return true }
            return false
        }
        .sorted { first, second in
            if first.isOverdue != second.isOverdue { return first.isOverdue }
            if first.priority.sortOrder != second.priority.sortOrder {
                return first.priority.sortOrder < second.priority.sortOrder
            }

            let firstDate = first.dueAt ?? first.planAt ?? Date.distantFuture
            let secondDate = second.dueAt ?? second.planAt ?? Date.distantFuture
            if firstDate != secondDate { return firstDate < secondDate }

            return first.updatedAt > second.updatedAt
        }
        .prefix(3)
        .map { memo in
            NextCourseLiveActivityTodoSnapshot(
                id: memo.id,
                title: memo.title,
                detail: todoDetail(for: memo),
                priority: memo.priority.sortOrder,
                isOverdue: memo.isOverdue
            )
        }
    }

    private func todoDetail(for memo: Memo) -> String {
        if memo.isOverdue { return String(localized: "overdue") }
        if let dueAt = memo.dueAt { return timeText(dueAt) }
        if let planAt = memo.planAt { return timeText(planAt) }
        return memo.priority.displayName
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func weekday(from day: String) -> Int? {
        switch day.lowercased() {
        case "monday": return 2
        case "tuesday": return 3
        case "wednesday": return 4
        case "thursday": return 5
        case "friday": return 6
        case "saturday": return 7
        case "sunday": return 1
        default: return nil
        }
    }

    private func time(from startTime: Course.TimeStart, timeSlot: Course.TimeSlot) -> (hour: Int, minute: Int)? {
        switch startTime {
        case .eight: return (8, 10)
        case .nine: return (9, 10)
        case .ten: return (10, 10)
        case .eleven: return (11, 10)
        case .thirteen: return (13, 10)
        case .fourteen: return (14, 10)
        case .fifteen: return (15, 10)
        case .sixteen: return (16, 10)
        case .seventeen: return (17, 10)
        case .eighteen: return (18, 30)
        case .nineteen: return (19, 25)
        case .twenty: return (20, 25)
        case .twentyone: return (21, 20)
        case .none: return time(from: timeSlot)
        }
    }

    private func time(from timeSlot: Course.TimeSlot) -> (hour: Int, minute: Int)? {
        switch timeSlot {
        case .morning1: return (8, 10)
        case .morning2: return (9, 10)
        case .morning3: return (10, 10)
        case .morning4: return (11, 10)
        case .afternoon1: return (13, 10)
        case .afternoon2: return (14, 10)
        case .afternoon3: return (15, 10)
        case .afternoon4: return (16, 10)
        case .afternoon5: return (17, 10)
        case .evening1: return (18, 30)
        case .evening2: return (19, 25)
        case .evening3: return (20, 25)
        case .evening4: return (21, 20)
        }
    }

    private func endTime(from timeSlot: Course.TimeSlot) -> (hour: Int, minute: Int)? {
        switch timeSlot {
        case .morning1: return (9, 0)
        case .morning2: return (10, 0)
        case .morning3: return (11, 0)
        case .morning4: return (12, 0)
        case .afternoon1: return (14, 0)
        case .afternoon2: return (15, 0)
        case .afternoon3: return (16, 0)
        case .afternoon4: return (17, 0)
        case .afternoon5: return (18, 0)
        case .evening1: return (19, 20)
        case .evening2: return (20, 15)
        case .evening3: return (21, 15)
        case .evening4: return (22, 10)
        }
    }
}

private extension NextCourseLiveActivitySnapshot {
    func withProgress(_ isInProgress: Bool) -> NextCourseLiveActivitySnapshot {
        NextCourseLiveActivitySnapshot(
            courseID: courseID,
            name: name,
            day: day,
            startTime: startTime,
            location: location,
            teacher: teacher,
            startsAt: startsAt,
            endsAt: endsAt,
            isInProgress: isInProgress
        )
    }
}
