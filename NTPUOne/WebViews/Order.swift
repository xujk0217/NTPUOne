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
    @Published var order: [Order] = []
    private var db = Firestore.firestore()

    func loadOrder() {
        db.collection(K.FStoreOr.collectionName)
            .order(by: K.FStoreOr.dateField)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                self.order = []
                if let e = error {
                    print("There is an issue: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let message = data[K.FStoreOr.messageField] as? String,
                               let messageSName = data[K.FStoreOr.nameField] as? String,
                               let messageUrl = data[K.FStoreOr.urlField] as? String {
                                let newOrder = Order(message: message, name: messageSName, url: messageUrl)
                                DispatchQueue.main.async {
                                    self.order.append(newOrder)
                                }
                                print("success get order")
                            }else{
                                print("order firebase fail")
                            }
                        }
                    }
                }
            }
    }
}

struct OrderDetail{
    let email: String
    let message: String
    let name: String
    let url: String
    let time: String
}

struct Order{
    let message: String
    let name: String
    let url: String
}
