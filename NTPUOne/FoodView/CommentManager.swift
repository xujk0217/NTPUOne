//
//  CommentManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2026/3/6.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Model

struct StoreComment: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String      // 自訂暱稱（快照，改暱稱不影響舊留言）
    var body: String      // 留言內容
    var date: Double      // epoch（Date().timeIntervalSince1970）
    var deviceId: String = ""  // 裝置唯一識別碼，舊文件無此欄仍可正常解碼
    var authorUid: String?     // 舊格式遺留欄位：新留言不再寫入，僅用於辨識並認領舊留言
    var updatedAt: Double?
    var authorBadgeLevel: Int? // 徽章快照：公開顯示用，避免暴露帳號 UID

    var statsOwnerId: String {
        guard let authorUid, !authorUid.isEmpty else { return deviceId }
        return authorUid
    }

    var isEdited: Bool {
        guard let updatedAt else { return false }
        return updatedAt > date + 1
    }

    /// 格式化顯示時間
    var dateText: String {
        let d = Date(timeIntervalSince1970: date)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy/MM/dd HH:mm"
        return fmt.string(from: d)
    }
}

// MARK: - Manager

enum CommentPostError: LocalizedError {
    case signInRequired
    case uploadFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .signInRequired:
            return String(localized: "community_google_sign_in_required_error")
        case .uploadFailed(let underlying):
            return underlying?.localizedDescription ?? String(localized: "comment_post_failed_generic")
        }
    }
}

/// 管理單一餐廳的留言子集合
///   路徑：/{dietCollection}/{storeId}/comments/{commentId}
class CommentManager: ObservableObject {
    @Published var comments: [StoreComment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var ownedCommentIds = Set<String>()

    /// 每個 deviceId 的全站全域留言數（跨所有店家，用於顯示最新徽章等級）
    @Published var userGlobalStats: [String: Int] = [:]

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var ownerListener: ListenerRegistration?
    private var listeningCollection: String?
    private var listeningStoreID: String?

    init() {}

    deinit {
        listener?.remove()
        ownerListener?.remove()
    }

    static func ownerDocumentId(collection: String, storeId: String, commentId: String) -> String {
        "\(collection)_\(storeId)_\(commentId)"
    }

    func canEdit(_ comment: StoreComment) -> Bool {
        guard let id = comment.id else { return false }
        if ownedCommentIds.contains(id) { return true }

        // 舊留言過渡：文件仍帶 authorUid 時，比對登入帳號即視為本人
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return false }
        return comment.authorUid == uid
    }

    // MARK: – 載入

