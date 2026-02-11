//
//  CoreDataManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//

import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()

    let persistentContainer: NSPersistentCloudKitContainer

    private init() {
        persistentContainer = NSPersistentCloudKitContainer(name: "CourseModel")
        
        // 使用App Group共享路径
        let appGroupIdentifier = "group.NTPUOne.NextCourseWidget"
        if let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("shared.sqlite") {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.xujk.NTPUOne")
            
            // 啟用自動輕量級遷移，確保資料不會遺失
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            persistentContainer.persistentStoreDescriptions = [storeDescription]
        }
        
        persistentContainer.loadPersistentStores { (description, error) in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            } else {
                print("✅ CoreDataManager store loaded at: \(description.url?.path ?? "unknown")")
            }
        }
    }

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

