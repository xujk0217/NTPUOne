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
        struct Attachment: Decodable { var filename: String }
        var id: Int; var name: String; var modname: String; var url: String?; var contents: [Attachment]?
    }
    struct ContentSection: Decodable, Identifiable { var id: Int; var name: String; var modules: [Resource] }
    struct Announcement: Decodable, Identifiable { var id: Int; var name: String; var message: String; var discussion: Int }
    struct Grade: Decodable, Identifiable {
        var id: Int; var itemname: String?; var gradeformatted: String?; var percentageformatted: String?; var gradeishidden: Bool?
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
struct SchoolReport: Codable, Identifiable {
    var kind: SchoolReportKind
    var html: String
    var checkedAt: Date
    var id: String { kind.rawValue }
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
        let document = try SwiftSoup.parse(html)
        let text = try document.text()
        switch kind {
        case .grades:
            guard text.contains("成績"), text.contains("學分數"), try document.select("tr").count > 1 else { throw AcademicError.unsupported }
        case .rank:
            guard text.contains("排名"), try !document.select("h6").isEmpty() else { throw AcademicError.unsupported }
        case .graduation:
            guard text.contains("學分"), text.contains("畢業"), try !document.select("section").isEmpty() else { throw AcademicError.unsupported }
        }
        try document.select("script,style,iframe,frame,object,embed,form,input,button,link,meta,base,img").remove()
        for anchor in try document.select("a") { try anchor.removeAttr("href") }
        let whitelist = try Whitelist.relaxed().addTags("section").addAttributes(":all", "class")
        guard let clean = try SwiftSoup.clean(try document.body()?.html() ?? "", whitelist), !clean.isEmpty else { throw AcademicError.unsupported }
        let csp = "default-src 'none'; script-src 'none'; style-src 'unsafe-inline'; img-src 'none'; connect-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'"
        let output = "<html><head><meta name='viewport' content='width=device-width, initial-scale=1'><meta http-equiv='Content-Security-Policy' content=\"\(csp)\"><style>body{font:16px -apple-system;padding:12px;color:#202124;background:#fff;overflow-wrap:anywhere}table{border-collapse:collapse;display:block;overflow:auto;width:100%}td,th{border:1px solid #ddd;padding:8px}h1,h2,h3,h6{font-size:19px;margin-top:24px}section,.card{padding:12px;margin:10px 0;border:1px solid #ddd;border-radius:12px}li{margin:6px 0}.row{margin:12px 0}p{line-height:1.6}</style></head><body>\(clean)</body></html>"
        return .init(kind: kind, html: output, checkedAt: Date())
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
