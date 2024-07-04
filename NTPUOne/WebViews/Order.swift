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
    @Published var order: [Order]? 
    private var db = Firestore.firestore()

    func loadOrder() {
        db.collection(K.FStoreOr.collectionName)
            .order(by: K.FStoreOr.dateField)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return } // 避免强引用导致的内存泄漏
                if let e = error {
                    print("There is an issue: \(e)")
                    return
                }
                
                if let snapshotDocuments = querySnapshot?.documents {
                    print("success get order")
                    var newOrders: [Order] = [] // 临时存储获取的订单数据
                    for doc in snapshotDocuments {
                        let data = doc.data()
                        if let message = data[K.FStoreOr.messageField] as? String,
                           let messageSName = data[K.FStoreOr.nameField] as? String,
                           let messageUrl = data[K.FStoreOr.urlField] as? String, let messageTag = data[K.FStoreOr.tagField] as? String{
                            let newOrder = Order(message: message, name: messageSName, url: messageUrl, tag: messageTag)
                            newOrders.append(newOrder)
                        } else {
                            print("order firebase fail")
                        }
                    }
                    DispatchQueue.main.async {
                        self.order = newOrders
                    }
                }
            }
    }
}

struct Order {
    let message: String
    let name: String
    let url: String
    let tag: String
}

//tag: 1.活動 2.公告 3.其他
