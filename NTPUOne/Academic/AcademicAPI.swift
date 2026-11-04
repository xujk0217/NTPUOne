import Foundation
import Security
import SwiftSoup
import CryptoKit

enum AcademicKeychain {
    private static let service = "com.xujk.NTPUOne.Academic"
    static func key(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false]
    }
    static func load<T: Decodable>(_ type: T.Type, account: String) throws -> T? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw AcademicError.storage }
        return try JSONDecoder().decode(type, from: data)
    }
    static func save<T: Encodable>(_ value: T, account: String) throws {
        let data = try JSONEncoder().encode(value)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query(account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query(account).merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw AcademicError.storage }
        } else if status != errSecSuccess { throw AcademicError.storage }
    }
    static func delete(account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AcademicError.storage }
    }
}

/// Ephemeral cookies, exact endpoint allowlist, no credential-bearing URL or logs.
final class AcademicHTTP: NSObject, URLSessionTaskDelegate {
    private var session: URLSession!
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    func close() { session.invalidateAndCancel() }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // The fresh portal login legitimately redirects to its same-origin home.
        let url = request.url
        let allowed = task.originalRequest?.url?.host == "my.ntpu.edu.tw" && url?.host == "my.ntpu.edu.tw" &&
            url?.scheme == "https" && url?.port == nil && url?.user == nil && url?.password == nil &&
            ["/", "/login"].contains(url?.path ?? "") && [301, 302, 303].contains(response.statusCode)
        completionHandler(allowed ? request : nil)
    }
    // Only URLs returned by Moodle content APIs may reach this method. Tokens
    // stay in the ephemeral request; redirects, caches and diagnostics are disabled.
    func moodleFile(_ value: String, token: String) async throws -> Data {
        guard var parts = URLComponents(string: value), parts.scheme == "https",
              parts.host == "lms3.ntpu.edu.tw", parts.port == nil, parts.user == nil, parts.password == nil,
              parts.path.hasPrefix("/webservice/pluginfile.php/"), parts.fragment == nil,
              !parts.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }),
              (parts.queryItems ?? []).allSatisfy({ $0.name == "forcedownload" }) else { throw AcademicError.unsupported }
        parts.queryItems = (parts.queryItems ?? []) + [URLQueryItem(name: "token", value: token)]
        guard let url = parts.url else { throw AcademicError.unsupported }
        var request = URLRequest(url: url); request.timeoutInterval = 30
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              !((http.mimeType ?? "").lowercased().contains("text/html")),
              http.expectedContentLength <= 20 * 1024 * 1024 else { throw AcademicError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 20 * 1024 * 1024 else { throw AcademicError.invalidResponse }
            data.append(byte)
        }
        guard !data.isEmpty else { throw AcademicError.invalidResponse }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["errorcode"] != nil || object["exception"] != nil { throw AcademicError.invalidResponse }
        return data
    }
    func request(_ url: URL, fields: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        let portal = url.host == "my.ntpu.edu.tw" && ["/", "/login", "/get-projects/10"].contains(url.path)
        let moodle = url.host == "lms3.ntpu.edu.tw" && ["/login/token.php", "/webservice/rest/server.php"].contains(url.path)
        let school = ["cof.ntpu.edu.tw", "ohs01.ntpu.edu.tw"].contains(url.host ?? "") &&
            ["/pls/pm/stud_system.signin", "/pls/univer/u0001.query_all_course.judge", "/pls/univer/query_all_course.judge"].contains(url.path)
        guard url.scheme == "https", url.port == nil, url.user == nil, url.password == nil,
              portal || moodle || school else { throw AcademicError.unsupported }
        if moodle { guard fields != nil, url.query == nil else { throw AcademicError.unsupported } }
        if portal {
            if url.path == "/" { guard fields == nil, url.query == nil else { throw AcademicError.unsupported } }
            if url.path == "/login" {
                guard url.query == nil, fields == nil || Set(fields!.keys) == ["_token", "username", "password"] else { throw AcademicError.unsupported }
            }
            if url.path == "/get-projects/10" {
                let permitted = ["3_m", "5_m", "8_m"].map { "https://ohs01.ntpu.edu.tw/pls/univer/u0001.query_all_course.judge?func=\($0)" } + ["https://ohs01.ntpu.edu.tw/pls/univer/query_all_course.judge?func=9_m"]
                let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                guard fields == nil, query?.count == 1, query?.first?.name == "url", permitted.contains(query?.first?.value ?? "") else { throw AcademicError.unsupported }
            }
        }
        if school && url.path.contains("judge") {
            let functions = url.path.contains("u0001.") ? ["3_m", "5_m", "8_m"] : ["9_m"]
            guard fields == nil, let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  query.count == 1, query[0].name == "func", functions.contains(query[0].value ?? "") else { throw AcademicError.unsupported }
        }
        if school && url.path.contains("signin") { guard Set(fields?.keys.map { $0 } ?? []) == ["id", "pw"], url.query == nil else { throw AcademicError.unsupported } }
        var request = URLRequest(url: url)
        request.setValue("NTPUOne-Academic/1.0", forHTTPHeaderField: "User-Agent")
        if let fields {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var form = URLComponents()
            form.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        }
        if url.path == "/get-projects/10" {
            request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              data.count <= 8_388_608 else { throw AcademicError.invalidResponse }
        return (data, response)
    }
}

