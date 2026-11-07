import CoreData
import Foundation

@main
struct CourseScheduleStorageChecks {
    static func main() throws {
        let entity = NSEntityDescription()
        entity.name = "CourseEntity"
        entity.managedObjectClassName = NSStringFromClass(CourseEntity.self)
        entity.properties = ["day", "id", "location", "name", "startTime", "teacher", "timeSlot", "isNotification"].map { name in
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = name == "isNotification" ? .booleanAttributeType : .stringAttributeType
            attribute.isOptional = name != "isNotification"
            if name == "isNotification" { attribute.defaultValue = false }
            return attribute
        }
        let model = NSManagedObjectModel()
        model.entities = [entity]
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        func insert(_ id: String, day: String = "Monday", slot: String = "Morning 1") -> CourseEntity {
            let row = CourseEntity(context: context)
            row.id = id
            row.day = day
            row.timeSlot = slot
            row.name = id
            return row
        }

        func expectCollision() throws {
            do {
                try CourseScheduleStorage.validatePendingChanges(in: context)
                preconditionFailure("Expected a storage conflict")
            } catch is CourseScheduleStorage.Conflict {}
        }

        _ = insert("A")
        try CourseScheduleStorage.validatePendingChanges(in: context)
        try context.save()
        _ = insert("B", day: " monday ")
        try expectCollision()
        context.rollback()
        _ = insert("B", slot: "Morning 2")
        _ = insert("C", slot: "Morning 2")
        try expectCollision()
        context.rollback()

        // Simulate CloudKit importing a record independently of the local writers.
        _ = insert("B")
        try context.save()
        var rows = try context.fetch(CourseEntity.fetchRequest())
        for order in [rows, Array(rows.reversed())] {
            let result = CourseScheduleStorage.partition(order)
            precondition(result.visible.map(\.id) == ["A"])
            precondition(result.conflicts.map(\.id) == ["B"])
        }

        let hidden = rows.first { $0.id == "B" }!
        hidden.timeSlot = "Morning 2"
        try CourseScheduleStorage.validatePendingChanges(in: context)
        try context.save()
        rows = try context.fetch(CourseEntity.fetchRequest())
        precondition(CourseScheduleStorage.partition(rows).conflicts.isEmpty)

        _ = insert("A", slot: "Morning 3")
        try expectCollision()
        context.rollback()
        let original = rows.first { $0.id == "A" }!
        let duplicate = insert("D", day: " monday ")
        duplicate.name = original.name
        try context.save()
        rows = try context.fetch(CourseEntity.fetchRequest())
        let duplicates = CourseScheduleStorage.duplicateGroups(rows)
        precondition(duplicates.count == 1 && duplicates[0].map(\.id) == ["A", "D"])
        context.delete(original)
        try context.save()
        rows = try context.fetch(CourseEntity.fetchRequest())
        let recalculated = CourseScheduleStorage.partition(rows)
        precondition(recalculated.conflicts.isEmpty && recalculated.visible.contains(duplicate))
        print("PASS: local and batch collisions, deterministic imported conflict, move, duplicate ID, duplicate grouping and recalculation after deletion")
    }
}
