//
//  CourseYearManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/9/4.
//

import Foundation
import FirebaseFirestore

class CourseYearManager: ObservableObject {
    private static var cachedCourseYear: [CourseYear]?

    @Published var courseYear: [CourseYear]?
    
    private var db = Firestore.firestore()
    private var hasLoadedYear = false
    private var isLoadingYear = false
    
    func loadYear() {
        if let cachedCourseYear = Self.cachedCourseYear {
            courseYear = cachedCourseYear
            hasLoadedYear = true
            return
        }
        guard !hasLoadedYear, !isLoadingYear else { return }
        isLoadingYear = true

        db.collection("CourseYear")
            .getDocuments { [weak self] querySnapshot, error in
                guard let self else { return }
                if let e = error {
                    print("There is an issue: \(e)")
                    DispatchQueue.main.async { self.isLoadingYear = false }
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
                            Self.cachedCourseYear = newYear
                            self.courseYear = newYear
                            self.hasLoadedYear = true
                            self.isLoadingYear = false
                        }
                    } else {
                        DispatchQueue.main.async { self.isLoadingYear = false }
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
