import Foundation
import SwiftUI
import CoreData
import FirebaseAuth
import SwiftSoup
import WebKit

struct AcademicRemoteTask: Codable, Identifiable {
    var id: Int
    var courseCode: String
    var courseName: String
    var title: String
    var description: String
    var due: Date?
    var url: URL
    var status: String
    var reliableSubmitted: Bool
    var version: String
    var sourceMissing: Bool? = nil
    var isTeam: Bool? = nil
}
struct AcademicMemoRecord: Codable {
    var memoID: String
    var lastTitle: String
    var lastDue: Date?
    var acknowledgedVersion: String?
    var managedCourseLink: Bool? = nil
    var lastCourseLink: String? = nil
    var lastContent: String? = nil
    var lastTagType: String? = nil
}
struct AcademicCachedCourse: Codable, Identifiable {
    var code: String
    var name: String
    var teacher: String
    var schedule: String
    var id: String { code }
}
struct AcademicCache: Codable {
    var prompted = false
    var schoolIdentity: String?
    var year: String?
    var term: String?
    var lastSemesterHint: String?
    var schoolCheckedAt: Date?
    var moodleCheckedAt: Date?
    var moodleUser: Int?
    var moodleCourses: [MoodleCourse]?
    var reports: [SchoolReport]?
    var courses: [AcademicCachedCourse] = []
    var tasks: [AcademicRemoteTask] = []
    var memoRecords: [String: AcademicMemoRecord] = [:]
    var courseRecords: [String: [String]] = [:]
    var courseSnapshots: [String: String] = [:]
}

@MainActor
final class AcademicSyncStore: ObservableObject {
    @Published private(set) var cache = AcademicCache()
    @Published private(set) var uid = ""
    @Published private(set) var schoolLinked = false
    @Published private(set) var moodleLinked = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var reportErrors: [SchoolReportKind: String] = [:]
    @Published var showConnection = false
    private(set) var moodleWebDataStore = WKWebsiteDataStore.nonPersistent()
    var sourceScope: String { "\(uid):\(cache.moodleUser ?? -1)" }
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var generation = UUID()
    private var lastAttempt: Date?
    private var failures: [String: Int] = [:]
    private var retryDates: [String: Date] = [:]
    private var storageAvailable = true
    private var requiresMoodleLogin = false
    private var requiresSchoolLogin = false
    private weak var memoManager: MemoManager?
    private weak var courseData: CourseData?

