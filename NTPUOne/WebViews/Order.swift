//
//  Order.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

class OrderManager: ObservableObject {
    enum OrderFilter: Equatable {
        case all
        case event
        case post
        case other

        var tagValue: String? {
            switch self {
            case .all: return nil
            case .event: return "1"
            case .post: return "2"
            case .other: return "3"
            }
        }
    }

    @Published var order: [Order]?
    @Published var eventN: Int = 0
    @Published var postN: Int = 0
    @Published var otherN: Int = 0
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var activeFilter: OrderFilter?

    deinit {
        listener?.remove()
    }
    
    func loadOrder() {
        startListening(filter: .all)
    }

    func startListening(filter: OrderFilter) {
        guard activeFilter != filter || listener == nil else { return }

        listener?.remove()
        activeFilter = filter
        order = nil

        var query: Query = db.collection(K.FStoreOr.collectionName)
        if let tag = filter.tagValue {
            query = query.whereField(K.FStoreOr.tagField, isEqualTo: tag)
        }

        listener = query
            .order(by: K.FStoreOr.dateField)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self else { return }
                if let error {
                    print("There is an issue: \(error)")
                    return
                }
                self.handleOrdersSnapshot(querySnapshot?.documents ?? [], filter: filter)
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        activeFilter = nil
    }

    private func handleOrdersSnapshot(_ snapshotDocuments: [QueryDocumentSnapshot],
                                      filter: OrderFilter) {
            var newOrders: [Order] = []
            var e = 0, p = 0, o = 0

            for doc in snapshotDocuments {
                let data = doc.data()

                // 既有欄位（必要）
                guard
                    let message = data[K.FStoreOr.messageField] as? String,
                    let name    = data[K.FStoreOr.nameField]    as? String,
                    let url     = data[K.FStoreOr.urlField]     as? String,
                    let tag     = data[K.FStoreOr.tagField]     as? String
                else {
                    print("order firebase fail")
                    continue
                }

                // 新欄位（可選 → 給預設）
                let time  = (data[K.FStoreOr.timeField]  as? String) ?? ""
                let email = (data[K.FStoreOr.emailField] as? String) ?? ""
                let date  = (data[K.FStoreOr.dateField]  as? Double) ?? Date().timeIntervalSince1970

                var order = Order(message: message,
                                  name: name,
                                  url: url,
                                  tag: tag,
                                  time: time,
                                  email: email,
                                  date: date)
                order.id = doc.documentID   // ✅ 補上 docID

                // 全體統計（保持你原本的行為）
                switch tag {
                case "1": e += 1
                case "2": p += 1
                default:  o += 1
                }

                newOrders.append(order)
            }

            print("event: \(e)  post: \(p)  other: \(o)")
            DispatchQueue.main.async {
                if filter == .all {
                    self.eventN = e
                    self.postN = p
                    self.otherN = o
                } else {
                    switch filter {
                    case .event: self.eventN = newOrders.count
                    case .post: self.postN = newOrders.count
                    case .other: self.otherN = newOrders.count
                    case .all: break
                    }
                }
                self.order  = newOrders
            }
        }

        // 活動 (tag = "1")
        func loadOrderEvent() {
            startListening(filter: .event)
        }

        // 貼文 (tag = "2")
        func loadOrderPost() {
            startListening(filter: .post)
        }

        // 其他 (tag = "3" 或非 1/2)
        func loadOrderOther() {
            startListening(filter: .other)
        }
    func updateOrder(docID: String, message: String, name: String, url: String, tag: String, time: String, email: String) {
            db.collection(K.FStoreOr.collectionName)
                .document(docID)
                .updateData([
                    K.FStoreOr.messageField: message,
                    K.FStoreOr.nameField: name,
                    K.FStoreOr.urlField: url,
                    K.FStoreOr.tagField: tag,
                    K.FStoreOr.timeField: time,
                    K.FStoreOr.emailField: email
                    // date 是否要更新？通常不更新（保持建立時間）
                    // 若你要改成「編輯時也刷新時間」，再加：
                    // ,K.FStoreOr.dateField: Date().timeIntervalSince1970
                ]) { err in
                    if let err = err { print("updateOrder failed: \(err)") }
                }
        }

        func deleteOrder(docID: String) {
            db.collection(K.FStoreOr.collectionName)
                .document(docID)
                .delete { err in
                    if let err = err { print("deleteOrder failed: \(err)") }
                }
        }
    
    /// 上傳新的 Order 到 Firebase
    func uploadOrder(message: String, name: String, url: String, tag: String, time: String, email: String, completion: ((Bool) -> Void)? = nil) {
        let data: [String: Any] = [
            K.FStoreOr.messageField: message,
            K.FStoreOr.nameField: name,
            K.FStoreOr.urlField: url,
            K.FStoreOr.tagField: tag,
            K.FStoreOr.timeField: time,
            K.FStoreOr.emailField: email,
            K.FStoreOr.dateField: Date().timeIntervalSince1970
        ]
        
        db.collection(K.FStoreOr.collectionName).addDocument(data: data) { err in
            if let err = err {
                print("uploadOrder failed: \(err)")
                completion?(false)
            } else {
                print("uploadOrder success")
                completion?(true)
            }
        }
    }
}

struct Order: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let message: String
    let name: String
    let url: String
    let tag: String
    
    var time: String        // 表單中的時間字串
    var email: String       // 聯絡 email
    var date: Double        // 以秒為單位的 epoch（Date().timeIntervalSince1970）

    var favoriteID: String? {
        guard let id else { return nil }
        return "order:\(id)"
    }

    var favoriteSource: String {
        switch tag {
        case "1":
            "活動"
        case "2":
            "社團"
        case "3":
            "其他"
        default:
            "公告"
        }
    }
}
