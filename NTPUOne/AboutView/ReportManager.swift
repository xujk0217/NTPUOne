//
//  BugManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/9/6.
//


import FirebaseFirestore
import FirebaseFirestoreSwift

final class BugManager: ObservableObject {
    @Published var items: [BugReport] = []
    private let db = Firestore.firestore()

    func load() {
        db.collection(K.FStoreR.collectionNameBug)
            .order(by: K.FStoreR.issueField) // 也可改 orderBy dateField
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                var list: [BugReport] = []
                for d in docs {
                    do {
                        var x = try d.data(as: BugReport.self)
                        x.id = d.documentID
                        list.append(x)
                    } catch {
                        print("Bug decode failed: \(error)")
                    }
                }
                DispatchQueue.main.async { self.items = list }
            }
    }

    func delete(id: String) {
        db.collection(K.FStoreR.collectionNameBug).document(id).delete { err in
            if let err = err { print("Bug delete failed: \(err)") }
        }
    }
}

final class FeatureManager: ObservableObject {
    @Published var items: [FeatureRequest] = []
    private let db = Firestore.firestore()

    func load() {
        db.collection(K.FStoreR.collectionNameFt)
            .order(by: K.FStoreR.issueField) // 或改 dateField
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                var list: [FeatureRequest] = []
                for d in docs {
                    do {
                        var x = try d.data(as: FeatureRequest.self)
                        x.id = d.documentID
                        list.append(x)
                    } catch {
                        print("Feature decode failed: \(error)")
                    }
                }
                DispatchQueue.main.async { self.items = list }
            }
    }

    func delete(id: String) {
        db.collection(K.FStoreR.collectionNameFt).document(id).delete { err in
            if let err = err { print("Feature delete failed: \(err)") }
        }
    }
}
