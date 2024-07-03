//
//  FManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/1.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class FManager: ObservableObject {
    @Published var Food: [FDetail]?
    
    private var db = Firestore.firestore()
    
    func loadF(whichDiet: String) {
        var collectName = ""
        if whichDiet == "B" {
            collectName = K.FStoreF.collectionNameB
        } else if whichDiet == "L" {
            collectName = K.FStoreF.collectionNamel
        } else if whichDiet == "D" {
            collectName = K.FStoreF.collectionNamed
        } else {
            collectName = K.FStoreF.collectionNamem
        }

        db.collection(collectName)
            .order(by: K.FStoreF.starField, descending: true)
            .addSnapshotListener { querySnapshot, error in
                if let e = error {
                    print("There is an issue: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        print("success get order")
                        var newFoods = [FDetail]()
                        for doc in snapshotDocuments {
                            do {
                                var food = try doc.data(as: FDetail.self)
                                food.id = doc.documentID
                                newFoods.append(food)
                            } catch {
                                print("Error decoding document: \(error)")
                            }
                        }
                        DispatchQueue.main.async {
                            self.Food = newFoods
                        }
                    }
                }
            }
    }
}

struct FDetail: Identifiable, Codable {
    @DocumentID var id: String?
    let store: String
    let time: String
    let url: String
    let address: String
    var starNum: Double
    let lat: Double
    let lng: Double
    let check: Bool
}