    func loadComments(collection: String, storeId: String) {
        guard !collection.isEmpty, !storeId.isEmpty else { return }
        guard listener == nil || listeningCollection != collection || listeningStoreID != storeId else {
            return
        }

        listener?.remove()
        listeningCollection = collection
        listeningStoreID = storeId
        observeOwnedRestaurantComments(collection: collection, storeId: storeId)
        isLoading = true

        listener = db
            .collection(collection)
            .document(storeId)
            .collection("comments")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                    return
                }
                var list: [StoreComment] = []
                for doc in snapshot?.documents ?? [] {
                    if var c = try? doc.data(as: StoreComment.self) {
                        c.id = doc.documentID
                        list.append(c)
                    }
                }
                DispatchQueue.main.async {
                    self.comments = list
                    self.isLoading = false
                    // 批次查詢所有留言者的全域統計（讓徽章反映全站最新等級）
                    let statsOwnerIds = list.map(\.statsOwnerId).filter { !$0.isEmpty }
                    self.fetchGlobalStats(for: Array(Set(statsOwnerIds)))
                    self.adoptLegacyOwnedComments(list, collection: collection, storeId: storeId)
                }
            }
    }

    // MARK: – 新增

    func addComment(collection: String, storeId: String, name: String, body: String, deviceId: String, completion: ((Error?) -> Void)? = nil) {
        guard !collection.isEmpty, !storeId.isEmpty else {
            completion?(CommentPostError.uploadFailed(underlying: nil)); return
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(CommentPostError.signInRequired); return
        }
        let commentRef = db.collection(collection)
            .document(storeId)
            .collection("comments")
            .document()
        let timestamp = Date().timeIntervalSince1970
        let data: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "body": body.trimmingCharacters(in: .whitespacesAndNewlines),
            "date": timestamp,
            "deviceId": deviceId,
            "authorBadgeLevel": CommentBadgeManager.shared.getCurrentBadge().rawValue
        ]

        let batch = db.batch()
        batch.setData(data, forDocument: commentRef)

        let ownerId = Self.ownerDocumentId(collection: collection, storeId: storeId, commentId: commentRef.documentID)
        let ownerRef = db.collection("restaurantCommentOwners")
            .document(uid)
            .collection("comments")
            .document(ownerId)
        batch.setData([
            "ownerUid": uid,
            "mealCollection": collection,
            "storeId": storeId,
            "commentId": commentRef.documentID,
            "createdAt": timestamp
        ], forDocument: ownerRef)

        batch.commit { [weak self] error in
            if error == nil {
                self?.db.collection("userStats").document(uid)
                    .setData(["total": FieldValue.increment(Int64(1))], merge: true)
            }
            DispatchQueue.main.async {
                if let error {
                    completion?(CommentPostError.uploadFailed(underlying: error))
                } else {
                    completion?(nil)
                }
            }
        }
    }

    // MARK: – 刪除

    func deleteComment(collection: String, storeId: String, id: String, deviceId: String = "", completion: ((Bool) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async { completion?(false) }
            return
        }
        let ref = db.collection(collection).document(storeId).collection("comments").document(id)
        let ownerRef = db.collection("restaurantCommentOwners")
            .document(uid)
            .collection("comments")
            .document(Self.ownerDocumentId(collection: collection, storeId: storeId, commentId: id))

        func performDelete(ownerStatsId: String) {
            let doDelete = {
                ref.delete { error in
                    DispatchQueue.main.async {
                        if let error {
                            print("deleteComment failed: \(error)")
                            completion?(false)
                        } else {
                            ownerRef.delete()
                            if !ownerStatsId.isEmpty {
                                self.db.collection("userStats").document(ownerStatsId)
                                    .updateData(["total": FieldValue.increment(Int64(-1))])
                            }
                            completion?(true)
                        }
                    }
                }
            }

            doDelete()
        }

        if !deviceId.isEmpty {
            ref.getDocument { snap, _ in
                let ownerStatsId = snap?.data()?["authorUid"] as? String ?? deviceId
                performDelete(ownerStatsId: ownerStatsId)
            }
        } else {
            ref.getDocument { snap, _ in
                let ownerStatsId = snap?.data()?["authorUid"] as? String ?? snap?.data()?["deviceId"] as? String ?? ""
                performDelete(ownerStatsId: ownerStatsId)
            }
        }
    }
    
    // MARK: – 編輯留言內容
    
    func editComment(collection: String, storeId: String, id: String, newBody: String, completion: ((Bool) -> Void)? = nil) {
        guard !collection.isEmpty, !storeId.isEmpty, !id.isEmpty else {
            completion?(false)
            return
        }
        db.collection(collection)
            .document(storeId)
            .collection("comments")
            .document(id)
            .updateData([
                "body": newBody.trimmingCharacters(in: .whitespacesAndNewlines),
                "updatedAt": Date().timeIntervalSince1970
            ]) { error in
                DispatchQueue.main.async {
                    if let error {
                        print("editComment failed: \(error)")
                        completion?(false)
                    } else {
                        completion?(true)
                    }
                }
            }
    }

    // 舊留言認領：公開文件仍帶本人 authorUid 但缺私有 owner 文件時，
    // 補建 owner 文件並清除公開文件上的 authorUid（rules 提供對應授權路徑）
    private func adoptLegacyOwnedComments(_ list: [StoreComment], collection: String, storeId: String) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let candidates = list.filter { comment in
            guard let commentId = comment.id else { return false }
            return comment.authorUid == uid && !ownedCommentIds.contains(commentId)
        }
        guard !candidates.isEmpty else { return }

        let group = DispatchGroup()
        let lock = NSLock()
        var pending: [(commentId: String, ownerRef: DocumentReference, publicRef: DocumentReference)] = []

        for comment in candidates {
            guard let commentId = comment.id else { continue }
            let ownerRef = db.collection("restaurantCommentOwners")
                .document(uid)
                .collection("comments")
                .document(Self.ownerDocumentId(collection: collection, storeId: storeId, commentId: commentId))
            let publicRef = db.collection(collection).document(storeId).collection("comments").document(commentId)

            group.enter()
            // 先確認 owner 文件不存在，避免與載入中的 ownedCommentIds 競爭導致批次被 rules 拒絕
            ownerRef.getDocument { snapshot, _ in
                defer { group.leave() }
                guard snapshot?.exists != true else { return }
                lock.lock()
                pending.append((commentId, ownerRef, publicRef))
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self, !pending.isEmpty else { return }
            let batch = self.db.batch()
            let timestamp = Date().timeIntervalSince1970
            for item in pending {
                batch.setData([
                    "ownerUid": uid,
                    "mealCollection": collection,
                    "storeId": storeId,
                    "commentId": item.commentId,
                    "createdAt": timestamp
                ], forDocument: item.ownerRef)
                batch.updateData(
                    ["authorUid": FieldValue.delete()],
                    forDocument: item.publicRef
                )
            }
            batch.commit { _ in
                self.observeOwnedRestaurantComments(collection: collection, storeId: storeId)
            }
        }
    }

    private func observeOwnedRestaurantComments(collection: String, storeId: String) {        ownerListener?.remove()
        ownedCommentIds.removeAll()

        guard let uid = Auth.auth().currentUser?.uid else { return }
        ownerListener = db.collection("restaurantCommentOwners")
            .document(uid)
            .collection("comments")
            .whereField("mealCollection", isEqualTo: collection)
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let ids = Set(snapshot?.documents.compactMap { $0.data()["commentId"] as? String } ?? [])
                DispatchQueue.main.async {
                    self.ownedCommentIds = ids
                }
            }
    }

    func fetchGlobalStats(for statsOwnerIds: [String]) {
        guard !statsOwnerIds.isEmpty else { return }
        // Firestore 每次 whereField in 最多 30 個；分批查詢
        let batches = stride(from: 0, to: statsOwnerIds.count, by: 30).map {
            Array(statsOwnerIds[$0..<min($0 + 30, statsOwnerIds.count)])
        }
        for batch in batches {
            db.collection("userStats")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { [weak self] snapshot, _ in
                    guard let self, let docs = snapshot?.documents else { return }
                    var stats: [String: Int] = [:]
                    for doc in docs {
                        stats[doc.documentID] = doc.data()["total"] as? Int ?? 0
                    }
                    DispatchQueue.main.async {
                        self.userGlobalStats.merge(stats) { _, new in new }
                    }
                }
        }
    }

    // MARK: – 同步當前用戶的全域統計到 Firestore
    func upsertMyStats(count: Int) {
        guard let uid = Auth.auth().currentUser?.uid, count > 0 else { return }
        db.collection("userStats").document(uid)
            .setData(["total": count], merge: true)
    }

    // MARK: – 更新所有舊留言的暱稱（逐一查詢已知 collection，無需 Firestore index）

    func updateAllComments(deviceId: String, newName: String, completion: ((Int) -> Void)? = nil) {
        guard !deviceId.isEmpty else { completion?(0); return }

        let foodCollections = ["breakfast", "lunch", "dinner", "MS"]
        let group = DispatchGroup()
        var totalUpdated = 0
        let lock = NSLock()

        for col in foodCollections {
            group.enter()
            db.collection(col).getDocuments { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents, error == nil else {
                    group.leave(); return
                }
                let storeIds = docs.map { $0.documentID }
                let innerGroup = DispatchGroup()

                for storeId in storeIds {
                    innerGroup.enter()
                    self.db.collection(col)
                        .document(storeId)
                        .collection("comments")
                        .whereField("deviceId", isEqualTo: deviceId)
                        .getDocuments { snap, err in
                            guard let commentDocs = snap?.documents, err == nil else {
                                innerGroup.leave(); return
                            }
                            if commentDocs.isEmpty { innerGroup.leave(); return }
                            let batch = self.db.batch()
                            for doc in commentDocs {
                                batch.updateData(["name": newName], forDocument: doc.reference)
                            }
                            batch.commit { _ in
                                lock.lock()
                                totalUpdated += commentDocs.count
                                lock.unlock()
                                innerGroup.leave()
                            }
                        }
                }

                innerGroup.notify(queue: .main) { group.leave() }
            }
        }

        group.notify(queue: .main) {
            completion?(totalUpdated)
        }
    }
}
