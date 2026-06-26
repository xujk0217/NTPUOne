import Foundation
import FirebaseFirestore
import UserNotifications

final class CommunityNotificationFallbackService {
    static let shared = CommunityNotificationFallbackService()

    private let db = Firestore.firestore()
    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "CommunityNotificationFallbackService")

    private let categorySubscriptionsKey = "communityCategorySubscriptions"
    private let topicSubscriptionsKey = "communityTopicSubscriptions"
    private let deviceIdKey = "commentDeviceId"
    private let lastRefreshAtKey = "communityNotificationLastRefreshAt"
    private let categoryBaselinesKey = "communityNotificationCategoryBaselines"
    private let topicBaselinesKey = "communityNotificationTopicBaselines"
    private let seenTopicIDsKey = "communityNotificationSeenTopicIDs"
    private let seenReplyIDsByTopicKey = "communityNotificationSeenReplyIDsByTopic"

    private let categoryRefreshLimit = 50
    private let replyRefreshLimit = 20
    private let maxSeenTopics = 300
    private let maxSeenRepliesPerTopic = 100
    private let foregroundRefreshInterval: TimeInterval = 90
    private let backgroundRefreshInterval: TimeInterval = 30 * 60

    private init() {}

    func refresh(source: String, completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            guard self.canScheduleNotifications(settings.authorizationStatus) else {
                DispatchQueue.main.async { completion?(true) }
                return
            }

            self.queue.async {
                guard !self.shouldSkipRefresh(source: source) else {
                    DispatchQueue.main.async { completion?(true) }
                    return
                }
                self.performRefresh(source: source, completion: completion)
            }
        }
    }

    func noteCategorySubscriptionChanged(_ category: String, isSubscribed: Bool) {
        queue.async {
            var baselines = self.loadDateMap(forKey: self.categoryBaselinesKey)
            if isSubscribed {
                baselines[category] = Date()
            } else {
                baselines.removeValue(forKey: category)
            }
            self.saveDateMap(baselines, forKey: self.categoryBaselinesKey)
        }
    }

    func noteTopicSubscriptionChanged(_ topicID: String, isSubscribed: Bool) {
        queue.async {
            var baselines = self.loadDateMap(forKey: self.topicBaselinesKey)
            var seenReplies = self.loadSeenRepliesByTopic()
            if isSubscribed {
                baselines[topicID] = Date()
            } else {
                baselines.removeValue(forKey: topicID)
                seenReplies.removeValue(forKey: topicID)
            }
            self.saveDateMap(baselines, forKey: self.topicBaselinesKey)
            self.saveSeenRepliesByTopic(seenReplies)
        }
    }

    private func performRefresh(source: String, completion: ((Bool) -> Void)?) {
        let startedAt = Date()
        let categorySubscriptions = Set(defaults.stringArray(forKey: categorySubscriptionsKey) ?? [])
            .filter { !$0.isEmpty && $0 != "all" }
        let topicSubscriptions = Array(Set(defaults.stringArray(forKey: topicSubscriptionsKey) ?? [])
            .filter { !$0.isEmpty }
            .sorted())
        let localDeviceId = defaults.string(forKey: deviceIdKey) ?? ""

        var categoryBaselines = loadDateMap(forKey: categoryBaselinesKey)
        var topicBaselines = loadDateMap(forKey: topicBaselinesKey)
        var changedBaselines = false

        for category in categorySubscriptions where categoryBaselines[category] == nil {
            categoryBaselines[category] = startedAt
            changedBaselines = true
        }
        for topicID in topicSubscriptions where topicBaselines[topicID] == nil {
            topicBaselines[topicID] = startedAt
            changedBaselines = true
        }

        if changedBaselines {
            saveDateMap(categoryBaselines, forKey: categoryBaselinesKey)
            saveDateMap(topicBaselines, forKey: topicBaselinesKey)
        }

        guard !categorySubscriptions.isEmpty || !topicSubscriptions.isEmpty else {
            defaults.set(startedAt.timeIntervalSince1970, forKey: lastRefreshAtKey)
            DispatchQueue.main.async { completion?(true) }
            return
        }

        let group = DispatchGroup()
        var didCompleteAllQueries = true

        for category in categorySubscriptions {
            guard let baseline = categoryBaselines[category] else { continue }
            group.enter()
            refreshCategory(
                category: category,
                baseline: baseline,
                localDeviceId: localDeviceId,
                refreshDate: startedAt
            ) { success in
                if !success { didCompleteAllQueries = false }
                group.leave()
            }
        }

        for topicID in topicSubscriptions {
            guard let baseline = topicBaselines[topicID] else { continue }
            group.enter()
            refreshReplies(
                topicID: topicID,
                baseline: baseline,
                localDeviceId: localDeviceId,
                refreshDate: startedAt
            ) { success in
                if !success { didCompleteAllQueries = false }
                group.leave()
            }
        }

        group.notify(queue: queue) {
            if didCompleteAllQueries {
                self.defaults.set(startedAt.timeIntervalSince1970, forKey: self.lastRefreshAtKey)
            }
            DispatchQueue.main.async { completion?(didCompleteAllQueries) }
        }
    }

    private func refreshCategory(category: String, baseline: Date, localDeviceId: String, refreshDate: Date, completion: @escaping (Bool) -> Void) {
        db.collection("communityTopics")
            .whereField("category", isEqualTo: category)
            .whereField("createdAt", isGreaterThan: Timestamp(date: baseline))
            .order(by: "createdAt", descending: false)
            .limit(to: categoryRefreshLimit)
            .getDocuments { [weak self] snapshot, error in
                guard let self else {
                    completion(false)
                    return
                }

                guard error == nil else {
                    self.queue.async { completion(false) }
                    return
                }

                self.queue.async {
                    var seenTopicIDs = self.loadSeenTopicIDs()
                    var baselines = self.loadDateMap(forKey: self.categoryBaselinesKey)
                    let documents = snapshot?.documents ?? []
                    var lastScannedDate: Date?
                    for document in documents {
                        let data = document.data()
                        let topic = TopicNotification(documentID: document.documentID, data: data)
                        if let createdAt = topic.createdAt {
                            lastScannedDate = max(lastScannedDate ?? createdAt, createdAt)
                        }
                        let categoryBaseline = baselines[category] ?? refreshDate
                        guard topic.createdAt.map({ $0 > categoryBaseline }) ?? false,
                              topic.authorDeviceId != localDeviceId,
                              !seenTopicIDs.contains(topic.id) else {
                            continue
                        }

                        seenTopicIDs.insert(topic.id)
                        self.scheduleTopicNotification(topic)
                    }

                    self.saveSeenTopicIDs(seenTopicIDs)
                    let nextBaseline = lastScannedDate ?? refreshDate
                    baselines[category] = max(baselines[category] ?? nextBaseline, nextBaseline)
                    self.saveDateMap(baselines, forKey: self.categoryBaselinesKey)
                    completion(true)
                }
            }
    }

    private func refreshReplies(topicID: String, baseline: Date, localDeviceId: String, refreshDate: Date, completion: @escaping (Bool) -> Void) {
        db.collection("communityTopics")
            .document(topicID)
            .collection("replies")
            .whereField("createdAt", isGreaterThan: Timestamp(date: baseline))
            .order(by: "createdAt", descending: false)
            .limit(to: replyRefreshLimit)
            .getDocuments { [weak self] snapshot, error in
                guard let self else {
                    completion(false)
                    return
                }

                guard error == nil else {
                    self.queue.async { completion(false) }
                    return
                }

                self.queue.async {
                    var seenReplies = self.loadSeenRepliesByTopic()
                    var seenReplyIDs = Set(seenReplies[topicID] ?? [])
                    let documents = snapshot?.documents ?? []
                    var lastScannedDate: Date?
                    for document in documents {
                        let data = document.data()
                        let reply = ReplyNotification(topicID: topicID, documentID: document.documentID, data: data)
                        if let createdAt = reply.createdAt {
                            lastScannedDate = max(lastScannedDate ?? createdAt, createdAt)
                        }
                        guard reply.authorDeviceId != localDeviceId,
                              reply.createdAt.map({ $0 > baseline }) ?? false,
                              !seenReplyIDs.contains(reply.id) else {
                            continue
                        }

                        seenReplyIDs.insert(reply.id)
                        self.scheduleReplyNotification(reply)
                    }

                    seenReplies[topicID] = Array(seenReplyIDs.suffix(self.maxSeenRepliesPerTopic))
                    self.saveSeenRepliesByTopic(seenReplies)
                    var baselines = self.loadDateMap(forKey: self.topicBaselinesKey)
                    let nextBaseline = lastScannedDate ?? refreshDate
                    baselines[topicID] = max(baselines[topicID] ?? nextBaseline, nextBaseline)
                    self.saveDateMap(baselines, forKey: self.topicBaselinesKey)
                    completion(true)
                }
            }
    }

    private func canScheduleNotifications(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private func shouldSkipRefresh(source: String) -> Bool {
        let lastRefresh = defaults.double(forKey: lastRefreshAtKey)
        guard lastRefresh > 0 else { return false }

        let minimumInterval = source == "background" ? backgroundRefreshInterval : foregroundRefreshInterval
        return Date().timeIntervalSince1970 - lastRefresh < minimumInterval
    }

    private func scheduleTopicNotification(_ topic: TopicNotification) {
        let content = UNMutableNotificationContent()
        content.title = "交流區有新主題"
        content.body = topic.title.isEmpty ? "有人發布了新的交流區主題。" : topic.title
        content.sound = .default
        content.userInfo = ["communityTopicID": topic.id, "communityCategory": topic.category]

        let request = UNNotificationRequest(
            identifier: "community.topic.\(topic.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleReplyNotification(_ reply: ReplyNotification) {
        let content = UNMutableNotificationContent()
        content.title = "交流區有新回覆"
        content.body = reply.body.isEmpty ? "有人回覆了你追蹤的主題。" : reply.body
        content.sound = .default
        content.userInfo = ["communityTopicID": reply.topicID, "communityReplyID": reply.id]

        let request = UNNotificationRequest(
            identifier: "community.reply.\(reply.topicID).\(reply.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func loadDateMap(forKey key: String) -> [String: Date] {
        let raw = defaults.dictionary(forKey: key) as? [String: TimeInterval] ?? [:]
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    private func saveDateMap(_ map: [String: Date], forKey key: String) {
        let raw = map.mapValues { $0.timeIntervalSince1970 }
        defaults.set(raw, forKey: key)
    }

    private func loadSeenTopicIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: seenTopicIDsKey) ?? [])
    }

    private func saveSeenTopicIDs(_ ids: Set<String>) {
        defaults.set(Array(ids.suffix(maxSeenTopics)), forKey: seenTopicIDsKey)
    }

    private func loadSeenRepliesByTopic() -> [String: [String]] {
        defaults.dictionary(forKey: seenReplyIDsByTopicKey) as? [String: [String]] ?? [:]
    }

    private func saveSeenRepliesByTopic(_ map: [String: [String]]) {
        defaults.set(map, forKey: seenReplyIDsByTopicKey)
    }
}

private struct TopicNotification {
    let id: String
    let title: String
    let category: String
    let authorDeviceId: String
    let createdAt: Date?

    init(documentID: String, data: [String: Any]) {
        id = documentID
        title = data["title"] as? String ?? ""
        category = data["category"] as? String ?? ""
        authorDeviceId = data["authorDeviceId"] as? String ?? ""
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
    }
}

private struct ReplyNotification {
    let topicID: String
    let id: String
    let body: String
    let authorDeviceId: String
    let createdAt: Date?

    init(topicID: String, documentID: String, data: [String: Any]) {
        self.topicID = topicID
        id = documentID
        body = data["body"] as? String ?? ""
        authorDeviceId = data["authorDeviceId"] as? String ?? ""
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
    }
}
