//
//  CourseYearManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/9/4.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class CourseYearManager: ObservableObject {
    @Published var courseYear: [CourseYear]?
    
    private var db = Firestore.firestore()
    
    func loadYear() {
        var collectName = "CourseYear"

        db.collection(collectName)
            .addSnapshotListener { querySnapshot, error in
                if let e = error {
                    print("There is an issue: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        print("success get order")
                        var newYear = [CourseYear]()
                        for doc in snapshotDocuments {
                            do {
                                var year = try doc.data(as: CourseYear.self)
                                year.id = doc.documentID
                                newYear.append(year)
                                print("currentYear:")
                                print(year.CurrentYear)
                            } catch {
                                print("Error decoding document: \(error)")
                            }
                        }
                        DispatchQueue.main.async {
                            self.courseYear = newYear
                        }
                    }
                }
            }
    }
}

struct CourseYear: Identifiable, Codable {
    @DocumentID var id: String?
    var CurrentSemester: String
    var CurrentYear: String
    var Years: [String]
}
