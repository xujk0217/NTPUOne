//
//  CommentManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2026/3/6.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Model

struct StoreComment: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String      // 自訂暱稱（快照，改暱稱不影響舊留言）
    var body: String      // 留言內容
    var date: Double      // epoch（Date().timeIntervalSince1970）
    var deviceId: String = ""  // 裝置唯一識別碼，舊文件無此欄仍可正常解碼

    /// 格式化顯示時間
    var dateText: String {
        let d = Date(timeIntervalSince1970: date)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy/MM/dd HH:mm"
        return fmt.string(from: d)
    }
}

// MARK: - Manager

/// 管理單一餐廳的留言子集合
///   路徑：/{dietCollection}/{storeId}/comments/{commentId}
class CommentManager: ObservableObject {
    @Published var comments: [StoreComment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {}

    deinit {
        listener?.remove()
    }

    // MARK: – 載入

    func loadComments(collection: String, storeId: String) {
        guard !collection.isEmpty, !storeId.isEmpty else { return }
        listener?.remove()
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
                }
            }
    }

    // MARK: – 新增

    func addComment(collection: String, storeId: String, name: String, body: String, deviceId: String, completion: ((Bool) -> Void)? = nil) {
        guard !collection.isEmpty, !storeId.isEmpty else { completion?(false); return }
        let data: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "body": body.trimmingCharacters(in: .whitespacesAndNewlines),
            "date": Date().timeIntervalSince1970,
            "deviceId": deviceId
        ]
        db.collection(collection)
            .document(storeId)
            .collection("comments")
            .addDocument(data: data) { error in
                DispatchQueue.main.async { completion?(error == nil) }
            }
    }

    // MARK: – 刪除

    func deleteComment(collection: String, storeId: String, id: String, completion: ((Bool) -> Void)? = nil) {
        db.collection(collection)
            .document(storeId)
            .collection("comments")
            .document(id)
            .delete { error in
                DispatchQueue.main.async {
                    if let error {
                        print("deleteComment failed: \(error)")
                        completion?(false)
                    } else {
                        completion?(true)
                    }
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
            .updateData(["body": newBody.trimmingCharacters(in: .whitespacesAndNewlines)]) { error in
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

    // MARK: – 更新所有舊留言的暱稱（逐一查詢已知 collection，無需 Firestore index）

    func updateAllComments(deviceId: String, newName: String, completion: ((Int) -> Void)? = nil) {
        guard !deviceId.isEmpty else { completion?(0); return }

        let foodCollections = ["breakfast", "lunch", "dinner", "MS"]
        let group = DispatchGroup()
        var totalUpdated = 0

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
                                totalUpdated += commentDocs.count
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
