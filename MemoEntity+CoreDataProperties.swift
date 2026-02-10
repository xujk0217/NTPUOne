//
//  MemoEntity+CoreDataProperties.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/17.
//
//

import Foundation
import CoreData

extension MemoEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MemoEntity> {
        return NSFetchRequest<MemoEntity>(entityName: "MemoEntity")
    }

    // 基本資料
    @NSManaged public var id: String?
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var tagType: String?
    @NSManaged public var courseLink: String?
    
    // 狀態
    @NSManaged public var status: String?
    @NSManaged public var priority: String?
    
    // 時間戳記
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var dueAt: Date?
    @NSManaged public var planAt: Date?
    @NSManaged public var doneAt: Date?
    
    // 提醒規則（JSON 字串儲存）
    @NSManaged public var reminderRulesData: Data?
    
    // 自動提醒設定
    @NSManaged public var disableAutoDueReminder: Bool
    @NSManaged public var disableAutoPlanReminder: Bool
}

extension MemoEntity: Identifiable {

}
