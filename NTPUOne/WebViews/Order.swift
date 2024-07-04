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
    @Published var eventN: Int = 0
    @Published var postN: Int = 0
    @Published var otherN: Int = 0
    
    private var db = Firestore.firestore()
    
    func loadOrder() {
        db.collection(K.FStoreOr.collectionName)
            .order(by: K.FStoreOr.dateField)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                if let e = error {
                    print("There is an issue: \(e)")
                    return
                }
                
                if let snapshotDocuments = querySnapshot?.documents {
                    print("success get order")
                    var newOrders: [Order] = []
                    eventN = 0
                    postN = 0
                    otherN = 0
                    for doc in snapshotDocuments {
                        let data = doc.data()
                        if let message = data[K.FStoreOr.messageField] as? String,
                           let messageSName = data[K.FStoreOr.nameField] as? String,
                           let messageUrl = data[K.FStoreOr.urlField] as? String, let messageTag = data[K.FStoreOr.tagField] as? String{
                            let newOrder = Order(message: message, name: messageSName, url: messageUrl, tag: messageTag)
                            if newOrder.tag == "1"{
                                eventN += 1
                            }else if newOrder.tag == "2"{
                                postN += 1
                            }else{
                                otherN += 1
                            }
                            newOrders.append(newOrder)
                        } else {
                            print("order firebase fail")
                        }
                    }
                    print("event: \(eventN)")
                    print("post: \(postN)")
                    print("other: \(otherN)")
                    DispatchQueue.main.async {
                        self.order = newOrders
                    }
                }
            }
    }
    func loadOrderEvent() {
        db.collection(K.FStoreOr.collectionName)
            .order(by: K.FStoreOr.dateField)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                if let e = error {
                    print("There is an issue: \(e)")
                    return
                }
                
                if let snapshotDocuments = querySnapshot?.documents {
                    print("success get order event")
                    var newOrders: [Order] = []
                    eventN = 0
                    postN = 0
                    otherN = 0
                    for doc in snapshotDocuments {
                        let data = doc.data()
                        if let message = data[K.FStoreOr.messageField] as? String,
                           let messageSName = data[K.FStoreOr.nameField] as? String,
                           let messageUrl = data[K.FStoreOr.urlField] as? String, let messageTag = data[K.FStoreOr.tagField] as? String{
                            let newOrder = Order(message: message, name: messageSName, url: messageUrl, tag: messageTag)
                            if newOrder.tag == "1"{
                                eventN += 1
                                newOrders.append(newOrder)
                            }else if newOrder.tag == "2"{
                                postN += 1
                            }else{
                                otherN += 1
                            }
                        } else {
                            print("order firebase fail")
                        }
                    }
                    print("event: \(eventN)")
                    print("post: \(postN)")
                    print("other: \(otherN)")
                    DispatchQueue.main.async {
                        self.order = newOrders
                    }
                }
            }
    }
    func loadOrderPost() {
        db.collection(K.FStoreOr.collectionName)
            .order(by: K.FStoreOr.dateField)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                if let e = error {
                    print("There is an issue: \(e)")
                    return
                }
                
                if let snapshotDocuments = querySnapshot?.documents {
                    print("success get order post")
                    var newOrders: [Order] = []
                    eventN = 0
                    postN = 0
                    otherN = 0
                    for doc in snapshotDocuments {
                        let data = doc.data()
                        if let message = data[K.FStoreOr.messageField] as? String,
                           let messageSName = data[K.FStoreOr.nameField] as? String,
                           let messageUrl = data[K.FStoreOr.urlField] as? String, let messageTag = data[K.FStoreOr.tagField] as? String{
                            let newOrder = Order(message: message, name: messageSName, url: messageUrl, tag: messageTag)
                            if newOrder.tag == "1"{
                                eventN += 1
                            }else if newOrder.tag == "2"{
                                postN += 1
                                newOrders.append(newOrder)
                            }else{
                                otherN += 1
                            }
                        } else {
                            print("order firebase fail")
                        }
                    }
                    print("event: \(eventN)")
                    print("post: \(postN)")
                    print("other: \(otherN)")
                    DispatchQueue.main.async {
                        self.order = newOrders
                    }
                }
            }
    }
    func loadOrderOther() {
        db.collection(K.FStoreOr.collectionName)
            .order(by: K.FStoreOr.dateField)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                if let e = error {
                    print("There is an issue: \(e)")
                    return
                }
                
                if let snapshotDocuments = querySnapshot?.documents {
                    print("success get order other")
                    var newOrders: [Order] = []
                    eventN = 0
                    postN = 0
                    otherN = 0
                    for doc in snapshotDocuments {
                        let data = doc.data()
                        if let message = data[K.FStoreOr.messageField] as? String,
                           let messageSName = data[K.FStoreOr.nameField] as? String,
                           let messageUrl = data[K.FStoreOr.urlField] as? String, let messageTag = data[K.FStoreOr.tagField] as? String{
                            let newOrder = Order(message: message, name: messageSName, url: messageUrl, tag: messageTag)
                            if newOrder.tag == "1"{
                                eventN += 1
                            }else if newOrder.tag == "2"{
                                postN += 1
                            }else{
                                otherN += 1
                                newOrders.append(newOrder)
                            }
                        } else {
                            print("order firebase fail")
                        }
                    }
                    print("event: \(eventN)")
                    print("post: \(postN)")
                    print("other: \(otherN)")
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
