import Foundation

struct CommunityAuthorOwnershipState {
    var uid: String?
    var topicIDs = Set<String>()
    var replyKeys = Set<String>()

    func ownsTopic(_ id: String, activeUID: String?) -> Bool {
        guard let uid, !uid.isEmpty, activeUID == uid else { return false }
        return topicIDs.contains(id)
    }
    func ownsReply(topicID: String, replyID: String, activeUID: String?) -> Bool {
        guard let uid, !uid.isEmpty, activeUID == uid else { return false }
        return replyKeys.contains("\(topicID)/\(replyID)")
    }
    static func reconciledNickname(remote: String?, localAtRequest: String, localNow: String) -> String {
        if localAtRequest != localNow { return localNow }
        let remote = remote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return remote.isEmpty ? localNow : remote
    }
    static func displayName(stored: String, nickname: String, isOwner: Bool) -> String {
        let nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return isOwner && !nickname.isEmpty ? nickname : stored
    }
}

/// Independent fields must not cancel each other's pending public-display updates.
struct CommunityDisplayRevisions {
    struct Token {
        let uid: String
        let fields: [String: Int]
    }
    private var revisions: [String: [String: Int]] = [:]
    mutating func begin(uid: String, fields: Set<String>) -> Token {
        var values: [String: Int] = [:]
        for field in fields {
            let next = (revisions[uid]?[field] ?? 0) + 1
            revisions[uid, default: [:]][field] = next
            values[field] = next
        }
        return Token(uid: uid, fields: values)
    }
    func isCurrent(_ token: Token, field: String) -> Bool {
        guard let version = token.fields[field] else { return false }
        return revisions[token.uid]?[field] == version
    }
    func hasCurrentFields(_ token: Token) -> Bool {
        token.fields.keys.contains { isCurrent(token, field: $0) }
    }
}
