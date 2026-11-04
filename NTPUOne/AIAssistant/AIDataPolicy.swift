import Foundation

enum AIDataSource: String, CaseIterable, Codable {
    case courses, memos, enrolment, moodleTasks, moodleContent
    case moodleGrades, schoolGrades, ranking, graduation
    case announcements, officialNews, calendar, weather, bikes, restaurants
    case preferences, campus, courseCatalog, deviceSettings, restaurantReviews, announcementImages

    var isSensitive: Bool { [.moodleGrades, .schoolGrades, .ranking, .graduation].contains(self) }
    var title: String {
        switch self {
        case .courses: return "手機課表"
        case .memos: return "備忘錄與排程"
        case .enrolment: return "正式修課與學期"
        case .moodleTasks: return "Moodle 作業與繳交狀態"
        case .moodleContent: return "Moodle 課程公告與教材"
        case .moodleGrades: return "Moodle 本人成績"
        case .schoolGrades: return "歷年與學期成績"
        case .ranking: return "學期排名"
        case .graduation: return "畢業門檻與學分"
        case .announcements: return "首頁公告與活動"
        case .officialNews: return "校方官方新聞"
        case .calendar: return "行事曆連結"
        case .weather: return "校園天氣"
        case .bikes: return "YouBike"
        case .restaurants: return "校園周邊餐廳"
        case .preferences: return "收藏、興趣與新生清單"
        case .campus: return "校園設施與常用連結"
        case .courseCatalog: return "公開開課查詢"
        case .deviceSettings: return "本機通知設定"
        case .restaurantReviews: return "餐廳公開評論"
        case .announcementImages: return "公告圖片文字"
        }
    }
    static func allowed(includeSensitive: Bool) -> Set<AIDataSource> {
        Set(allCases.filter { includeSensitive || !$0.isSensitive })
    }
}

enum AIDataPermissions {
    static func allowed(master: Bool, courses: Bool, memos: Bool, moodle: Bool, school: Bool, grades: Bool) -> Set<AIDataSource> {
        guard master else { return [] }
        var sources = AIDataSource.allowed(includeSensitive: grades)
        if !courses { sources.remove(.courses) }
        if !memos { sources.remove(.memos) }
        if !moodle { sources.subtract([.moodleTasks, .moodleContent, .moodleGrades]) }
        if !school { sources.subtract([.enrolment, .schoolGrades, .ranking, .graduation]) }
        return sources
    }
}

/// Explicitly selected bytes; never persisted in chat history or sent to a planner.
struct AIUploadAttachment: Identifiable {
    let id = UUID()
    let name: String
    let mimeType: String
    let data: Data
    var isMoodle = false
    var uploadName: String {
        String(name.map { "<>\"'&/\\".contains($0) ? "_" : $0 })
    }
    var isValid: Bool {
        !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) && !data.isEmpty && data.count <= 20 * 1024 * 1024 && !name.isEmpty && name.count <= 200
            && !mimeType.isEmpty && mimeType.count <= 120
    }
}

struct AIContextPayload {
    var text: String
    var image: Data? = nil
    var attachment: AIUploadAttachment? = nil
    static let empty = AIContextPayload(text: "")
}

struct AIContextRequest {
    var sources: Set<AIDataSource>
    var courseKeyword: String = ""
    // Native-only: model JSON cannot opt into automatic arrival collection.
    var isArrival = false
    var webQuery: String? = nil
    // Native-only: automatic attachment access follows the user's Moodle content request.
    var readMoodleFiles = false
    var moodleFileKeyword = ""
    var latestMoodleAnnouncement = false

