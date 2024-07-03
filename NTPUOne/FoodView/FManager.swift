//
//  FManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/1.
//

import Foundation
import FirebaseFirestore


class FManager: ObservableObject {
    @Published var Food: [FDetail]?
    
    private var db = Firestore.firestore()
    
    func loadF(whichDiet:String) {
        var collectName = ""
        if whichDiet == "B"{
            collectName = K.FStoreF.collectionNameB
        }else if whichDiet == "L"{
            collectName = K.FStoreF.collectionNamel
        }else if whichDiet == "D"{
            collectName = K.FStoreF.collectionNamed
        }else {
            collectName = K.FStoreF.collectionNamem
        }
        db.collection(collectName)
            .order(by: K.FStoreF.starField)
            .addSnapshotListener { querySnapshot, error in
                self.Food = []
                if let e = error {
                    print("There is an issue: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        print("success get order")
                        var newFoods = [FDetail]()
                        for doc in snapshotDocuments {
                            let data = doc.data()
                            if let store = data[K.FStoreF.storeField] as? String,
                               let time = data[K.FStoreF.openTimeField] as? String,
                               let url = data[K.FStoreF.urlField] as? String,
                               let starNum = data[K.FStoreF.starField] as? Double,
                               let lat = data[K.FStoreF.latField] as? Double,
                               let lng = data[K.FStoreF.lngField] as? Double,
                               let address = data[K.FStoreF.addressField] as? String {
                                let newF = FDetail(store: store, time: time, url: url, address: address, starNum: starNum, lat: lat, lng: lng)
                                newFoods.append(newF)
                            } else {
                                print("order firebase fail")
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

struct FDetail: Identifiable{
    var id: Double{
        return lat
    }
    let store: String
    let time: String
    let url: String
    let address: String
    let starNum: Double
    let lat: Double
    let lng: Double
}
