// Standalone macOS checks against the same App services. No production database.
import Foundation
import Darwin

@main struct AcademicIntegrationChecks {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "AcademicChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func rejects(_ body: () throws -> Void) throws {
        do { try body() } catch { return }
        throw NSError(domain: "AcademicChecks", code: 2)
    }
    static func fixture(state: String = "已核准", student: String = "SYNTHETIC", term: String = "1") -> String {
        let headers = ["", "科目名稱(與組別)", "核課資訊", "授課老師", "上課時間@教室", "類別", "學分/時數", "開課系級", "備註"]
        let row = ["", "Synthetic(U1234)", state, "Teacher", "每週二3~4 Room", "", "3/3", "", ""]
        return "<table>" + [headers, row].map { "<tr>" + $0.map { "<td>\($0)</td>" }.joined() + "</tr>" }.joined() +
            "</table><a href='../univer/course_check_m.dt_e?stud_no=\(student)&year1=115&term1=\(term)'>Confirm</a>"
    }
    static func main() async {
        var stage = "offline"
        do {
            if CommandLine.arguments.contains(where: { $0.hasPrefix("--live-") }) {
                guard isatty(STDIN_FILENO) == 0 else { throw AcademicError.loginRequired }
            }
            if CommandLine.arguments.contains("--live-moodle") {
                // Credentials only arrive through a captured pipe, never arguments/files/logs.
                let data = FileHandle.standardInput.readDataToEndOfFile()
                let credential = try JSONDecoder().decode(MoodleCredential.self, from: data)
                let api = MoodleAPI()
                stage = "moodle-courses"
                let courses = try await api.courses(credential)
                let term = AcademicPolicy.currentTerm().replacingOccurrences(of: "-", with: "")
                var count = 0, statuses = 0
                var contentChecked = false
                for course in courses where course.fullname.hasPrefix(term + "_") {
                    if !contentChecked {
                        stage = "moodle-course-content"
                        let (sections, announcements) = try await api.content(courseID: course.id, credential: credential)
                        stage = "moodle-own-grades"
                        let grades = try await api.ownGrades(courseID: course.id, credential: credential)
                        print("LIVE_SWIFT_MOODLE_CONTENT sections=\(sections.count) announcements=\(announcements.count) own_grade_items=\(grades.count)")
                        contentChecked = true
                    }
                    stage = "moodle-assignments"
                    let assignments = try await api.assignments(course: course, credential: credential)
                    count += assignments.count
                    for assignment in assignments {
                        stage = "moodle-submissions"
                        let status: MoodleSubmission = try await api.call("mod_assign_get_submission_status", token: credential.token,
                            fields: ["assignid": String(assignment.id)])
                        try require(status.warnings?.isEmpty != false, "warnings")
                        statuses += 1
                    }
                }
                print("LIVE_SWIFT_MOODLE courses=\(courses.count) assignments=\(count) submission_responses=\(statuses)")
                return
            }
            if CommandLine.arguments.contains("--live-school-html") {
                struct Input: Decodable { var html: String; var identity: String }
                let input = try JSONDecoder().decode(Input.self, from: FileHandle.standardInput.readDataToEndOfFile())
                let enrolment = try SchoolAPI.parseEnrolment(input.html, identity: input.identity)
                var slots = 0
                for row in enrolment.courses {
                    let matches = try await CourseCatalogService.search(year: enrolment.year, term: enrolment.term, code: row.code).filter { $0.courseno == row.code }
                    try require(matches.count == 1, "ambiguous course")
                    slots += try AcademicMeeting.parse(matches[0].scheduleText ?? "").count
                }
                print("LIVE_SWIFT_SCHOOL year=\(enrolment.year) term=\(enrolment.term) courses=\(enrolment.courses.count) meetings=\(slots)")
                return
            }
            if CommandLine.arguments.contains("--live-school-report") {
                struct Input: Decodable { var html: String; var identity: String; var kind: SchoolReportKind }
                let input = try JSONDecoder().decode(Input.self, from: FileHandle.standardInput.readDataToEndOfFile())
                let report = try SchoolAPI.parseReport(input.html, identity: input.identity, kind: input.kind)
                print("LIVE_SWIFT_REPORT kind=\(input.kind.rawValue) native_sections=\(report.sections?.count ?? 0) subjects=\(report.sections?.reduce(0) { $0 + $1.subjects.count } ?? 0)")
                return
            }
            let rows = try AcademicMeeting.parse("每週二3~4 Room A\n每週四7、9 Room B")
            try require(rows.count == 4 && rows.map(\.slot) == [3, 4, 7, 9], "range/non-contiguous periods")
            try require(rows[0].day == "Tuesday" && rows[2].day == "Thursday", "multiple days")
            let manual = AcademicImportSlot(id: "ORIGINAL_UUID", name: "Manual Course", day: "Monday", period: 1, fingerprint: "private")
            try require(AcademicImportPolicy.decide(proposedID: "NEW", name: "Different Course", day: "Monday", period: 1,
                existing: [manual], sourceIDs: [], previous: [:]) == .conflict, "manual slot must not be replaced")
            try require(AcademicImportPolicy.decide(proposedID: "NEW", name: "Manual Course", day: "Monday", period: 1,
                existing: [manual], sourceIDs: [], previous: [:]) == .link("ORIGINAL_UUID"), "manual UUID and Memo linkage must survive")
            try require(AcademicImportPolicy.decide(proposedID: "NEW", name: "Renamed Course", day: "Monday", period: 1,
                existing: [manual], sourceIDs: ["ORIGINAL_UUID"], previous: ["ORIGINAL_UUID": "private"]) == .update("ORIGINAL_UUID"), "source updates keep original UUID")
            try require(AcademicImportPolicy.decide(proposedID: "NEW", name: "Renamed Course", day: "Monday", period: 1,
                existing: [manual], sourceIDs: ["ORIGINAL_UUID"], previous: ["ORIGINAL_UUID": "old"]) == .preserve("ORIGINAL_UUID"), "private course edits win")
            try require(AcademicImportPolicy.decide(proposedID: "ORIGINAL_UUID", name: "Manual Course", day: "Tuesday", period: 2,
                existing: [manual], sourceIDs: ["ORIGINAL_UUID"], previous: ["ORIGINAL_UUID": "old"]) == .preserve("ORIGINAL_UUID"), "manually moved courses must not be recreated")
            try require(AcademicImportPolicy.decide(proposedID: "ORIGINAL_UUID", name: "Manual Course", day: "Tuesday", period: 2,
                existing: [manual], sourceIDs: [], previous: [:]) == .link("ORIGINAL_UUID"), "cache loss must not duplicate an existing source UUID")
            try require(AcademicImportPolicy.decide(proposedID: "NEW", name: "Manual Course", day: "Monday", period: 1,
                existing: [manual, manual], sourceIDs: [], previous: [:]) == .conflict, "ambiguous occupied slots fail closed")
            for invalid in ["", "每週日3~4 Room", "每週一0~2 Room", "每週二4~2 Room", "每週三1~14 Room", "每週三3~4", "每週一3~4 Room 每週二5~6 Room", "每週一1、1 Room"] {
                try rejects { _ = try AcademicMeeting.parse(invalid) }
            }
            for value in ["draft", "new", "reopened", "graded", "overdue", "unknown"] {
                try require(!AcademicPolicy.reliableSubmission(status: value, isTeam: false), "false completion")
            }
            try require(AcademicPolicy.reliableSubmission(status: "submitted", isTeam: false), "individual submitted")
            try require(!AcademicPolicy.reliableSubmission(status: "submitted", isTeam: true), "unverified team completion")
            let now = Date(timeIntervalSince1970: 1_000_000)
            try require(!AcademicPolicy.needsRefresh(last: now.addingTimeInterval(-299), now: now, interval: 300), "foreground debounce")
            try require(AcademicPolicy.needsRefresh(last: now.addingTimeInterval(-300), now: now, interval: 300), "refresh boundary")
            try require(AcademicPolicy.needsRefresh(last: now.addingTimeInterval(60), now: now, interval: 300), "clock reversal")
            let parsed = try SchoolAPI.parseEnrolment(fixture(), identity: "SYNTHETIC")
            try require(parsed.year == "115" && parsed.term == "1" && parsed.courses.first?.code == "U1234", "enrolment")
            for html in [fixture(state: "退選"), fixture(state: "未知"), fixture(student: "OTHER"), fixture(term: "3"), fixture().replacingOccurrences(of: "核課資訊", with: "Unknown")] {
                try rejects { _ = try SchoolAPI.parseEnrolment(html, identity: "SYNTHETIC") }
            }
            let request = CourseCatalogService.request(year: "115", term: "1", code: "U1234&extra=true")
            let query = URLComponents(string: "?" + String(decoding: request.httpBody!, as: UTF8.self))!
            try require(query.queryItems?.first(where: { $0.name == "courseno" })?.value == "U1234&extra=true", "form injection")
            try require(request.value(forHTTPHeaderField: "Cookie") == nil, "public request cookie leak")
            var cells = Array(repeating: "", count: 15)
            cells[3] = "U1234"; cells[7] = "<a>Synthetic Course</a>"; cells[8] = "Teacher"
            cells[13] = "每週二3~4 Room A<br>每週四7、9 Room B"
            let catalog = try CourseCatalogService.parse("<table id=example><tbody><tr>" + cells.map { "<td>\($0)</td>" }.joined() + "</tr></tbody></table>")
            try require(catalog.count == 1 && catalog[0].courseName == "Synthetic Course", "shared CourseGet parser")
            let meetings = try AcademicMeeting.parse(catalog[0].scheduleText!)
            try require(meetings.count == 4, "HTML line breaks preserved")
            try rejects { _ = try CourseCatalogService.parse("<h1>Login required</h1>") }
            let gradeJSON = #"{"id":1,"itemname":null,"gradeformatted":"-","gradeishidden":false}"#
            let grade = try JSONDecoder().decode(MoodleAPI.Grade.self, from: Data(gradeJSON.utf8))
            try require(grade.itemname == nil, "Moodle course total may have a null item name")
            let reportHTML = """
            <div>本人 SYNTHETIC 成績 學分數</div>
            <div class='card my-4'><div class='card-title'><span class='lang lang-zh-TW'>測試學年</span><span class='lang lang-en-US'>English duplicate</span></div>
            <table class='table table-striped'><tr><th>類別</th><th>科目名稱</th><th>學分</th><th>成績</th><th>學分</th><th>成績</th></tr>
            <tr><td>必修</td><td class='text-left'>Synthetic Course</td><td class='sem1bg'>3</td><td class='sem1bg'>A</td><td class='sem2bg'></td><td class='sem2bg'></td></tr>
            <tr><td colspan=2>學期平均</td><td class='sem1bg' colspan=2>87</td><td class='sem2bg' colspan=2></td></tr></table></div>
            <script>UNTRUSTED_SCRIPT</script><iframe src='https://example.org'></iframe>
            """
            let report = try SchoolAPI.parseReport(reportHTML, identity: "SYNTHETIC", kind: .grades)
            try require(report.html == nil && report.isNative, "new report must not retain/render HTML")
            try require(report.sections?.count == 1 && report.sections?.first?.subjects.count == 1, "semester isolation and absent semester")
            try require(report.sections?.first?.subjects.first?.grade == "A", "grade cell contract")
            try require(report.sections?.first?.fields.first?.value == "87", "official summary value")
            let encoded = try JSONEncoder().encode(report)
            let encodedText = String(decoding: encoded, as: UTF8.self)
            try require(!encodedText.contains("UNTRUSTED_SCRIPT") && !encodedText.contains("example.org") && !encodedText.contains("English duplicate"), "structured report only")
            let oldJSON = try JSONSerialization.data(withJSONObject: ["kind": "grades", "html": reportHTML, "checkedAt": 1.0])
            let old = try JSONDecoder().decode(SchoolReport.self, from: oldJSON)
            let migrated = try old.migrated()
            try require(migrated.isNative && migrated.html == nil && migrated.checkedAt == old.checkedAt, "first-open legacy cache migration")
            try rejects { _ = try AcademicReportParser.parse("<h1>成績</h1><table><tr><td>unknown</td></tr></table>", kind: .grades) }
            try rejects { _ = try SchoolAPI.parseReport(reportHTML, identity: "OTHER", kind: .grades) }
            let rankHTML = "<div class='container my-2'><h6>測試學年</h6><div class='card'><div class='datasheets'><strong>第一學期</strong><ul class='datarows'><li>平均成績：87</li><li>排名：3 / 30</li></ul></div></div></div>"
            let rankReport = try AcademicReportParser.parse(rankHTML, kind: .rank)
            let cumulative = try AcademicReportParser.parse("<div class='container my-2'><h6>累計成績</h6><div class=card><div class='card-body datasheets'><ul class=datarows><li>平均成績：87</li></ul></div></div></div>", kind: .rank)
            try require(cumulative.sections?.first?.title == "累計成績", "cumulative rank card has no semester strong")
            try require(rankReport.sections?.first?.fields.count == 2 && rankReport.sections?.first?.fields.last?.value == "3 / 30", "rank fixed class contract")
            let summaryHTML = """
            <div class='row_progress'>
              <div class='flex_item_col'><div><div class='grid_stat_item_title'>已累計總學分</div><div class='credit_count'>(123 = 50 + 25 + 38 + 10)</div></div><div class='credit_box'><div class='main_credit'>123</div></div></div>
              <div class='flex_item_col'><div class='grid_stat_item_title'>系必修</div><div class='credit_box'><div class='main_credit'>50</div><div class='total_credit'>/ 60</div></div></div>
              <div class='flex_item_col'><div class='grid_stat_item_title'>系選修</div><div class='credit_box'><div class='main_credit'>25</div></div></div>
              <div class='flex_item_col'><div class='grid_stat_item_title'>其他學分</div><div class='credit_box'><div class='main_credit'>10</div></div></div>
              <ul class='item_ul'><li class='item_li'><div><div class='item_title'>外語能力指標檢核</div><div>未處理</div></div></li></ul>
            </div>
            """
            let unsortedTerms = ["113學年度 · 第1學期", "累計成績", "112學年度 · 第2學期", "112學年度 · 第1學期", "114學年度 · 第一學期", "114學年度 · 下學期"].enumerated().map { index, title in
                AcademicReportSection(id: String(index), title: title)
            }
            let orderedTerms = AcademicReportOrdering.sorted(unsortedTerms)
            try require(orderedTerms.map(\.id) == ["3", "2", "0", "4", "5", "1"], "school year and semester tabs must sort chronologically")
            try require(AcademicReportOrdering.latestTerm(unsortedTerms)?.id == "5", "default stays on latest semester rather than cumulative")
            let shortTerms = [AcademicReportSection(id: "b", title: "112-2"), AcademicReportSection(id: "a", title: "112-1")]
            try require(AcademicReportOrdering.sorted(shortTerms).map(\.id) == ["a", "b"], "short year-semester format")
            let graduationHTML = summaryHTML + "<div id=tag_total><div class=credit_box><div class=main_credit>100</div><div class=total_credit>128</div></div></div>" + ["required", "option", "common", "other"].map { id in
                "<section id='\(id)'><div class=collapse_title>\(id)</div><div class=collapse_ul_header><div class=collapse_col_item><span>應修</span><span>3</span></div></div><li class=subject_li><div class=subject_title>Synthetic Course</div><div class=subject_state>已修</div></li></section>"
            }.joined()
            let graduation = try AcademicReportParser.parse(graduationHTML, kind: .graduation)
            try require(graduation.sections?.count == 10 && graduation.sections?.last?.subjects.count == 1, "graduation IDs and subject rows")
            try require(graduation.sections?.first(where: { $0.id == "tag_total" })?.title == "校訂必修學分", "tag_total is the general-education category, not cumulative credits")
            try require(graduation.sections?.first(where: { $0.id == "tag_total" })?.fields.first?.value == "100", "three-digit credits remain intact")
            try require(graduation.sections?.first(where: { $0.id == "tag_total" })?.fields.first?.detail == "128", "separate credit values and requirements, never concatenate")
            let totalSection = graduation.sections?.first(where: { $0.id == "summary_total" })
            try require(totalSection?.fields.first?.value == "123", "cumulative total comes from its own card, not the category")
            try require(graduation.sections?.first(where: { $0.id == "requirements" })?.fields.first?.value == "未處理", "official requirement status preserved")
            let fallback = try AcademicReportParser.parse(graduationHTML.replacingOccurrences(of: "<div class='main_credit'>123</div>", with: "<div>123</div>"), kind: .graduation)
            try require(fallback.sections?.first(where: { $0.id == "summary_total" })?.fields.first?.value == "123", "single-number total box without inner class")
            let requiredFallback = try AcademicReportParser.parse(graduationHTML.replacingOccurrences(of: "<div class='main_credit'>50</div><div class='total_credit'>/ 60</div>", with: "<div>50 / 60</div>"), kind: .graduation)
            try require(requiredFallback.sections?.first(where: { $0.id == "summary_required" })?.fields.first?.value == "50" && requiredFallback.sections?.first(where: { $0.id == "summary_required" })?.fields.first?.detail == "/ 60", "summary fallback keeps numerator and target separate")

            try rejects { _ = try AcademicReportParser.parse(graduationHTML.replacingOccurrences(of: "<div class='main_credit'>123</div>", with: "<div>123 50</div>"), kind: .graduation) }

            try require(totalSection?.fields.first?.detail == "(123 = 50 + 25 + 38 + 10)", "school's expression is retained")
            try require(graduation.sections?.first(where: { $0.id == "summary_required" })?.fields.first?.detail == "/ 60", "required credit target")
            try rejects { _ = try AcademicReportParser.parse(graduationHTML.replacingOccurrences(of: "<div class='row_progress'>", with: "<div class='row_progress'>" + summaryHTML), kind: .graduation) }
            try require(graduation.isCurrent, "new graduation parser revision")
            var legacyGraduation = graduation; legacyGraduation.parserVersion = 2
            try require(legacyGraduation.isNative && !legacyGraduation.isCurrent, "legacy concatenated graduation cache must refresh before display")
            let graduationRoundTrip = try JSONDecoder().decode(SchoolReport.self, from: JSONEncoder().encode(graduation))
            try require(graduationRoundTrip.sections?.first(where: { $0.id == "tag_total" })?.fields.first?.detail == "128" && graduationRoundTrip.isCurrent, "credit detail survives protected cache")
            let decimalGraduation = try AcademicReportParser.parse(graduationHTML.replacingOccurrences(of: ">100<", with: ">12.5<"), kind: .graduation)
            try require(decimalGraduation.sections?.first(where: { $0.id == "tag_total" })?.fields.first?.value == "12.5", "decimal credits must not be rounded or truncated")

            try rejects { _ = try AcademicReportParser.parse(graduationHTML.replacingOccurrences(of: "id='required'", with: "id='changed'"), kind: .graduation) }
            try require(AcademicMemoMergePolicy.content(existing: "", previous: nil, incoming: "source") == "source", "legacy empty notes receive source")
            try require(AcademicMemoMergePolicy.content(existing: "source", previous: "source", incoming: "new") == "new", "source-managed notes refresh")
            try require(AcademicMemoMergePolicy.content(existing: "private edit", previous: "source", incoming: "new") == "private edit", "private notes survive")
            try require(AcademicMemoMergePolicy.content(existing: "private", previous: nil, incoming: "source").hasPrefix("private\n"), "legacy private notes preserved")
            try require(AcademicMemoMergePolicy.courseName("Synthetic Course(U1234)") == "Synthetic Course", "catalog course matching")
            try require(AcademicCompletionPolicy.completed(status: "submitted", isTeam: false) == true, "submitted imports completed immediately")
            for status in ["new", "draft", "reopened"] {
                try require(AcademicCompletionPolicy.completed(status: status, isTeam: false) == false, "unsubmitted/reopened restores incomplete")
            }
            try require(AcademicCompletionPolicy.completed(status: "submitted", isTeam: true) == nil, "unverified group completion stays manual")
            try require(AcademicCompletionPolicy.completed(status: "unknown", isTeam: false) == nil, "unknown must not reset completion")
            try require(AcademicCompletionPolicy.completed(status: "submitted", isTeam: false, missing: true) == nil, "missing source must not change completion")
            let due = Date(timeIntervalSince1970: 2_000_000_000)
            let legacy = AcademicReminderPolicy.legacyOffsets.map { offset in
                AcademicReminderSnapshot(id: "academic.\(offset)", triggerAt: due.addingTimeInterval(-Double(offset)), enabled: true, isDefaultKind: true)
            }
            let migratedReminders = AcademicReminderPolicy.plan(current: legacy, previousOffsets: AcademicReminderPolicy.legacyOffsets,
                previousDue: due, due: due, targetOffsets: [5 * 86400], isNew: false)
            try require(migratedReminders.removeIDs.count == 3 && migratedReminders.addOffsets == [5 * 86400], "replace untouched legacy reminders with configured default")
            var edited = legacy[0]; edited.triggerAt = due; edited.enabled = false
            let preservedReminder = AcademicReminderPolicy.plan(current: [edited], previousOffsets: [259200], previousDue: due,
                due: due, targetOffsets: [86400], isNew: false)
            try require(preservedReminder.removeIDs.isEmpty && preservedReminder.addOffsets.isEmpty, "disabled/edited reminders remain private")
            let deletedReminder = AcademicReminderPolicy.plan(current: [], previousOffsets: [259200], previousDue: due,
                due: due, targetOffsets: [86400], isNew: false)
            try require(deletedReminder.addOffsets.isEmpty, "deleted default must not resurrect")
            let noReminder = AcademicReminderPolicy.plan(current: legacy, previousOffsets: AcademicReminderPolicy.legacyOffsets,
                previousDue: due, due: due, targetOffsets: [], isNew: false)
            try require(noReminder.removeIDs.count == 3 && noReminder.addOffsets.isEmpty, "disable only source-managed reminders")
            let firstDue = AcademicReminderPolicy.plan(current: [], previousOffsets: [259200], previousDue: nil,
                due: due, targetOffsets: [259200], isNew: false)
            try require(firstDue.addOffsets == [259200], "newly published deadline gets default reminder")
            print("PASS: academic safety, real App parsers, semester, scheduling and completion checks")
        } catch {
            // No raw service error or response: live payloads may contain private data.
            print("FAIL: academic check stopped stage=\(stage) (\(error is AcademicError ? "academic-contract" : "local-check"))")
            Foundation.exit(1)
        }
    }
}
