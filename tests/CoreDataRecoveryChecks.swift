import Foundation
import CoreData

@main
enum CoreDataRecoveryChecks {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        func model() -> NSManagedObjectModel {
            let title = NSAttributeDescription()
            title.name = "title"
            title.attributeType = .stringAttributeType
            title.isOptional = false
            let entity = NSEntityDescription()
            entity.name = "Record"
            entity.managedObjectClassName = "NSManagedObject"
            entity.properties = [title]
            let model = NSManagedObjectModel()
            model.entities = [entity]
            return model
        }

        let blocked = root.appendingPathComponent("blocked")
        let sentinel = Data("existing data must survive".utf8)
        try sentinel.write(to: blocked)
        let manager = CoreDataManager(storeURL: blocked.appendingPathComponent("store.sqlite"),
                                      model: model(), cloudSyncEnabled: false)
        precondition(!manager.isReady && manager.loadError != nil, "Load failure must be recoverable")
        let preserved = try Data(contentsOf: blocked)
        precondition(preserved == sentinel, "Load failure must preserve original bytes")

        // Remove only our test obstacle, then prove the same manager can retry.
        try FileManager.default.removeItem(at: blocked)
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
        manager.retryLoading()
        precondition(manager.isReady && manager.loadError == nil, "Retry must load the store")

        let context = manager.persistentContainer.viewContext
        let record = NSEntityDescription.insertNewObject(forEntityName: "Record", into: context)
        precondition(!manager.saveContext(), "Missing required title must fail validation")
        precondition(context.hasChanges && manager.operationError != nil, "Failed save must retain pending changes")
        record.setValue("recovered", forKey: "title")
        precondition(manager.saveContext() && !context.hasChanges, "Pending save must be retryable")
        precondition(manager.operationError == nil, "Successful retry must clear the error")
        let count = try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Record"))
        precondition(count == 1)

        let unavailable = CoreDataManager(storeURL: nil, model: model(), cloudSyncEnabled: false)
        unavailable.retryLoading()
        precondition(!unavailable.isReady && unavailable.loadError != nil)
        precondition(unavailable.persistentContainer.persistentStoreDescriptions.isEmpty,
                     "Missing App Group must never fall back to a different database")
        print("PASS: load failure, original data preservation, load retry, failed save retention, save retry, missing App Group")
    }
}