struct MoodleCredential: Codable { var token: String; var userID: Int; var schoolIdentity: String? = nil }
struct MoodleCourse: Codable, Identifiable {
    var id: Int; var fullname: String; var shortname: String?; var idnumber: String?
}
struct MoodleAssignment: Decodable, Identifiable {
    var id: Int; var cmid: Int; var name: String; var intro: String; var duedate: Double
    var teamsubmission: Int; var requireallteammemberssubmit: Int
    var courseID: Int = 0
    var courseName: String = ""
    enum CodingKeys: String, CodingKey { case id, cmid, name, intro, duedate, teamsubmission, requireallteammemberssubmit }
    var url: URL { URL(string: "https://lms3.ntpu.edu.tw/mod/assign/view.php?id=\(cmid)")! }
}
struct MoodleSubmission: Decodable {
    struct Submission: Decodable { var status: String; var attemptnumber: Int?; var timemodified: Double? }
    struct Attempt: Decodable { var submission: Submission?; var teamsubmission: Submission?; var graded: Bool?; var extensionduedate: Double? }
    var lastattempt: Attempt?
    var warnings: [MoodleWarning]?
}
struct MoodleWarning: Decodable { var warningcode: String? }

final class MoodleAPI {
    let http = AcademicHTTP()
    deinit { http.close() }
    private let allowed: Set<String> = ["core_webservice_get_site_info", "core_course_get_enrolled_courses_by_timeline_classification",
        "mod_assign_get_assignments", "mod_assign_get_submission_status", "core_calendar_get_action_events_by_timesort",
        "core_course_get_contents", "mod_forum_get_forums_by_courses", "mod_forum_get_forum_discussions", "gradereport_user_get_grade_items"]
    private var verifiedUserID: Int?
    private(set) var verifiedSchoolIdentity: String?
    private var availableFunctions: Set<String> = []
    struct Site: Decodable {
        struct Function: Decodable { var name: String }
        var userid: Int; var username: String; var functions: [Function]
    }
    func login(username: String, password: String) async throws -> MoodleCredential {
        let (data, _) = try await http.request(URL(string: "https://lms3.ntpu.edu.tw/login/token.php")!,
            fields: ["username": username, "password": password, "service": "moodle_mobile_app"])
        struct Token: Decodable { var token: String }
        guard let result = try? JSONDecoder().decode(Token.self, from: data), !result.token.isEmpty else { throw AcademicError.loginRequired }
        let site: Site = try await call("core_webservice_get_site_info", token: result.token)
        guard site.userid > 0 else { throw AcademicError.loginRequired }
        verifiedUserID = site.userid
        return MoodleCredential(token: result.token, userID: site.userid, schoolIdentity: AcademicKeychain.key(site.username))
    }
    func call<T: Decodable>(_ function: String, token: String, fields: [String: String] = [:]) async throws -> T {
        guard allowed.contains(function), Set(fields.keys).isDisjoint(with: ["wstoken", "wsfunction", "moodlewsrestformat"]) else { throw AcademicError.unsupported }
        if function == "gradereport_user_get_grade_items" {
            guard let own = verifiedUserID, own > 0, fields["userid"] == String(own) else { throw AcademicError.identityChanged }
        } else if fields["userid"] != nil { throw AcademicError.identityChanged }
        var fields = fields
        fields.merge(["wstoken": token, "wsfunction": function, "moodlewsrestformat": "json"]) { _, new in new }
        let (data, _) = try await http.request(URL(string: "https://lms3.ntpu.edu.tw/webservice/rest/server.php")!, fields: fields)
        if let error = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let code = error["errorcode"] as? String {
            throw ["invalidtoken", "accessexception", "requireloginerror"].contains(code) ? AcademicError.loginRequired : AcademicError.invalidResponse
        }
        do { return try JSONDecoder().decode(T.self, from: data) } catch { throw AcademicError.invalidResponse }
    }
    func courses(_ credential: MoodleCredential) async throws -> [MoodleCourse] {
        let site: Site = try await call("core_webservice_get_site_info", token: credential.token)
        guard site.userid == credential.userID else { throw AcademicError.identityChanged }
        verifiedUserID = site.userid; availableFunctions = Set(site.functions.map(\.name))
        verifiedSchoolIdentity = AcademicKeychain.key(site.username)
        guard credential.schoolIdentity == nil || credential.schoolIdentity == verifiedSchoolIdentity else { throw AcademicError.identityChanged }
        let needed: Set<String> = ["core_course_get_enrolled_courses_by_timeline_classification", "mod_assign_get_assignments", "mod_assign_get_submission_status"]
        guard needed.isSubset(of: Set(site.functions.map(\.name))) else { throw AcademicError.unsupported }
        struct Page: Decodable { var courses: [MoodleCourse]; var nextoffset: Int }
        var result: [Int: MoodleCourse] = [:], offset = 0
        for _ in 0..<20 {
            let page: Page = try await call("core_course_get_enrolled_courses_by_timeline_classification", token: credential.token,
                fields: ["classification": "inprogress", "limit": "50", "offset": String(offset)])
            if page.courses.isEmpty { return result.values.sorted { $0.id < $1.id } }
            guard page.nextoffset > offset, page.courses.allSatisfy({ result[$0.id] == nil }) else { throw AcademicError.invalidResponse }
            for course in page.courses { result[course.id] = course }
            offset = page.nextoffset
        }
        throw AcademicError.invalidResponse
    }
    func assignments(course: MoodleCourse, credential: MoodleCredential) async throws -> [MoodleAssignment] {
        struct Result: Decodable {
            struct Course: Decodable { var id: Int; var assignments: [MoodleAssignment] }
            var courses: [Course]; var warnings: [MoodleWarning]
        }
        let result: Result = try await call("mod_assign_get_assignments", token: credential.token, fields: ["courseids[0]": String(course.id)])
        guard result.warnings.isEmpty, result.courses.allSatisfy({ $0.id == course.id }) else { throw AcademicError.invalidResponse }
        return result.courses.flatMap(\.assignments).map { assignment in
            var assignment = assignment; assignment.courseID = course.id; assignment.courseName = course.fullname; return assignment
        }
    }