    /// Model output selects allowed sources and an optional filtered public search query.
    static func parse(_ text: String, allowed: Set<AIDataSource>) -> AIContextRequest? {
        guard text.utf8.count <= 8_192 else { return nil }
        var content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.hasPrefix("```json\n"), content.hasSuffix("```") {
            content = String(content.dropFirst(8).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = content.data(using: .utf8) else { return nil }
        struct Selection: Decodable { var sources: [String]; var courseKeyword: String?; var webQuery: String?; var moodleFileKeyword: String? }
        let names: [String]
        var keyword = ""
        var webQuery: String?
        var fileKeyword = ""
        if let value = try? JSONDecoder().decode(Selection.self, from: data) {
            names = value.sources; keyword = value.courseKeyword ?? ""; webQuery = value.webQuery; fileKeyword = value.moodleFileKeyword ?? ""
        } else if let value = try? JSONDecoder().decode([String].self, from: data) { names = value }
        else { return nil }
        if ["最新", "最近", "公告", "最新公告", "最近公告", "教材", "附件", "檔案"].contains(fileKeyword.trimmingCharacters(in: .whitespacesAndNewlines)) { fileKeyword = "" }
        guard names.count <= 40, keyword.count <= 80, fileKeyword.count <= 100,
              !fileKeyword.contains("://"), !fileKeyword.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              !keyword.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              !keyword.contains("://") else { return nil }
        let sources = Set(names.compactMap(AIDataSource.init(rawValue:))).intersection(allowed)
        return AIContextRequest(sources: sources, courseKeyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines), webQuery: AIWebQueryPolicy.clean(webQuery), moodleFileKeyword: fileKeyword.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum AIContextText {
    static func safe(_ text: String, limit: Int = 800) -> String {
        var value = String(text.prefix(limit))
        // Remove known credential patterns; this is not a guarantee for arbitrary notes.
        for pattern in [#"(?i)(token|wstoken|authorization|sessionid|sesskey|password|passwd)=([^\s&<>\"']+)"#,
                        #"(?i)Bearer\s+[A-Za-z0-9._~+/=-]+"#] {
            value = value.replacingOccurrences(of: pattern, with: "[已隱藏憑證]", options: .regularExpression)
        }
        return value
    }
    static func publicURL(_ value: String) -> String {
        guard var url = URLComponents(string: value), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { return "" }
        url.queryItems = (url.queryItems ?? []).filter {
            !["token", "wstoken", "authorization", "session", "sessionid", "sesskey", "password"].contains($0.name.lowercased())
        }
        url.fragment = nil
        return String((url.string ?? "").prefix(400))
    }
}


/// These routes are app-owned identifiers, never destinations supplied by the model.
enum AIAppPage: String, CaseIterable, Identifiable {
    case home, memo, timetable, community, profile, googleAccount, schoolAccount, grades, graduation
    case announcements, links, bikes, campusMap, checklist, breakfast, lunch, dinner, midnight
    case courseSearch, privacy, feedback, bugReport
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "首頁"; case .memo: return "備忘錄"; case .timetable: return "課表"
        case .community: return "交流區"; case .profile: return "個人頁"
        case .googleAccount: return "Google 帳號登入"
        case .schoolAccount: return "學校帳號與同步"; case .grades: return "成績與排名"
        case .graduation: return "畢業門檻"; case .announcements: return "校方新聞"
        case .links: return "常用連結"; case .bikes: return "YouBike"
        case .campusMap: return "校園地圖"; case .checklist: return "新生清單"
        case .breakfast: return "早餐"; case .lunch: return "午餐"; case .dinner: return "晚餐"
        case .midnight: return "宵夜"
        case .courseSearch: return "課程查詢"; case .privacy: return "隱私設定"
        case .feedback: return "功能建議"; case .bugReport: return "回報問題"
        }
    }
    var guide: String {
        switch self {
        case .home: return "首頁查看公告、天氣、快捷功能與今日資訊"
        case .memo: return "備忘錄查看作業、設定期限與提醒，並可連結課程"
        case .timetable: return "課表查看每週課程，編輯或同步課程"
        case .community: return "交流區瀏覽公開貼文與討論"
        case .profile: return "個人頁進入學校帳號、隱私及其他設定"
        case .googleAccount: return "帳號中心：登入 Google 帳號或管理 App 帳號"
        case .schoolAccount: return "學校帳號與同步：登入、更新本機帳密與同步校務及 Moodle"
        case .grades: return "成績與排名：查看各學期成績或排名"
        case .graduation: return "畢業門檻：查看校方學分和門檻預覽"
        case .announcements: return "校方新聞：瀏覽學校公告"
        case .links: return "常用連結：開啟學校相關網站"
        case .bikes: return "YouBike：查看附近站點、可借與可還數量"
        case .campusMap: return "校園地圖：查看校園設施"
        case .checklist: return "新生清單：查看及勾選準備項目"
        case .breakfast, .lunch, .dinner, .midnight: return "\(title)：查看餐廳、評分及評論"
        case .courseSearch: return "課程查詢：依學年、學期或課名搜尋課程並加入課表"
        case .privacy: return "隱私設定：查看及管理個人資料設定"
        case .feedback: return "功能建議：填寫希望新增的功能"
        case .bugReport: return "回報問題：填寫問題與重現方式"
        }
    }
    static var guideText: String {
        allCases.map { "\($0.rawValue)：\($0.guide)" }.joined(separator: "\n") + """

        補充操作：課程詳情從課表點選課程開啟，可查看已配對的 Moodle 課程內容。備忘錄內可連結課程、設定提醒並依 Moodle 繳交狀態更新；排定的提醒由備忘錄頁的通知清單查看。更新本機學校密碼在學校帳號與同步按「更新本機登入資料」，不會修改校方密碼。AI 資料與成績授權可在聊天標題列的資料設定變更。課表手動刷新位於課表編輯功能。實際功能可能受帳號、權限、網路或功能開關影響。
        """
    }
}


/// Arrival suggestions are read-only and limited to non-grade, non-attachment sources.
enum AIArrivalPolicy {
    static func sources(includePersonal: Bool) -> Set<AIDataSource> {
        includePersonal ? [.courses, .memos, .weather, .restaurants] : [.weather, .restaurants]
    }
    static func shouldGenerate(now: Date, entryAlreadyRequested: Bool, lastAttempt: Date?) -> Bool {
        if entryAlreadyRequested { return false }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < 60 { return false }
        return true
    }
    static func nextCourse(day: String, time: String, now: Date, calendar: Calendar) -> Date? {
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        let fields = time.split(separator: ":").compactMap { Int($0) }
        guard let weekday = weekdays[day.lowercased()], fields.count == 2,
              (0...23).contains(fields[0]), (0...59).contains(fields[1]) else { return nil }
        return calendar.nextDate(after: now, matching: DateComponents(hour: fields[0], minute: fields[1], weekday: weekday), matchingPolicy: .nextTime)
    }
    static func preview(_ text: String) -> String {
        var value = text.replacingOccurrences(of: #"\[\[page:[^\]]+\]\]"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"[\*#`_]+"#, with: "", options: .regularExpression)
        return String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
    }
}

/// Always sent, including when App-data sharing is off. Never derive "today" from model memory.
enum AIClockContext {
    static func timestamp(_ date: Date = Date()) -> String {
        let format = DateFormatter()
        format.calendar = Calendar(identifier: .gregorian)
        format.timeZone = TimeZone(identifier: "Asia/Taipei")!
        format.locale = Locale(identifier: "zh_TW")
        format.dateFormat = "yyyy-MM-dd EEEE HH:mm:ss"
        return format.string(from: date) + "（Asia/Taipei，UTC+08:00）"
    }
    static func prompt(at date: Date = Date()) -> String {
        "[App 即時時鐘] 現在是 " + timestamp(date) + "。今天的日期與星期以此為準；不要沿用舊對話、教材日期或模型記憶。事件本身的日期仍依來源資料。"
    }
}

/// Capability metadata is separate from the snapshots selected for a single question.
enum AIAssistantPersona {
    static func prompt(appDataEnabled: Bool, sensitiveDataEnabled: Bool, allowedSources: Set<AIDataSource>? = nil) -> String {
        let permitted = appDataEnabled ? (allowedSources ?? AIDataSource.allowed(includeSensitive: sensitiveDataEnabled)) : []
        let enabled = AIDataSource.allCases.filter { permitted.contains($0) }.map(\.title).joined(separator: "、")
        return """
        你是 NTPU One App 內的 AI 助理，由校方 NTPU AI 服務提供回答；自我介紹應以「NTPU One 的 AI 助理」為主。
        你可以說明 App 操作、整理課業與校園生活資訊；使用者提問時，手機會依問題選取並查詢已授權的資料，再交給你回答。可支援的來源有：\(AIDataSource.allCases.map(\.title).joined(separator: "、"))。
        目前 App 資料授權：\(appDataEnabled ? "已開啟" : "未開啟")；成績與畢業資料授權：\(appDataEnabled && sensitiveDataEnabled ? "已開啟" : "未開啟")。
        目前可依問題自動選取的來源：\(enabled.isEmpty ? "尚未開啟 App 資料，使用者可在 AI 資料設定開啟" : enabled)。成績、GPA、排名、畢業及 Moodle 成績另外受成績授權控制。
        「本輪沒有附上資料」不等於「無法查詢」或「使用者未授權」。回答你是誰／能做什麼時，簡潔介紹能力與幾個可問的例子，不要固定附上無法查看個人資料的制式段落；權限已開啟時應說可以依問題查詢。未開啟時才說明需先啟用對應開關。
        只有本輪實際提供的資料才能作為查詢結果。來源未連結、未同步、過期或取用失敗時說明具體限制，不假裝查過，不編造數字；已授權也不代表資料必然可取得。教材只能依本輪實際提供的內文、原始附件或附件文字回答；只有本輪明確附上原檔或提供文字擷取結果時才能說讀取過檔案。若未取得附件、內容被截斷或校方無法解析格式，必須說明，不能宣稱已讀完整份附件。
        你可提供原生頁面開啟按鈕，也可提出課表或備忘錄的變更建議；必須由使用者在 App 預覽並確認，不能自行儲存或宣稱已完成。成績與設定不可修改。以下是可開啟頁面及用法：
        \(AIAppPage.guideText)
        需要開頁面時，在回答最後輸出 [[page:代碼]]，代碼僅限上述清單。當使用者明確要求新增、修改或刪除課表或備忘錄時，在回答最後另外輸出一個 <ntpu-change>JSON</ntpu-change>；單筆使用 JSON 物件，多筆使用 JSON 陣列（最多 20 筆），可逐筆或整批預覽並確認；每個物件僅接受 kind（memo 或 course）、operation（create、edit 或 delete）、target（既有項目完整名稱）、title、content、course（使用者要連結的既有課程名稱，必須逐字取自本輪提供的手機課表；不確定或未提供課表時省略）、weekday（Monday 至 Saturday）、period（1 到 13）、location、teacher、deadline（含時區的 ISO8601）。新增備忘錄或待辦時，先查看本輪提供的手機課表；若使用者提到課程且能明確對應，填入 course。不得猜課程或自行建立課程。未知欄位省略，不得猜日期或目標；資訊不足時請詢問。這只是建議，不代表已執行。使用繁體中文，簡潔回答，只提出使用者要求的項目，不增加多餘任務。
        """
    }
}

/// A model-suggested operation is untrusted data and can only open a review UI.
struct AIChangeProposal: Decodable, Identifiable {
    enum Kind: String, Decodable { case memo, course }
    enum Operation: String, Decodable { case create, edit, delete }
    var kind: Kind
    var operation: Operation
    var target: String?
    var title: String?
    var content: String?
    var course: String?
    var weekday: String?
    var period: Int?
    var location: String?
    var teacher: String?
    var deadline: String?
    // Assigned locally from message ID + proposal position; never accepted from model JSON.
    var executionID: String? = nil
    enum CodingKeys: String, CodingKey {
        case kind, operation, target, title, content, course, weekday, period, location, teacher, deadline
    }
    var id: String { "\(kind.rawValue):\(operation.rawValue):\(target ?? ""):\(title ?? "")" }
    static func extractAll(from text: String) -> [AIChangeProposal]? {
        guard text.utf8.count <= 100_000,
              let start = text.range(of: "<ntpu-change>"),
              let end = text.range(of: "</ntpu-change>", range: start.upperBound..<text.endIndex),
              text.range(of: "<ntpu-change>", range: start.upperBound..<text.endIndex) == nil,
              text.range(of: "</ntpu-change>", range: end.upperBound..<text.endIndex) == nil else { return nil }
        let raw = String(text[start.upperBound..<end.lowerBound])
        guard raw.utf8.count <= 32_768, let data = raw.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        let values: [Self]
        if let array = try? decoder.decode([Self].self, from: data) { values = array }
        else if let single = try? decoder.decode(Self.self, from: data) { values = [single] }
        else { return nil }
        guard !values.isEmpty, values.count <= 20, values.allSatisfy({ value in
            [value.target, value.title, value.content, value.weekday, value.location, value.teacher, value.deadline]
                .compactMap({ $0 }).allSatisfy({ $0.count <= 500 && !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && $0 != "\n" }) }) &&
            (value.period.map({ (1...13).contains($0) }) ?? true)
        }) else { return nil }
        return values
    }
    static func extract(from text: String) -> AIChangeProposal? {
        guard let values = extractAll(from: text), values.count == 1 else { return nil }
        return values.first
    }
    static func displayText(_ text: String) -> String {
        guard let start = text.range(of: "<ntpu-change>") else { return text }
        guard let end = text.range(of: "</ntpu-change>", range: start.upperBound..<text.endIndex) else {
            return String(text[..<start.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if text.range(of: "<ntpu-change>", range: end.upperBound..<text.endIndex) != nil ||
           text.range(of: "</ntpu-change>", range: end.upperBound..<text.endIndex) != nil {
            return String(text[..<start.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var result = text; result.removeSubrange(start.lowerBound..<end.upperBound)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The identity belongs to a local chat turn, never to model-generated content.
struct AIChangeExecutionState {
    private var applied: Set<String> = []
    private func key(_ proposal: AIChangeProposal, account: String) -> String? {
        proposal.executionID.map { account + "|" + $0 }
    }
    func contains(_ proposal: AIChangeProposal, account: String) -> Bool {
        key(proposal, account: account).map { applied.contains($0) } ?? false
    }
    mutating func mark(_ proposals: [AIChangeProposal], account: String) {
        applied.formUnion(proposals.compactMap { key($0, account: account) })
    }
}

/// Local welcome and handle decisions do not send messages or depend on a signed-in session.
enum AIWelcomePolicy {
    static func shouldShow(messageCount: Int, replying: Bool, preparingArrival: Bool) -> Bool {
        messageCount == 0 && !replying && !preparingArrival
    }
}
enum AIPanelDismissPolicy {
    static func shouldDismiss(horizontal: CGFloat, vertical: CGFloat, predictedVertical: CGFloat, threshold: CGFloat) -> Bool {
        let dominantDirection = vertical != 0 ? vertical : predictedVertical
        let projectedDistance = max(vertical, predictedVertical)
        return dominantDirection > 0 && abs(dominantDirection) > abs(horizontal) && projectedDistance >= threshold
    }
}

enum AIWebQueryPolicy {
    static func clean(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty, value.count <= 160,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              value.range(of: #"(?i)(@|://|password|token|cookie|密碼|學號|身分證|我的成績|我的課表|\d{6,})"#, options: .regularExpression) == nil else { return nil }
        return value
    }
}


/// Match only names and labels returned by Moodle, never model-provided URLs.
enum AIMoodleAttachmentSelection {
    static func select(keyword: String, names: [String], labels: [String]) -> Int? {
        guard names.count == labels.count else { return nil }
        let key = normalize(keyword)
        guard !key.isEmpty else { return names.count == 1 ? 0 : nil }
        let exact = names.indices.filter { normalize(names[$0]) == key }
        if !exact.isEmpty { return exact.count == 1 ? exact[0] : nil }
        let filename = names.indices.filter { normalize(names[$0]).contains(key) }
        if !filename.isEmpty { return filename.count == 1 ? filename[0] : nil }
        let context = labels.indices.filter { normalize(labels[$0]).contains(key) }
        return context.count == 1 ? context[0] : nil
    }
    private static func normalize(_ value: String) -> String {
        value.folding(options: [.widthInsensitive, .caseInsensitive], locale: Locale(identifier: "zh_TW"))
            .filter { !$0.isWhitespace && !$0.isPunctuation }
    }
}
