//
//  CourseEntity+CoreDataProperties.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//
//

import Foundation
import CoreData


extension CourseEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CourseEntity> {
        return NSFetchRequest<CourseEntity>(entityName: "CourseEntity")
    }

    @NSManaged public var day: String?
    @NSManaged public var id: String?
    @NSManaged public var location: String?
    @NSManaged public var name: String?
    @NSManaged public var startTime: String?
    @NSManaged public var teacher: String?
    @NSManaged public var timeSlot: String?
    @NSManaged public var isNotification: Bool

}

extension CourseEntity : Identifiable {

}
