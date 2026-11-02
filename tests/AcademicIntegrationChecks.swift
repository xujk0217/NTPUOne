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
                print("LIVE_SWIFT_REPORT kind=\(input.kind.rawValue) sanitised_bytes=\(report.html.utf8.count)")
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
            let reportHTML = "<div>本人 SYNTHETIC 成績 學分數</div><table><tr><td>Header</td></tr><tr><td>Value</td></tr></table><script>UNTRUSTED_SCRIPT</script><img src='https://example.org/track' onerror='steal()'><a href='https://example.org/'>Link</a>"
            let report = try SchoolAPI.parseReport(reportHTML, identity: "SYNTHETIC", kind: .grades)
            try require(!report.html.contains("UNTRUSTED_SCRIPT") && !report.html.contains("onerror") && !report.html.contains("example.org"), "report active content or exfiltration")
            try require(report.html.contains("script-src 'none'") && report.html.contains("form-action 'none'"), "report CSP")
            try rejects { _ = try SchoolAPI.parseReport(reportHTML, identity: "OTHER", kind: .grades) }
            print("PASS: academic safety, real App parsers, semester, scheduling and completion checks")
        } catch {
            // No raw service error or response: live payloads may contain private data.
            print("FAIL: academic check stopped stage=\(stage) (\(error is AcademicError ? "academic-contract" : "local-check"))")
            Foundation.exit(1)
        }
    }
}