    func start(memos: MemoManager, courses: CourseData) {
        memoManager = memos; courseData = courses
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.configure(user?.uid ?? "") }
        }
    }
    private func credentialKey(_ source: String) -> String { AcademicKeychain.key("\(uid):\(source)") }
    private func cacheURL() throws -> URL {
        guard !uid.isEmpty else { throw AcademicError.loginRequired }
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Academic", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var directory = root
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return root.appendingPathComponent(AcademicKeychain.key(uid) + ".json")
    }
    private func persist() throws {
        guard storageAvailable else { throw AcademicError.storage }
        do { try JSONEncoder().encode(cache).write(to: cacheURL(), options: [.atomic, .completeFileProtection]) }
        catch { throw AcademicError.storage }
    }
    private func configure(_ newUID: String) {
        guard newUID != uid else { return }
        generation = UUID(); uid = newUID; cache = AcademicCache(); busy = false; message = nil
        showConnection = false; lastAttempt = nil; storageAvailable = true
        reportErrors = [:]; failures = [:]; retryDates = [:]
        moodleWebDataStore = .nonPersistent()
        schoolLinked = false; moodleLinked = false; requiresMoodleLogin = false; requiresSchoolLogin = false
        guard !uid.isEmpty else { return }
        do {
            let url = try cacheURL()
            if FileManager.default.fileExists(atPath: url.path) {
                cache = try JSONDecoder().decode(AcademicCache.self, from: Data(contentsOf: url))
            }
            schoolLinked = try AcademicKeychain.load(SchoolCredential.self, account: credentialKey("school")) != nil
            moodleLinked = try AcademicKeychain.load(MoodleCredential.self, account: credentialKey("moodle")) != nil
        } catch { storageAvailable = false; message = AcademicError.storage.localizedDescription }
        Task { await migrateCachedReports(); reconcileImportedMemos(); await refresh() }
    }
    func offerConnectionIfNeeded() {
        guard !uid.isEmpty, !cache.prompted, storageAvailable else { return }
        showConnection = true
        cache.prompted = true
        do { try persist() } catch { message = AcademicError.storage.localizedDescription }
    }
    private func check(_ expected: UUID) throws {
        guard generation == expected, Auth.auth().currentUser?.uid == uid, !uid.isEmpty else { throw CancellationError() }
        try Task.checkCancellation()
    }
    private func show(_ error: Error) {
        if error is CancellationError { return }
        message = (error as? AcademicError)?.localizedDescription ?? "連線暫時失敗，已保留原有資料，稍後可重新整理。"
    }
    func connectSchool(username: String, password: String) async -> Bool {
        guard !uid.isEmpty, Auth.auth().currentUser?.uid == uid, !busy, storageAvailable else { return false }
        busy = true; message = nil
        let epoch = generation
        defer { if epoch == generation { busy = false } }
        do {
            let credential = SchoolCredential(username: username, password: password)
            let api = SchoolAPI()
            let enrolment = try await api.enrolment(credential)
            try check(epoch)
            let identity = AcademicKeychain.key(enrolment.identity)
            guard cache.schoolIdentity == nil || cache.schoolIdentity == identity else { throw AcademicError.identityChanged }
            if moodleLinked, let moodle = try AcademicKeychain.load(MoodleCredential.self, account: credentialKey("moodle")),
               let previousIdentity = moodle.schoolIdentity, previousIdentity != identity { throw AcademicError.identityChanged }
            let catalog = try await fetchCatalog(enrolment, epoch: epoch)
            try check(epoch)
            try AcademicKeychain.save(credential, account: credentialKey("school"))
            cache.schoolIdentity = identity; cache.year = enrolment.year; cache.term = enrolment.term
            cache.lastSemesterHint = AcademicPolicy.currentTerm()
            cache.courses = catalog; cache.schoolCheckedAt = Date()
            try persist(); schoolLinked = true; requiresSchoolLogin = false
            message = "已取得 \(catalog.count) 門已核准課程；請先檢查課表預覽，再決定是否匯入。"
            await refreshReports(api: api, credential: credential, epoch: epoch, force: true)
            return true
        } catch { if epoch == generation { show(error) }; return false }
    }
    private func fetchCatalog(_ enrolment: SchoolEnrolment, epoch: UUID) async throws -> [AcademicCachedCourse] {
        var result: [AcademicCachedCourse] = []
        for row in enrolment.courses {
            let matches = try await CourseCatalogService.search(year: enrolment.year, term: enrolment.term, code: row.code).filter { $0.courseno == row.code }
            try check(epoch)
            guard matches.count == 1, let course = matches.first else { throw AcademicError.unsupported }
            result.append(.init(code: row.code, name: course.courseName, teacher: course.teacher,
                                schedule: course.scheduleText ?? "\(course.time) \(course.location)"))
        }
        guard !result.isEmpty else { throw AcademicError.invalidResponse }
        return result
    }
    func connectMoodle(username: String, password: String) async -> Bool {
        guard !uid.isEmpty, Auth.auth().currentUser?.uid == uid, !busy, storageAvailable else { return false }
        busy = true; message = nil
        let epoch = generation
        defer { if epoch == generation { busy = false } }
        do {
            let credential = try await MoodleAPI().login(username: username, password: password)
            try check(epoch)
            guard cache.moodleUser == nil || cache.moodleUser == credential.userID else { throw AcademicError.identityChanged }
            guard cache.schoolIdentity == nil || cache.schoolIdentity == credential.schoolIdentity else { throw AcademicError.identityChanged }
            try AcademicKeychain.save(credential, account: credentialKey("moodle"))
            cache.moodleUser = credential.userID; cache.moodleCheckedAt = nil
            try persist(); moodleLinked = true; requiresMoodleLogin = false
            do { try await refreshMoodle(epoch: epoch) } catch { show(error) }
            return true
        } catch { if epoch == generation { show(error) }; return false }
    }
    func unlink() {
        guard !uid.isEmpty, Auth.auth().currentUser?.uid == uid, !busy else { return }
        do {
            try AcademicKeychain.delete(account: credentialKey("school"))
            try AcademicKeychain.delete(account: credentialKey("moodle"))
            generation = UUID(); schoolLinked = false; moodleLinked = false
            moodleWebDataStore = .nonPersistent()
            cache.schoolIdentity = nil; cache.moodleUser = nil
            cache.year = nil; cache.term = nil; cache.courses = []; cache.tasks = []; cache.moodleCourses = nil
            cache.reports = nil; reportErrors = [:]
            cache.schoolCheckedAt = nil; cache.moodleCheckedAt = nil
            // Retain provenance/tombstones to avoid resurrecting deleted tasks on reconnect.
            try persist(); message = "已解除本機連結，保留已匯入的課表與待辦。"
        } catch { show(error) }
    }
    func refresh(force: Bool = false) async {
        guard !uid.isEmpty, Auth.auth().currentUser?.uid == uid, !busy, storageAvailable, schoolLinked || moodleLinked else { return }
        if !force, !AcademicPolicy.needsRefresh(last: lastAttempt, interval: 60) { return }
        busy = true; lastAttempt = Date()
        let epoch = generation
        defer { if epoch == generation { busy = false } }
        message = nil
        let schoolAPI = SchoolAPI()
        let semesterChanged = cache.lastSemesterHint != AcademicPolicy.currentTerm()
        if schoolLinked, !requiresSchoolLogin, force || retryAllowed("school"),
           force || AcademicPolicy.needsRefresh(last: cache.schoolCheckedAt, interval: 30 * 86400) || semesterChanged {
            do {
                guard let credential = try AcademicKeychain.load(SchoolCredential.self, account: credentialKey("school")) else { throw AcademicError.loginRequired }
                let enrolment = try await schoolAPI.enrolment(credential)
                try check(epoch)
                guard AcademicKeychain.key(enrolment.identity) == cache.schoolIdentity else { throw AcademicError.identityChanged }
                let catalog = try await fetchCatalog(enrolment, epoch: epoch)
                try check(epoch)
                cache.courses = catalog; cache.year = enrolment.year; cache.term = enrolment.term
                cache.lastSemesterHint = AcademicPolicy.currentTerm()
                cache.schoolCheckedAt = Date(); try persist(); resetRetry("school")
            } catch {
                guard epoch == generation else { return }
                if case AcademicError.loginRequired = error { requiresSchoolLogin = true }
                show(error)
                backOff("school")
            }
        }
        guard epoch == generation else { return }
        if moodleLinked, !requiresMoodleLogin, force || retryAllowed("moodle"),
           force || AcademicPolicy.needsRefresh(last: cache.moodleCheckedAt, interval: 300) {
            do { try await refreshMoodle(epoch: epoch); resetRetry("moodle") }
            catch {
                guard epoch == generation else { return }
                if case AcademicError.loginRequired = error { requiresMoodleLogin = true }
                show(error)
                backOff("moodle")
            }
        }
        guard epoch == generation else { return }
        if schoolLinked, !requiresSchoolLogin,
           let credential = try? AcademicKeychain.load(SchoolCredential.self, account: credentialKey("school")) {
            await refreshReports(api: schoolAPI, credential: credential, epoch: epoch, force: force)
        }
    }
    private func retryAllowed(_ source: String) -> Bool { retryDates[source].map { $0 <= Date() } ?? true }
    private func resetRetry(_ source: String) { failures[source] = nil; retryDates[source] = nil }
    private func backOff(_ source: String) {
        let count = min(5, (failures[source] ?? 0) + 1)
        failures[source] = count
        retryDates[source] = Date().addingTimeInterval(min(900, 60 * pow(2, Double(count - 1))))
    }
    private func refreshReports(api: SchoolAPI, credential: SchoolCredential, epoch: UUID, force: Bool, only: SchoolReportKind? = nil) async {
        guard let identity = cache.schoolIdentity else { return }
        for kind in SchoolReportKind.allCases where only == nil || only == kind {
            let source = "reports.\(kind.rawValue)"
            if !force && !retryAllowed(source) { continue }
            let previous = cache.reports?.first { $0.kind == kind }
            if !force && previous?.isNative == true && !AcademicPolicy.needsRefresh(last: previous?.checkedAt, interval: 86400) { continue }
            do {
                let report = try await api.report(kind, credential: credential, expectedIdentity: identity)
                try check(epoch)
                var reports = cache.reports ?? []
                reports.removeAll { $0.kind == kind }; reports.append(report); cache.reports = reports
                try persist(); reportErrors[kind] = nil; resetRetry(source)
            } catch {
                guard epoch == generation else { return }
                reportErrors[kind] = "暫時無法更新\(kind.title)，保留上次成功結果。"
                backOff(source)
                if case AcademicError.loginRequired = error { requiresSchoolLogin = true; return }
            }
        }
    }
    private func migrateCachedReports() async {
        let epoch = generation
        let previous = cache.reports ?? []
        guard previous.contains(where: { !$0.isNative }) else { return }
        // Build 12 stored static HTML. Parse it away from first presentation/the main actor.
        let converted = await Task.detached(priority: .utility) {
            previous.compactMap { try? $0.migrated() }
        }.value
        guard epoch == generation, Auth.auth().currentUser?.uid == uid else { return }
        var reports = cache.reports ?? []
        for report in converted {
            if let index = reports.firstIndex(where: { $0.kind == report.kind && !$0.isNative && $0.checkedAt == report.checkedAt }) {
                reports[index] = report
            }
        }
        cache.reports = reports
        do { try persist() } catch { show(error) }
    }
    func prepareReport(_ kind: SchoolReportKind) async {
        await migrateCachedReports()
        guard cache.reports?.contains(where: { $0.kind == kind && $0.isNative }) != true else { return }
        await refreshReport(kind)
    }
    func refreshReport(_ kind: SchoolReportKind) async {
        guard Auth.auth().currentUser?.uid == uid, !busy, schoolLinked, storageAvailable else { return }
        let epoch = generation; busy = true
        defer { if epoch == generation { busy = false } }
        do {
            guard let credential = try AcademicKeychain.load(SchoolCredential.self, account: credentialKey("school")) else { throw AcademicError.loginRequired }
            await refreshReports(api: SchoolAPI(), credential: credential, epoch: epoch, force: true, only: kind)
        } catch { if epoch == generation { show(error) } }
    }
    private func refreshMoodle(epoch: UUID) async throws {
        guard let year = cache.year, let term = cache.term, !cache.courses.isEmpty else {
            message = "請先連結校務系統，核對正式學期與課號後再同步 Moodle 作業。"; return
        }
        guard let credential = try AcademicKeychain.load(MoodleCredential.self, account: credentialKey("moodle")),
              credential.userID == cache.moodleUser else { throw AcademicError.loginRequired }
        let api = MoodleAPI()
        let allCourses = try await api.courses(credential)
        try check(epoch)
        guard api.verifiedSchoolIdentity == cache.schoolIdentity else { throw AcademicError.identityChanged }
        let courseCodes = Set(cache.courses.map(\.code))
        let termPattern = try NSRegularExpression(pattern: "(?:^|[^0-9])\(year)[-_]?\(term)(?:[^0-9]|$)")
        func matchesTerm(_ course: MoodleCourse) -> Bool {
            [course.fullname, course.shortname ?? "", course.idnumber ?? ""].filter {
                termPattern.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil
            }.count >= 2
        }
        var remote: [AcademicRemoteTask] = []
        var matchedCourses: [MoodleCourse] = []
        var matchedCodes: Set<String> = []
        for course in allCourses where matchesTerm(course) {
            let codes = courseCodes.filter { course.fullname.contains("(\($0))") }
            guard codes.count == 1, let code = codes.first else { continue }
            guard matchedCodes.insert(code).inserted else { throw AcademicError.invalidResponse }
            matchedCourses.append(course)
            for assignment in try await api.assignments(course: course, credential: credential) {
                try check(epoch)
                let status: MoodleSubmission = try await api.call("mod_assign_get_submission_status", token: credential.token, fields: ["assignid": String(assignment.id)])
                try check(epoch)
                guard status.warnings?.isEmpty != false else { throw AcademicError.invalidResponse }
                let attempt = status.lastattempt
                let submission = assignment.teamsubmission != 0 ? attempt?.teamsubmission : attempt?.submission
                let known = ["new", "draft", "submitted", "reopened"]
                let value = known.contains(submission?.status ?? "") ? submission!.status : "unknown"
                let due = max(assignment.duedate, attempt?.extensionduedate ?? 0)
                var task = AcademicRemoteTask(id: assignment.id, courseCode: code, courseName: course.fullname,
                    title: assignment.name, description: try SwiftSoup.parseBodyFragment(assignment.intro).text(),
                    due: due > 0 ? Date(timeIntervalSince1970: due) : nil, url: assignment.url, status: value,
                    reliableSubmitted: AcademicPolicy.reliableSubmission(status: value, isTeam: assignment.teamsubmission != 0),
                    version: "\(assignment.id):\(submission?.attemptnumber ?? -1):\(submission?.timemodified ?? 0):\(value)")
                task.isTeam = assignment.teamsubmission != 0
                remote.append(task)
            }
        }
        guard !matchedCourses.isEmpty, Set(remote.map(\.id)).count == remote.count else { throw AcademicError.invalidResponse }
        try check(epoch)
        try mergeTasks(remote, userID: credential.userID)
        let returnedIDs = Set(remote.map(\.id))
        let missing = cache.tasks.filter { !returnedIDs.contains($0.id) }.map { old -> AcademicRemoteTask in
            var old = old; old.sourceMissing = true; old.reliableSubmitted = false; return old
        }
        cache.tasks = remote + missing; cache.moodleCourses = matchedCourses; cache.moodleCheckedAt = Date(); try persist()
    }
    private func memoKey(_ task: AcademicRemoteTask, userID: Int) -> String { "\(userID):\(task.id)" }
    private func stableID(_ key: String) -> String {
        let hex = String(AcademicKeychain.key("\(uid):\(key)").prefix(32))
        let a = Array(hex)
        return [String(a[0..<8]), String(a[8..<12]), String(a[12..<16]), String(a[16..<20]), String(a[20..<32])].joined(separator: "-")
    }
    private func matchingCourseLink(_ task: AcademicRemoteTask) -> String? {
        guard let data = courseData else { return nil }
        if let id = cache.courseRecords[sourceKey(task.courseCode)]?.first(where: { id in data.courses.contains { $0.id == id } }) { return id }
        guard let source = cache.courses.first(where: { $0.code == task.courseCode }) else { return nil }
        let matches = data.courses.filter {
            AcademicMemoMergePolicy.courseName($0.name) == AcademicMemoMergePolicy.courseName(source.name) &&
            (source.teacher.isEmpty || $0.teacher.isEmpty || $0.teacher == source.teacher)
        }
        guard Set(matches.map(\.teacher)).count <= 1 else { return nil }
        return matches.sorted { $0.id < $1.id }.first?.id
    }
    func reconcileImportedMemos() {
        guard Auth.auth().currentUser?.uid == uid, !busy, let user = cache.moodleUser else { return }
        do { try mergeTasks(cache.tasks.filter { $0.sourceMissing != true }, userID: user); try persist() }
        catch { show(error) }
    }
    private func mergeTasks(_ remote: [AcademicRemoteTask], userID: Int) throws {
        guard let manager = memoManager, let context = manager.viewContext, !context.hasChanges else { throw AcademicError.storage }
        var nextRecords = cache.memoRecords
        // Managers report save failures; verify the persisted row before acknowledging a mapping.
        for task in remote {
            let key = memoKey(task, userID: userID), old = nextRecords[key]
            let id = old?.memoID ?? stableID("moodle:\(key)")
            let existing = manager.memos.first { $0.id == id }
            let sourceCourseLink = matchingCourseLink(task)
            if old != nil && existing == nil { continue } // User-deleted: never recreate.
            if var memo = existing {
                if let old {
                    let previous = memo
                    if (old.managedCourseLink == true || (old.managedCourseLink == nil && memo.courseLink == nil)) && memo.courseLink == old.lastCourseLink { memo.courseLink = sourceCourseLink }
                    if memo.title == old.lastTitle { memo.title = task.title }
                    memo.content = AcademicMemoMergePolicy.content(existing: memo.content, previous: old.lastContent, incoming: task.description)
                    if memo.tagType.rawValue == (old.lastTagType ?? Memo.TagType.homework.rawValue) { memo.tagType = .moodle }
                    if memo.dueAt == old.lastDue {
                        memo.dueAt = task.due
                        memo.reminderRules = memo.reminderRules.compactMap { rule in
                            guard rule.id.hasPrefix("academic."), let offset = Double(rule.id.dropFirst("academic.".count)),
                                  let previous = old.lastDue,
                                  rule.triggerAt == previous.addingTimeInterval(-offset) else { return rule }
                            guard let due = task.due else { return nil }
                            var updated = rule; updated.triggerAt = due.addingTimeInterval(-offset); return updated
                        }
                    }
                    if memo != previous {
                        memo.updatedAt = Date()
                        manager.updateMemo(memo)
                        guard manager.memos.first(where: { $0.id == id }) == memo else { throw AcademicError.storage }
                    }
                }
            } else {
                var memo = Memo.create(title: task.title, tagType: .moodle, dueAt: task.due)
                memo.content = task.description
                memo.id = id; memo.disableAutoDueReminder = true
                if let due = task.due {
                    memo.reminderRules = [3 * 86400, 86400, 1800].map { interval in
                        ReminderRule(id: "academic.\(interval)", triggerAt: due.addingTimeInterval(-Double(interval)), kind: .beforeDue)
                    }
                }
                memo.courseLink = sourceCourseLink
                manager.addMemo(memo)
            }
            guard manager.memos.contains(where: { $0.id == id }) else { throw AcademicError.storage }
            nextRecords[key] = .init(memoID: id, lastTitle: task.title, lastDue: task.due,
                                     acknowledgedVersion: old?.acknowledgedVersion,
                                     managedCourseLink: old?.managedCourseLink ?? (existing?.courseLink == nil), lastCourseLink: sourceCourseLink,
                                     lastContent: task.description, lastTagType: Memo.TagType.moodle.rawValue)
        }
        cache.memoRecords = nextRecords
    }
    var completionCandidates: [AcademicRemoteTask] {
        guard let user = cache.moodleUser, let manager = memoManager else { return [] }
        return cache.tasks.filter { task in
            guard task.reliableSubmitted, let record = cache.memoRecords[memoKey(task, userID: user)],
                  record.acknowledgedVersion != task.version,
                  let memo = manager.memos.first(where: { $0.id == record.memoID }) else { return false }
            return memo.status != .done
        }
    }
    func acknowledge(_ task: AcademicRemoteTask, complete: Bool) {
        guard Auth.auth().currentUser?.uid == uid else { return }
        guard let user = cache.moodleUser, let manager = memoManager else { return }
        guard cache.tasks.contains(where: { $0.id == task.id && $0.version == task.version && $0.reliableSubmitted }) else { show(AcademicError.conflict); return }
        let key = memoKey(task, userID: user)
        guard var record = cache.memoRecords[key], let memo = manager.memos.first(where: { $0.id == record.memoID }) else { return }
        if complete { manager.markAsCompleted(memo) }
        if complete && manager.memos.first(where: { $0.id == memo.id })?.status != .done { show(AcademicError.storage); return }
        record.acknowledgedVersion = task.version; cache.memoRecords[key] = record
        do { try persist() } catch { show(error) }
    }
    func previewIssue(_ course: AcademicCachedCourse) -> String? {
        guard let data = courseData else { return "課表尚未載入" }
        do {
            let meetings = try AcademicMeeting.parse(course.schedule)
            let occupied = Set(meetings.map { "\($0.day):\($0.slot)" })
            for other in cache.courses where other.code != course.code {
                if let rows = try? AcademicMeeting.parse(other.schedule), rows.contains(where: { occupied.contains("\($0.day):\($0.slot)") }) {
                    return "來源課程時段互相衝突，需要確認後再匯入"
                }
            }
            if meetings.contains(where: { importDecision(course, meeting: $0, data: data) == .conflict }) {
                return "與現有課表衝突，保留原有課程"
            }
            return nil
        } catch { return "時段格式需要確認，暫不匯入" }
    }
    private func slot(_ value: Int) -> Course.TimeSlot { Course.TimeSlot.allCases[value - 1] }
    private func sourceKey(_ code: String) -> String { "\(cache.schoolIdentity ?? ""):\(cache.year ?? "")-\(cache.term ?? ""):\(code)" }
    private func importDecision(_ course: AcademicCachedCourse, meeting: AcademicMeeting, data: CourseData) -> AcademicImportDecision {
        AcademicImportPolicy.decide(proposedID: stableID("course:\(sourceKey(course.code)):\(meeting.day):\(meeting.slot)"),
            name: course.name, day: meeting.day, period: meeting.slot,
            existing: data.courses.map { .init(id: $0.id, name: $0.name, day: $0.day,
                period: (Course.TimeSlot.allCases.firstIndex(of: $0.timeSlot) ?? -1) + 1, fingerprint: snapshot($0)) },
            sourceIDs: Set(cache.courseRecords[sourceKey(course.code)] ?? []), previous: cache.courseSnapshots)
    }
    func courseContent(_ course: MoodleCourse) async throws -> ([MoodleAPI.ContentSection], [MoodleAPI.Announcement]) {
        let epoch = generation
        guard cache.moodleCourses?.contains(where: { $0.id == course.id }) == true,
              let credential = try AcademicKeychain.load(MoodleCredential.self, account: credentialKey("moodle")) else { throw AcademicError.loginRequired }
        let api = MoodleAPI()
        guard try await api.courses(credential).contains(where: { $0.id == course.id }) else { throw AcademicError.identityChanged }
        try check(epoch)
        let result = try await api.content(courseID: course.id, credential: credential)
        try check(epoch)
        return result
    }
    func courseGrades(_ course: MoodleCourse) async throws -> [MoodleAPI.Grade] {
        let epoch = generation
        guard cache.moodleCourses?.contains(where: { $0.id == course.id }) == true,
              let credential = try AcademicKeychain.load(MoodleCredential.self, account: credentialKey("moodle")) else { throw AcademicError.loginRequired }
        let api = MoodleAPI()
        guard try await api.courses(credential).contains(where: { $0.id == course.id }) else { throw AcademicError.identityChanged }
        try check(epoch)
        let result = try await api.ownGrades(courseID: course.id, credential: credential)
        try check(epoch)
        return result
    }
    func remoteTask(for memoID: String) -> AcademicRemoteTask? {
        guard let user = cache.moodleUser else { return nil }
        return cache.tasks.first { cache.memoRecords[memoKey($0, userID: user)]?.memoID == memoID }
    }
    func moodleCourse(forCourseID id: String) -> MoodleCourse? {
        guard let identity = cache.schoolIdentity,
              let source = cache.courseRecords.first(where: { $0.key.hasPrefix(identity + ":") && $0.value.contains(id) }),
              let code = source.key.split(separator: ":").last else { return nil }
        let matches = (cache.moodleCourses ?? []).filter { $0.fullname.contains("(\(code))") }
        return matches.count == 1 ? matches[0] : nil
    }
    private func snapshot(_ course: Course) -> String { "\(course.name)|\(course.day)|\(course.timeSlot.rawValue)|\(course.location)|\(course.teacher)" }
    func importCourses() {
        guard Auth.auth().currentUser?.uid == uid, !uid.isEmpty else { return }
        guard let data = courseData, let context = data.viewContext, !context.hasChanges,
              let year = cache.year, let term = cache.term else { show(AcademicError.storage); return }
        var records = cache.courseRecords, snapshots = cache.courseSnapshots
        do {
            // Re-read the store in case CloudKit changed it since the preview.
            data.loadCoursesFromCoreData()
            let existing = try context.fetch(CourseEntity.fetchRequest())
            var imported = 0
            for course in cache.courses where previewIssue(course) == nil {
                let key = "\(cache.schoolIdentity ?? ""):\(year)-\(term):\(course.code)"
                var ids = records[key] ?? []
                for meeting in try AcademicMeeting.parse(course.schedule) {
                    let id: String
                    let isNew: Bool
                    switch importDecision(course, meeting: meeting, data: data) {
                    case .preserve(let existingID), .link(let existingID):
                        if !ids.contains(existingID) { ids.append(existingID) }; continue
                    case .update(let existingID): id = existingID; isNew = false
                    case .add: id = stableID("course:\(key):\(meeting.day):\(meeting.slot)"); isNew = true
                    case .conflict: throw AcademicError.conflict
                    }
                    let entity = existing.first { $0.id == id } ?? CourseEntity(context: context)
                    entity.id = id; entity.name = course.name; entity.day = meeting.day
                    entity.timeSlot = slot(meeting.slot).rawValue; entity.location = meeting.location; entity.teacher = course.teacher
                    let starts: [Course.TimeStart] = [.eight, .nine, .ten, .eleven, .thirteen, .fourteen, .fifteen, .sixteen, .seventeen, .eighteen, .nineteen, .twenty, .twentyone]
                    entity.startTime = starts[meeting.slot - 1].rawValue
                    if isNew { entity.isNotification = true }
                    let row = Course(id: id, name: course.name, day: meeting.day, startTime: starts[meeting.slot - 1], timeSlot: slot(meeting.slot), location: meeting.location, teacher: course.teacher, isNotification: entity.isNotification)
                    snapshots[id] = snapshot(row)
                    if !ids.contains(id) { ids.append(id) }
                    imported += 1
                }
                records[key] = ids
            }
            try context.save()
            cache.courseRecords = records; cache.courseSnapshots = snapshots
            data.loadCoursesFromCoreData()
            if let user = cache.moodleUser { try mergeTasks(cache.tasks.filter { $0.sourceMissing != true }, userID: user) }
            try persist()
            message = "已套用 \(imported) 節課；相同課程沿用原 ID，有衝突或手動修改的課程予以保留。來源已移除的舊課程不會自動刪除。"
        } catch {
            if context.hasChanges { context.rollback() }
            show(error)
        }
    }
}
