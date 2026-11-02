import Foundation

enum AcademicError: LocalizedError {
    case invalidResponse, loginRequired, identityChanged, unsupported, storage, conflict
    var errorDescription: String? {
        switch self {
        case .loginRequired: return "學校連線已失效，請重新連結帳號。"
        case .identityChanged: return "學校帳號與先前不同，已停止更新。請先解除舊連結。"
        case .unsupported: return "校方回傳的格式或登入目的地尚未驗證，已保留原有資料。"
        case .storage: return "無法安全保存資料，本次未完成同步。"
        case .conflict: return "資料已變動或時段有衝突，請重新檢查預覽。"
        case .invalidResponse: return "暫時無法取得完整學校資料，已保留上次成功結果。"
        }
    }
}

enum AcademicPolicy {
    static func currentTerm(at date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let year = calendar.component(.year, from: date) - 1911
        return calendar.component(.month, from: date) >= 8 ? "\(year)-1" : "\(year - 1)-2"
    }
    static func needsRefresh(last: Date?, now: Date = Date(), interval: TimeInterval) -> Bool {
        guard let last else { return true }
        return now < last || now.timeIntervalSince(last) >= interval
    }
    static func reliableSubmission(status: String?, isTeam: Bool) -> Bool {
        !isTeam && status == "submitted"
    }
}

struct AcademicMeeting: Hashable, Codable {
    var day: String
    var slot: Int
    var location: String

    /// Reject partial or ambiguous parsing instead of inventing a day or period.
    static func parse(_ text: String) throws -> [AcademicMeeting] {
        let days = ["一": "Monday", "二": "Tuesday", "三": "Wednesday", "四": "Thursday",
                    "五": "Friday", "六": "Saturday"]
        let pattern = #"^(?:每週|每周|星期|週)([一二三四五六])\s*([0-9]+(?:\s*[~～\-－、,，]\s*[0-9]+)*)\s+(.+)$"#
        let expression = try NSRegularExpression(pattern: pattern)
        var result: [AcademicMeeting] = []
        for line in text.components(separatedBy: .newlines).map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
            let ns = line as NSString
            guard let match = expression.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
                  let day = days[ns.substring(with: match.range(at: 1))] else { throw AcademicError.unsupported }
            let room = ns.substring(with: match.range(at: 3))
            guard !room.contains("每週"), !room.contains("星期"), !room.contains("週") else { throw AcademicError.unsupported }
            let periods = ns.substring(with: match.range(at: 2)).replacingOccurrences(of: " ", with: "")
            var slots: [Int] = []
            for part in periods.components(separatedBy: CharacterSet(charactersIn: "、,，")) {
                let range = part.components(separatedBy: CharacterSet(charactersIn: "~～-－"))
                guard (1...2).contains(range.count), let start = Int(range[0]), (1...13).contains(start),
                      let end = Int(range.last!), (start...13).contains(end) else { throw AcademicError.unsupported }
                slots.append(contentsOf: start...end)
            }
            guard Set(slots).count == slots.count else { throw AcademicError.unsupported }
            result += slots.map { AcademicMeeting(day: day, slot: $0, location: room) }
        }
        guard !result.isEmpty, Set(result.map { "\($0.day):\($0.slot)" }).count == result.count else { throw AcademicError.unsupported }
        return result
    }
}

struct AcademicImportSlot {
    var id: String
    var name: String
    var day: String
    var period: Int
    var fingerprint: String
}
enum AcademicImportDecision: Equatable {
    case add, update(String), preserve(String), link(String), conflict
}
enum AcademicImportPolicy {
    static func decide(proposedID: String, name: String, day: String, period: Int,
                       existing: [AcademicImportSlot], sourceIDs: Set<String>, previous: [String: String]) -> AcademicImportDecision {
        // A manually moved/edited imported row keeps its ID and private edits.
        if let row = existing.first(where: { $0.id == proposedID }) {
            guard let baseline = previous[row.id] else { return .link(row.id) }
            if row.fingerprint != baseline { return .preserve(row.id) }
        }
        let occupied = existing.filter { $0.day == day && $0.period == period }
        guard occupied.count <= 1 else { return .conflict }
        guard let row = occupied.first else { return .add }
        if sourceIDs.contains(row.id), let baseline = previous[row.id] {
            return row.fingerprint == baseline ? .update(row.id) : .preserve(row.id)
        }
        return row.name == name ? .link(row.id) : .conflict
    }
}