    struct Resource: Decodable, Identifiable {
        struct Attachment: Decodable { var filename: String; var fileurl: String?; var type: String?; var content: String?; var mimetype: String? }
        var id: Int; var name: String; var modname: String; var url: String?; var contents: [Attachment]?; var description: String?
    }
    struct ContentSection: Decodable, Identifiable { var id: Int; var name: String; var modules: [Resource]; var summary: String? }
    struct Announcement: Decodable, Identifiable { var id: Int; var name: String; var message: String; var discussion: Int; var attachments: [Resource.Attachment]?; var timemodified: Double? = nil }
    struct Grade: Decodable, Identifiable {
        var id: Int; var itemname: String?; var gradeformatted: String?; var percentageformatted: String?; var gradeishidden: Bool?; var feedback: String?
    }
    func content(courseID: Int, credential: MoodleCredential) async throws -> ([ContentSection], [Announcement]) {
        guard availableFunctions.contains("core_course_get_contents") else { throw AcademicError.unsupported }
        let sections: [ContentSection] = try await call("core_course_get_contents", token: credential.token, fields: ["courseid": String(courseID)])
        guard availableFunctions.contains("mod_forum_get_forums_by_courses"), availableFunctions.contains("mod_forum_get_forum_discussions") else { return (sections, []) }
        struct Forum: Decodable { var id: Int; var course: Int; var type: String }
        let forums: [Forum] = try await call("mod_forum_get_forums_by_courses", token: credential.token, fields: ["courseids[0]": String(courseID)])
        guard forums.allSatisfy({ $0.course == courseID }) else { throw AcademicError.invalidResponse }
        var announcements: [Announcement] = []
        for forum in forums where forum.type == "news" {
            struct Discussions: Decodable { var discussions: [Announcement]; var warnings: [MoodleWarning] }
            let result: Discussions = try await call("mod_forum_get_forum_discussions", token: credential.token,
                fields: ["forumid": String(forum.id), "page": "0", "perpage": "10"])
            guard result.warnings.isEmpty else { throw AcademicError.invalidResponse }
            announcements += result.discussions
        }
        return (sections, announcements)
    }
    func ownGrades(courseID: Int, credential: MoodleCredential) async throws -> [Grade] {
        guard verifiedUserID == credential.userID, availableFunctions.contains("gradereport_user_get_grade_items") else { throw AcademicError.unsupported }
        struct Report: Decodable {
            struct User: Decodable { var courseid: Int; var userid: Int; var gradeitems: [Grade] }
            var usergrades: [User]; var warnings: [MoodleWarning]
        }
        let report: Report = try await call("gradereport_user_get_grade_items", token: credential.token,
            fields: ["courseid": String(courseID), "userid": String(credential.userID)])
        guard report.warnings.isEmpty, report.usergrades.count == 1,
              report.usergrades[0].userid == credential.userID, report.usergrades[0].courseid == courseID else { throw AcademicError.identityChanged }
        return report.usergrades[0].gradeitems.filter { $0.gradeishidden != true }
    }
}

