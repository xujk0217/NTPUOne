//
//  CourseEntity+CoreDataClass.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//
//

import Foundation
import CoreData

@objc(CourseEntity)
public class CourseEntity: NSManagedObject {

}

/// Shared by the App and widgets so a synced collision has the same visible winner.
enum CourseScheduleStorage {
    private struct Slot: Hashable {
        let day: String
        let period: String

        init?(_ row: CourseEntity) {
            guard let day = row.day?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !day.isEmpty,
                  let period = row.timeSlot?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !period.isEmpty else { return nil }
            self.day = day
            self.period = period
        }
    }

    struct Conflict: LocalizedError {
        var errorDescription: String? { "這個時段已有課程，請選擇其他時段或先處理同步衝突。" }
    }

    static func validatePendingChanges(in context: NSManagedObjectContext) throws {
        context.processPendingChanges()
        let fields: Set<String> = ["day", "timeSlot", "id"]
        let touched = context.insertedObjects.union(context.updatedObjects).compactMap { $0 as? CourseEntity }
            .filter { !$0.isDeleted && ($0.isInserted || !fields.isDisjoint(with: $0.changedValues().keys)) }
        guard !touched.isEmpty else { return }

        let rows = try context.fetch(CourseEntity.fetchRequest())
        for row in touched {
            guard let slot = Slot(row), let id = row.id, !id.isEmpty else { throw Conflict() }
            if rows.contains(where: { $0 !== row && !$0.isDeleted && (Slot($0) == slot || $0.id == id) }) {
                throw Conflict()
            }
        }
    }

    static func partition(_ rows: [CourseEntity]) -> (visible: [CourseEntity], conflicts: [CourseEntity]) {
        // Course IDs and values sync across devices. The local object ID only breaks
        // ties between rows with otherwise identical display values.
        let sorted = rows.sorted { lhs, rhs in
            let left = order(lhs), right = order(rhs)
            if left != right { return left.lexicographicallyPrecedes(right) }
            return lhs.objectID.uriRepresentation().absoluteString < rhs.objectID.uriRepresentation().absoluteString
        }
        var slots = Set<Slot>()
        var ids = Set<String>()
        var visible: [CourseEntity] = [], conflicts: [CourseEntity] = []
        for row in sorted {
            let slot = Slot(row)
            let id = row.id.flatMap { $0.isEmpty ? nil : $0 }
            if slot.map(slots.contains) == true || id.map(ids.contains) == true {
                conflicts.append(row)
                continue
            }
            if let slot { slots.insert(slot) }
            if let id { ids.insert(id) }
            visible.append(row)
        }
        return (visible, conflicts)
    }

    private static func order(_ row: CourseEntity) -> [String] {
        [row.id ?? "", row.name ?? "", row.day ?? "", row.timeSlot ?? "", row.startTime ?? "",
         row.location ?? "", row.teacher ?? "", row.isNotification ? "1" : "0"]
    }
}
