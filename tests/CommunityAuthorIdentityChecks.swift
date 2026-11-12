import Foundation

@main struct CommunityAuthorIdentityChecks {
    static func main() {
        let owner = CommunityAuthorOwnershipState(uid: "account-A", topicIDs: ["post-from-old-device"], replyKeys: ["post/reply"])
        precondition(owner.ownsTopic("post-from-old-device", activeUID: "account-A"), "Ownership survives device-ID changes")
        precondition(!owner.ownsTopic("post-from-old-device", activeUID: "account-B"))
        precondition(!owner.ownsTopic("post-from-old-device", activeUID: nil))
        precondition(owner.ownsReply(topicID: "post", replyID: "reply", activeUID: "account-A"))
        precondition(!owner.ownsReply(topicID: "different-post", replyID: "reply", activeUID: "account-A"))
        let currentName = CommunityAuthorOwnershipState.displayName(stored: "old name", nickname: " new name ", isOwner: true)
        precondition(currentName == "new name")
        precondition(CommunityAuthorOwnershipState.displayName(stored: "someone else", nickname: "my name", isOwner: false) == "someone else")
        precondition(CommunityAuthorOwnershipState.displayName(stored: "original", nickname: "  ", isOwner: true) == "original")

        precondition(CommunityAuthorOwnershipState.reconciledNickname(remote: "old cloud name", localAtRequest: "old local name", localNow: "new local name") == "new local name", "A late profile fetch cannot revert a name just edited locally")
        precondition(CommunityAuthorOwnershipState.reconciledNickname(remote: "cloud name", localAtRequest: "local", localNow: "local") == "cloud name")
        precondition(CommunityAuthorOwnershipState.reconciledNickname(remote: " ", localAtRequest: "local", localNow: "local") == "local")
        var revisions = CommunityDisplayRevisions()
        let profile = revisions.begin(uid: "account-A", fields: ["authorName", "authorBadgeLevel"])
        let badge = revisions.begin(uid: "account-A", fields: ["authorBadgeLevel"])
        precondition(revisions.isCurrent(profile, field: "authorName"), "A badge refresh cannot cancel a pending nickname update")
        precondition(!revisions.isCurrent(profile, field: "authorBadgeLevel"))
        precondition(revisions.isCurrent(badge, field: "authorBadgeLevel"))
        let nickname = revisions.begin(uid: "account-A", fields: ["authorName"])
        precondition(!revisions.isCurrent(profile, field: "authorName"), "Old nickname responses must not win")
        precondition(revisions.isCurrent(nickname, field: "authorName"))
        precondition(!revisions.hasCurrentFields(profile))
        _ = revisions.begin(uid: "account-B", fields: ["authorName", "authorBadgeLevel"])
        precondition(revisions.isCurrent(nickname, field: "authorName"), "Another account has independent revisions")
        precondition(!revisions.isCurrent(nickname, field: "authorDepartment"))
        print("PASS: account ownership across devices; list/detail nickname consistency; account isolation; independent field revisions; stale nickname updates rejected")
    }
}