struct SchoolCredential: Codable { var username: String; var password: String }
struct SchoolEnrolment: Codable {
    struct Row: Codable, Identifiable { var code: String; var name: String; var id: String { code } }
    var identity: String; var year: String; var term: String; var courses: [Row]
    var semester: String { "\(year)-\(term)" }
}
enum SchoolReportKind: String, CaseIterable, Codable, Identifiable {
    case grades, rank, graduation
    var id: String { rawValue }
    var title: String { switch self { case .grades: return "歷年與學期成績"; case .rank: return "學期成績排名"; case .graduation: return "畢業門檻預覽" } }
    var function: String { switch self { case .grades: return "5_m"; case .rank: return "8_m"; case .graduation: return "9_m" } }
    var path: String { self == .graduation ? "/pls/univer/query_all_course.judge" : "/pls/univer/u0001.query_all_course.judge" }
}
struct AcademicReportField: Codable, Identifiable {
    var id: String
    var label: String
    var value: String
    var detail: String? = nil
}
struct AcademicReportSubject: Codable, Identifiable {
    var id: String
    var title: String
    var category: String?
    var credits: String?
    var grade: String?
    var details: [String]
}
struct AcademicReportSection: Codable, Identifiable {
    var id: String
    var title: String
    var fields: [AcademicReportField] = []
    var subjects: [AcademicReportSubject] = []
    var notes: [String] = []
}
/// Stable chronological ordering for school year/semester tabs.
enum AcademicReportOrdering {
    private static func dateKey(_ title: String) -> (Int, Int)? {
        let yearPattern = #"(?<![0-9])([0-9]{2,4})(?![0-9])"#
        guard let yearMatch = try? NSRegularExpression(pattern: yearPattern).firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let yearRange = Range(yearMatch.range(at: 1), in: title), let year = Int(title[yearRange]) else { return nil }
        let termPattern = #"第\s*([12一二])\s*學期|([12一二])\s*學期|[-/]\s*([12])(?![0-9])|上學期|下學期"#
        guard let termMatch = try? NSRegularExpression(pattern: termPattern).firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let termRange = Range(termMatch.range, in: title) else { return nil }
        let term = String(title[termRange])
        if term.contains("1") || term.contains("一") || term.contains("上") { return (year, 1) }
        if term.contains("2") || term.contains("二") || term.contains("下") { return (year, 2) }
        return nil
    }
    static func sorted(_ sections: [AcademicReportSection]) -> [AcademicReportSection] {
        sections.enumerated().sorted { lhs, rhs in
            let left = dateKey(lhs.element.title), right = dateKey(rhs.element.title)
            switch (left, right) {
            case let (.some(a), .some(b)):
                if a.0 != b.0 { return a.0 < b.0 }
                if a.1 != b.1 { return a.1 < b.1 }
                return lhs.offset < rhs.offset
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none):
                let leftCumulative = lhs.element.title.contains("累計")
                let rightCumulative = rhs.element.title.contains("累計")
                return leftCumulative == rightCumulative ? lhs.offset < rhs.offset : !leftCumulative
            }
        }.map(\.element)
    }
    static func latestTerm(_ sections: [AcademicReportSection]) -> AcademicReportSection? {
        let ordered = sorted(sections)
        return ordered.last(where: { dateKey($0.title) != nil }) ?? ordered.first
    }
}

