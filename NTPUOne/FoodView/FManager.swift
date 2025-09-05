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
    
    func getCollectionName(for diet: String) -> String {
        switch diet {
        case "B": return K.FStoreF.collectionNameB
        case "L": return K.FStoreF.collectionNamel
        case "D": return K.FStoreF.collectionNamed
        default:  return K.FStoreF.collectionNamem
        }
    }
    
    /// 原子遞增星數（支援 +/−，多人同時操作不會彼此覆蓋）
    func incrementStar(diet: String, id: String, delta: Double) {
        let col = getCollectionName(for: diet)
        db.collection(col).document(id).updateData([
            K.FStoreF.starField: FieldValue.increment(delta)
        ]) { err in
            if let err = err { print("incrementStar failed: \(err)") }
        }
    }

    /// 批次更新欄位（保留其他欄位）
    func updateFoodFields(diet: String, id: String, fields: [String: Any]) {
        let col = getCollectionName(for: diet)
        db.collection(col).document(id).updateData(fields) { err in
            if let err = err { print("updateFoodFields failed: \(err)") }
        }
    }

    /// 刪除指定餐廳
    func deleteFood(diet: String, id: String) {
        let col = getCollectionName(for: diet)
        db.collection(col).document(id).delete { err in
            if let err = err { print("deleteFood failed: \(err)") }
        }
    }

}

struct FDetail: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let store: String
    let time: String
    let url: String
    let address: String
    let phone: String
    var starNum: Double
    let lat: Double
    let lng: Double
    let check: Bool
}
