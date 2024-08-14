//
//  CourseData.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI
import CloudKit

struct Course: Identifiable {
    var id: String
    var name: String
    var day: String
    var startTime: TimeStart
    var timeSlot: TimeSlot
    var location: String
    var teacher: String
    
    enum TimeStart: String, CaseIterable, Identifiable {
        case none = "none"
        case eight = "8:10"
        case nine = "9:10"
        case ten = "10:10"
        case eleven = "11:10"
        case thirteen = "13:10"
        case fourteen = "14:10"
        case fifteen = "15:10"
        case sixteen = "16:10"
        case seventeen = "17:10"
        case eightteen = "18:30"
        
        var id: String { self.rawValue }
    }
    
    enum TimeSlot: String, CaseIterable, Identifiable {
        case morning1 = "Morning 1"
        case morning2 = "Morning 2"
        case morning3 = "Morning 3"
        case morning4 = "Morning 4"
        case afternoon1 = "Afternoon 1"
        case afternoon2 = "Afternoon 2"
        case afternoon3 = "Afternoon 3"
        case afternoon4 = "Afternoon 4"
        case afternoon5 = "Afternoon 5"
        case evening = "Evening"
        
        var id: String { self.rawValue }
    }
    
}

class CourseData: ObservableObject {
    @Published var courses: [Course] = []
    private var container: CKContainer
    private var privateDatabase: CKDatabase
    
    init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        loadCoursesFromCloudKit()
    }
    
    // 加载课程数据从 CloudKit
    func loadCoursesFromCloudKit() {
        let query = CKQuery(recordType: "Course", predicate: NSPredicate(value: true))
        
        privateDatabase.perform(query, inZoneWith: nil) { results, error in
            if let error = error {
                print("Error loading from CloudKit: \(error.localizedDescription)")
                return
            }
            
            if let results = results {
                DispatchQueue.main.async {
                    self.courses = results.map { record in
                        Course(
                            id: record.recordID.recordName,
                            name: record["name"] as? String ?? "",
                            day: record["day"] as? String ?? "", 
                            startTime: Course.TimeStart(rawValue: record["startTime"] as? String ?? "")  ?? .eight,
                            timeSlot: Course.TimeSlot(rawValue: record["timeSlot"] as? String ?? "") ?? .morning1,
                            location: record["location"] as? String ?? "",
                            teacher: record["teacher"] as? String ?? ""
                        )
                    }
                }
            }
        }
    }
    
    func addCourse(_ course: Course) {
        let courseRecord = CKRecord(recordType: "Course")
        courseRecord["name"] = course.name as CKRecordValue
        courseRecord["day"] = course.day as CKRecordValue
        var startTime: Course.TimeStart = .eight
        switch course.timeSlot{
        case .morning1:
            startTime = .eight
        case .morning2:
            startTime = .nine
        case .morning3:
            startTime = .ten
        case .morning4:
            startTime = .eleven
        case .afternoon1:
            startTime = .thirteen
        case .afternoon2:
            startTime = .fourteen
        case .afternoon3:
            startTime = .fifteen
        case .afternoon4:
            startTime = .sixteen
        case .afternoon5:
            startTime = .seventeen
        case .evening:
            startTime = .eightteen
        }
        courseRecord["startTime"] = startTime.rawValue as CKRecordValue
        courseRecord["timeSlot"] = course.timeSlot.rawValue as CKRecordValue
        courseRecord["location"] = course.location as CKRecordValue
        courseRecord["teacher"] = course.teacher as CKRecordValue

        privateDatabase.save(courseRecord) { record, error in
            if let error = error {
                print("Error saving to CloudKit: \(error.localizedDescription)")
            } else if let record = record {
                DispatchQueue.main.async {
                    // Accessing the recordID here
                    let recordID = record.recordID.recordName
                    print("Successfully saved record with ID: \(recordID)")
                    
                    // Optionally, you can update your local courses list or perform other actions
                    // Here we can update the course object with the recordID
                    var updatedCourse = course
                    updatedCourse.id = recordID // Assuming `Course` has an `id` property
                    updatedCourse.startTime = startTime
                    self.courses.append(updatedCourse)
                }
            }
        }
    }

    
    func deleteCourse(_ course: Course) {
        // 从本地数据源中删除课程
        if let index = courses.firstIndex(where: { $0.id == course.id }) {
            courses.remove(at: index)
            print("Course deleted: \(course.name)")
        } else {
            print("Course not found: \(course.name)")
        }
            
        // 从 CloudKit 删除课程
        let recordID = CKRecord.ID(recordName: course.id)
        privateDatabase.delete(withRecordID: recordID) { _, error in
            if let error = error {
                print("Error deleting from CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteCourseById(_ courseid: String) {
        // 从本地数据源中删除课程
        if let index = courses.firstIndex(where: { $0.id == courseid }) {
            courses.remove(at: index)
        }
            
        // 从 CloudKit 删除课程
        let recordID = CKRecord.ID(recordName: courseid)
        privateDatabase.delete(withRecordID: recordID) { _, error in
            if let error = error {
                print("Error deleting from CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    // 更新课程
    func updateCourse(_ course: Course) {
        let recordID = CKRecord.ID(recordName: course.id)
        
        privateDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            if let error = error {
                print("Error fetching record from CloudKit: \(error.localizedDescription)")
                return
            }
            
            guard let record = record else {
                print("Record not found")
                return
            }
            
            record["name"] = course.name as CKRecordValue
            record["day"] = course.day as CKRecordValue
            var startTime: Course.TimeStart = .eight
            switch course.timeSlot{
            case .morning1:
                startTime = .eight
            case .morning2:
                startTime = .nine
            case .morning3:
                startTime = .ten
            case .morning4:
                startTime = .eleven
            case .afternoon1:
                startTime = .thirteen
            case .afternoon2:
                startTime = .fourteen
            case .afternoon3:
                startTime = .fifteen
            case .afternoon4:
                startTime = .sixteen
            case .afternoon5:
                startTime = .seventeen
            case .evening:
                startTime = .eightteen
            }
            record["startTime"] = startTime.rawValue as CKRecordValue
            record["timeSlot"] = course.timeSlot.rawValue as CKRecordValue
            record["location"] = course.location as CKRecordValue
            record["teacher"] = course.teacher as CKRecordValue
            
            self?.privateDatabase.save(record) { savedRecord, saveError in
                if let saveError = saveError {
                    print("Error updating record in CloudKit: \(saveError.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        if let index = self?.courses.firstIndex(where: { $0.id == course.id }) {
                            var newCourse = course
                            newCourse.startTime = startTime
                            self?.courses[index] = newCourse
                        }
                    }
                }
            }
        }
    }
}
