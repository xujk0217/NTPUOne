//
//  NextCourseWidgetBundle.swift
//  NextCourseWidget
//
//  Created by 許君愷 on 2024/8/21.
//

import WidgetKit
import SwiftUI
import CoreData

@main
struct NextCourseWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        NextCourseWidget()
        CourseLargeWidget()
        MemoWidget()
        NextTaskWidget()
        if #available(iOSApplicationExtension 16.1, *) {
            NextCourseLiveActivityWidget()
        }
    }
}


/// Widgets only read the existing shared store; a load failure retries on the next timeline.
/// Never force-unwrap the App Group URL or create a replacement database.
enum WidgetPersistence {
    static func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T] {
        guard let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.NTPUOne.NextCourseWidget")?
            .appendingPathComponent("shared.sqlite"),
              FileManager.default.fileExists(atPath: storeURL.path) else { return [] }
        let container = NSPersistentContainer(name: "CourseModel")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = false
        description.isReadOnly = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions = [description]
        var loadingError: Error?
        container.loadPersistentStores { _, error in loadingError = error }
        if let loadingError { throw loadingError }
        // Materialize values before returning to the timeline / view.
        request.returnsObjectsAsFaults = false
        return try container.viewContext.performAndWait {
            try container.viewContext.fetch(request)
        }
    }
}