struct SchoolReport: Codable, Identifiable {
    var kind: SchoolReportKind
    var checkedAt: Date
    var sections: [AcademicReportSection]?
    var parserVersion: Int? = nil
    // Decode old build-12 caches only. New responses never store HTML.
    var html: String?
    var id: String { kind.rawValue }
    var isNative: Bool { sections?.isEmpty == false }
    var isCurrent: Bool { isNative && (kind != .graduation || parserVersion == 4) && (kind != .grades || parserVersion == 5) }
    func migrated() throws -> SchoolReport {
        if isNative { return self }
        guard let html else { throw AcademicError.invalidResponse }
        return try AcademicReportParser.parse(html, kind: kind, checkedAt: checkedAt)
    }
}

/// Contracts observed on the authenticated school pages; no page rendering or JavaScript.
enum AcademicReportParser {
    static func parse(_ html: String, kind: SchoolReportKind, checkedAt: Date = Date()) throws -> SchoolReport {
        guard html.utf8.count <= 8_388_608 else { throw AcademicError.invalidResponse }
        let document = try SwiftSoup.parse(html)
        try document.select("script,style,form,input,button,iframe,object").remove()
        // The school publishes the GPA-labelled summary in the English footer.
        // Capture its exact values before removing duplicate translated content.
        let officialFooters = kind == .grades ? try gradeFooters(document) : [:]
        try document.select(".lang-en-US").remove()
        let sections: [AcademicReportSection]
        switch kind {
        case .grades: sections = try grades(document, officialFooters: officialFooters)
        case .rank: sections = try ranks(document)
        case .graduation: sections = try graduation(document)
        }
        guard !sections.isEmpty, Set(sections.map(\.id)).count == sections.count else { throw AcademicError.unsupported }
        return SchoolReport(kind: kind, checkedAt: checkedAt, sections: sections, parserVersion: kind == .grades ? 5 : 4, html: nil)
    }
    private static func text(_ node: Element, _ selector: String) throws -> String {
        try node.select(selector).first()?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    private static func distinct(_ values: [String]) -> [String] {
        var seen = Set<String>(); return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    private static func gradeFooters(_ document: Document) throws -> [String: String] {
        var values: [String: String] = [:]
        for (index, card) in try document.select(".card.my-4").enumerated() {
            guard let table = try card.select("table.table-striped").first() else { continue }
            for row in try table.select("tfoot > tr.lang-en-US") {
                let cells = try row.select("td")
                guard cells.count == 5,
                      try cells[0].text().range(of: "GPA|績點", options: [.regularExpression, .caseInsensitive]) != nil else { continue }
                for semester in 1...2 {
                    let raw = try cells[semester * 2].text().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !raw.isEmpty { values["grades.\(index).\(semester)"] = raw }
                }
            }
        }
        return values
    }
    private static func grades(_ document: Document, officialFooters: [String: String]) throws -> [AcademicReportSection] {
        var output: [AcademicReportSection] = []
        for (index, card) in try document.select(".card.my-4").enumerated() {
            let year = try text(card, ".card-title")
            guard !year.isEmpty, let table = try card.select("table.table-striped").first() else { throw AcademicError.unsupported }
            let headers = try table.select("tr").filter { try $0.select("th").count == 6 }
            guard let header = headers.first, try header.select("th").map({ try $0.text() }) == ["類別", "科目名稱", "學分", "成績", "學分", "成績"] else { throw AcademicError.unsupported }
            for semester in 1...2 {
                let selector = ".sem\(semester)bg"
                var section = AcademicReportSection(id: "grades.\(index).\(semester)", title: "\(year) · 第\(semester)學期")
                for (rowIndex, row) in try table.select("tr").enumerated() {
                    let cells = try row.select("td")
                    guard !cells.isEmpty else { continue }
                    let values = try row.select("td\(selector)").map { try $0.text() }
                    if cells.count == 6, cells[1].hasClass("text-left") {
                        guard values.count == 2 else { throw AcademicError.unsupported }
                        if values.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
                        let title = try cells[1].text()
                        guard !title.isEmpty else { throw AcademicError.unsupported }
                        section.subjects.append(.init(id: "\(section.id).\(rowIndex)", title: title,
                            category: try cells[0].text(), credits: values[0], grade: values[1], details: []))
                    } else if !values.isEmpty {
                        let label = try cells.filter { !$0.hasClass("sem1bg") && !$0.hasClass("sem2bg") }.map { try $0.text() }.joined(separator: " ")
                        let value = values.joined(separator: " / ")
                        if !label.isEmpty && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            section.fields.append(.init(id: "\(section.id).summary.\(rowIndex)", label: label, value: value))
                        }
                    }
                }
                if let raw = officialFooters[section.id] {
                    section.fields.insert(.init(id: "\(section.id).officialGPA", label: "學期平均／GPA", value: raw, detail: "校方頁尾原值，未自行換算"), at: 0)
                }
                if !section.subjects.isEmpty || !section.fields.isEmpty { output.append(section) }
            }
        }
        return output
    }
    private static func ranks(_ document: Document) throws -> [AcademicReportSection] {
        var output: [AcademicReportSection] = []
        for (index, card) in try document.select(".container.my-2 > .card").enumerated() {
            var heading = try card.previousElementSibling()
            while let element = heading, element.tagName() != "h6" { heading = try element.previousElementSibling() }
            let year = try heading?.text() ?? ""
            guard !year.isEmpty else { throw AcademicError.unsupported }
            for (termIndex, sheet) in try card.select(".datasheets").enumerated() {
                let term = try text(sheet, "strong")
                guard !term.isEmpty || sheet.hasClass("card-body") else { throw AcademicError.unsupported }
                var section = AcademicReportSection(id: "rank.\(index).\(termIndex)", title: term.isEmpty ? year : "\(year) · \(term)")
                for (rowIndex, row) in try sheet.select("ul.datarows > li").enumerated() {
                    let value = try row.text()
                    guard !value.isEmpty else { continue }
                    let parts = value.components(separatedBy: CharacterSet(charactersIn: "：:"))
                    let label = parts.count > 1 ? parts[0] : (rowIndex == 0 ? "成績資訊" : "排名資訊")
                    section.fields.append(.init(id: "\(section.id).\(rowIndex)", label: label,
                        value: parts.count > 1 ? parts.dropFirst().joined(separator: "：").trimmingCharacters(in: .whitespacesAndNewlines) : value))
                }
                if !section.fields.isEmpty { output.append(section) }
            }
        }
        return output
    }
    private static func graduation(_ document: Document) throws -> [AcademicReportSection] {
        var output: [AcademicReportSection] = []
        // Read the school's own summary card; do not add or infer credits ourselves.
        let headings = try document.select(".row_progress .grid_stat_item_title")
        for (label, id) in [("已累計總學分", "summary_total"), ("系必修", "summary_required"),
                            ("系選修", "summary_option"), ("其他學分", "summary_other")] {
            let matches = try headings.filter { try $0.text().trimmingCharacters(in: .whitespacesAndNewlines) == label }
            guard matches.count <= 1 else { throw AcademicError.unsupported }
            guard let heading = matches.first else { continue }
            var container = heading.parent()
            while let current = container, !current.hasClass("flex_item_col") { container = current.parent() }
            guard let container else { throw AcademicError.unsupported }
            let boxes = try container.select(".credit_box")
            guard boxes.count == 1, let box = boxes.first else { throw AcademicError.unsupported }
            let values = try box.select(".main_credit")
            let value: String
            var fallbackContext = ""
            if values.count == 1, let main = values.first {
                value = try main.text().trimmingCharacters(in: .whitespacesAndNewlines)
            } else if values.isEmpty {
                // Accept only a single number, optionally followed by one / target.
                let raw = try box.text().trimmingCharacters(in: .whitespacesAndNewlines)
                let pattern = id == "summary_total" ? "^[0-9]+(?:\\.[0-9]+)?$" : "^[0-9]+(?:\\.[0-9]+)?(?:\\s*/\\s*[0-9]+(?:\\.[0-9]+)?)?$"
                guard raw.range(of: pattern, options: .regularExpression) != nil else { throw AcademicError.unsupported }
                let parts = raw.split(separator: "/", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                value = parts[0]
                if parts.count == 2 { fallbackContext = "/ " + parts[1] }
            } else { throw AcademicError.unsupported }
            guard !value.isEmpty else { throw AcademicError.unsupported }
            let officialContext = try text(container, id == "summary_total" ? ".credit_count" : ".total_credit")
            let context = officialContext.isEmpty ? fallbackContext : officialContext
            var section = AcademicReportSection(id: id, title: label)
            section.fields.append(.init(id: "\(id).value", label: label, value: value,
                                        detail: context.isEmpty ? nil : context))
            output.append(section)
        }
        // These status rows are school statements, not an app eligibility calculation.
        let requirementTitles = ["外語能力指標檢核", "校定程式設計能力", "學分學程、微學程"]
        var requirementFields: [AcademicReportField] = []
        for (index, row) in try document.select(".item_ul > .item_li").enumerated() {
            let label = try text(row, ".item_title")
            guard requirementTitles.contains(where: { label.hasPrefix($0) }) else { continue }
            let full = try row.text()
            guard full.hasPrefix(label) else { continue }
            let status = String(full.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !status.isEmpty, !requirementFields.contains(where: { $0.label == label }) else { continue }
            requirementFields.append(.init(id: "requirements.\(index)", label: label, value: status))
        }
        if !requirementFields.isEmpty {
            var section = AcademicReportSection(id: "requirements", title: "畢業條件")
            section.fields = requirementFields
            output.append(section)
        }
        // Category values are independent of the accumulated total.
        for (id, title) in [("tag_total", "校訂必修學分"), ("tag_chinese", "國文"), ("tag_english", "英文"), ("tag_pe", "體育"), ("tag_general", "通識"), ("mini_general", "通識分類")] {
            guard let node = try document.select("#\(id)").first() else { continue }
            var section = AcademicReportSection(id: id, title: title)
            for (index, box) in try node.select(".credit_box").enumerated() {
                let main = try text(box, ".main_credit"), total = try text(box, ".total_credit")
                if !main.isEmpty {
                    section.fields.append(.init(id: "\(id).\(index)", label: index == 0 ? "學分進度" : "分類進度",
                        value: main, detail: total.isEmpty ? nil : total))
                }
            }
            if !section.fields.isEmpty { output.append(section) }
        }
        for id in ["required", "option", "common", "other"] {
            guard let node = try document.select("section#\(id)").first() else { throw AcademicError.unsupported }
            let title = try text(node, ".collapse_title")
            guard !title.isEmpty else { throw AcademicError.unsupported }
            var section = AcademicReportSection(id: id, title: title)
            section.notes = distinct(try node.select(".collapse_info .illus_text").map { try $0.text() })
            for (index, item) in try node.select(".collapse_ul_header .collapse_col_item").enumerated() {
                let values = try item.select("span").map { try $0.text() }
                guard values.count == 2 else { throw AcademicError.unsupported }
                section.fields.append(.init(id: "\(id).metric.\(index)", label: values[0], value: values[1]))
            }
            for (index, row) in try node.select(".subject_li").enumerated() {
                let name = try text(row, ".subject_title")
                guard !name.isEmpty else { throw AcademicError.unsupported }
                let details = distinct(try row.select(".subject_state").map { try $0.text() })
                section.subjects.append(.init(id: "\(id).subject.\(index)", title: name, category: nil, credits: nil, grade: nil, details: details))
            }
            let sums = distinct(try node.select(".collapse_ul_footer").map { try $0.text() })
            section.notes += sums
            output.append(section)
        }
        return output
    }
}

final class SchoolAPI {
    let http = AcademicHTTP()
    deinit { http.close() }
    private let origin = "https://my.ntpu.edu.tw"
    private var menus: [[String: Any]]?
    private var authenticatedHosts = Set<String>()
    private var sessionIdentity: String?
    private func authenticate(_ credential: SchoolCredential) async throws {
        if menus != nil { return }
        let (formData, _) = try await http.request(URL(string: origin + "/login")!)
        let document = try SwiftSoup.parse(String(decoding: formData, as: UTF8.self))
        guard let form = try document.select("form[method=POST], form[method=post]").first(),
              ["/login", origin + "/login"].contains(try form.attr("action")),
              let token = try form.select("input[name=_token]").first()?.attr("value"), !token.isEmpty else { throw AcademicError.unsupported }
        let (home, response) = try await http.request(URL(string: origin + "/login")!, fields: ["_token": token, "username": credential.username, "password": credential.password])
        let page = try SwiftSoup.parse(String(decoding: home, as: UTF8.self))
        guard response.url?.path != "/login", try !page.select("form[action$=/logout], a[href$=/logout]").isEmpty(),
              try page.select("input[name=password]").isEmpty() else { throw AcademicError.loginRequired }
        let pattern = #"\bvar arr\s*=\s*(\[.*?\]);"#
        let text = String(decoding: home, as: UTF8.self), ns = text as NSString
        let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let raw = ns.substring(with: match.range(at: 1)).data(using: .utf8),
              let menus = try JSONSerialization.jsonObject(with: raw) as? [[String: Any]] else { throw AcademicError.unsupported }
        self.menus = menus
    }
    private func readPage(_ credential: SchoolCredential, path: String, function: String) async throws -> (String, String) {
        try await authenticate(credential)
        let destination = "https://ohs01.ntpu.edu.tw\(path)?func=\(function)"
        guard menus?.filter({ $0["url"] as? String == destination && $0["project_id"] as? Int == 10 }).count == 1 else { throw AcademicError.unsupported }
        var components = URLComponents(string: origin + "/get-projects/10")!
        components.queryItems = [URLQueryItem(name: "url", value: destination)]
        let (bridge, _) = try await http.request(components.url!)
        struct Bridge: Decodable { var form_url: String; var base_url: String; var formData: [String: String] }
        let descriptor = try JSONDecoder().decode(Bridge.self, from: bridge)
        guard let login = URL(string: descriptor.form_url), ["cof.ntpu.edu.tw", "ohs01.ntpu.edu.tw"].contains(login.host ?? ""),
              descriptor.form_url == "https://\(login.host!)/pls/pm/stud_system.signin",
              descriptor.base_url == "https://\(login.host!)\(path)?func=\(function)",
              Set(descriptor.formData.keys) == ["id", "pw"], let identity = descriptor.formData["id"], !identity.isEmpty,
              descriptor.formData["pw"]?.isEmpty == false else { throw AcademicError.unsupported }
        guard sessionIdentity == nil || sessionIdentity == identity else { throw AcademicError.identityChanged }
        sessionIdentity = identity
        if !authenticatedHosts.contains(login.host!) {
            _ = try await http.request(login, fields: descriptor.formData)
            authenticatedHosts.insert(login.host!)
        }
        let (data, _) = try await http.request(URL(string: descriptor.base_url)!)
        return (try CourseCatalogService.decode(data), identity)
    }
    func enrolment(_ credential: SchoolCredential) async throws -> SchoolEnrolment {
        let (html, identity) = try await readPage(credential, path: "/pls/univer/u0001.query_all_course.judge", function: "3_m")
        return try Self.parseEnrolment(html, identity: identity)
    }
    func report(_ kind: SchoolReportKind, credential: SchoolCredential, expectedIdentity: String) async throws -> SchoolReport {
        let (html, identity) = try await readPage(credential, path: kind.path, function: kind.function)
        guard AcademicKeychain.key(identity) == expectedIdentity else { throw AcademicError.identityChanged }
        return try Self.parseReport(html, identity: identity, kind: kind)
    }
    static func parseReport(_ html: String, identity: String, kind: SchoolReportKind) throws -> SchoolReport {
        guard !identity.isEmpty, html.range(of: "(?<![0-9])" + NSRegularExpression.escapedPattern(for: identity) + "(?![0-9])", options: .regularExpression) != nil else { throw AcademicError.identityChanged }
        return try AcademicReportParser.parse(html, kind: kind)
    }
    static func parseEnrolment(_ html: String, identity: String) throws -> SchoolEnrolment {
        let page = try SwiftSoup.parse(html)
        let rows = try page.select("tr")
        let expected = ["", "科目名稱(與組別)", "核課資訊", "授課老師", "上課時間@教室", "類別", "學分/時數", "開課系級", "備註"]
        guard let first = rows.first(), try first.select("td,th").map({ try $0.text() }) == expected,
              rows.count > 1, rows.count <= 301 else { throw AcademicError.unsupported }
        var semesters = Set<String>()
        for link in try page.select("a[href]") {
            let href = try link.attr("href")
            guard href.hasPrefix("../univer/course_check_m.dt_e?") else { continue }
            let query = URLComponents(string: href)?.queryItems ?? []
            func one(_ name: String) -> String? { let values = query.filter { $0.name == name }; return values.count == 1 ? values.first?.value : nil }
            guard one("stud_no") == identity, let year = one("year1"), year.range(of: #"^1\d{2}$"#, options: .regularExpression) != nil,
                  let term = one("term1"), ["1", "2"].contains(term) else { throw AcademicError.identityChanged }
            semesters.insert("\(year)-\(term)")
        }
        guard semesters.count == 1, let semester = semesters.first else { throw AcademicError.unsupported }
        let parts = semester.split(separator: "-")
        let regex = try NSRegularExpression(pattern: #"\(([A-Z]\d{4})\)\s*$"#)
        var courses: [SchoolEnrolment.Row] = []
        for row in rows.dropFirst() {
            let cells = try row.select("td").map { try $0.text() }
            guard cells.count == 9, cells[2] == "已核准" else { throw AcademicError.unsupported }
            let name = cells[1] as NSString
            guard let match = regex.firstMatch(in: cells[1], range: NSRange(location: 0, length: name.length)) else { throw AcademicError.unsupported }
            courses.append(.init(code: name.substring(with: match.range(at: 1)), name: name.substring(to: match.range.location)))
        }
        guard Set(courses.map(\.code)).count == courses.count else { throw AcademicError.unsupported }
        return SchoolEnrolment(identity: identity, year: String(parts[0]), term: String(parts[1]), courses: courses)
    }
}
