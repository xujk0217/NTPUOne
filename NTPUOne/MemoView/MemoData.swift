//
//  MemoData.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import Foundation
import SwiftUI

// MARK: - Memo 資料模型
struct Memo: Identifiable, Equatable {
    var id: String
    var title: String
    var content: String
    var tagType: TagType
    var courseLink: String?  // 連結到 Course.id，可為空
    
    // 排程與完成狀態
    var status: MemoStatus
    var priority: Priority
    
    // 時間戳記
    var createdAt: Date
    var updatedAt: Date
    var dueAt: Date?       // 死線時間
    var planAt: Date?      // 計劃執行時間
    var doneAt: Date?      // 完成時間
    
    // 提醒規則
    var reminderRules: [ReminderRule]
    
    // MARK: - 計算屬性
    
    /// 是否逾期
    var isOverdue: Bool {
        guard status != .done, let dueAt = dueAt else { return false }
        return dueAt < Date()
    }
    
    /// 距離截止時間的描述
    var dueDateDescription: String? {
        guard let dueAt = dueAt else { return nil }
        let now = Date()
        let calendar = Calendar.current
        
        if status == .done {
            return "已完成"
        }
        
        if dueAt < now {
            let components = calendar.dateComponents([.day, .hour], from: dueAt, to: now)
            if let days = components.day, days > 0 {
                return "逾期 \(days) 天"
            } else if let hours = components.hour, hours > 0 {
                return "逾期 \(hours) 小時"
            } else {
                return "剛剛逾期"
            }
        } else {
            let components = calendar.dateComponents([.day, .hour], from: now, to: dueAt)
            if let days = components.day, days > 0 {
                return "還剩 \(days) 天"
            } else if let hours = components.hour, hours > 0 {
                return "還剩 \(hours) 小時"
            } else {
                return "即將到期"
            }
        }
    }
    
    // MARK: - Enums
    
    enum TagType: String, CaseIterable, Identifiable {
        case activity = "活動"
        case homework = "作業"
        case exam = "考試"
        case meeting = "會議"
        case reminder = "提醒"
        case other = "其他"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .activity: return "party.popper"
            case .homework: return "doc.text"
            case .exam: return "pencil.and.list.clipboard"
            case .meeting: return "person.3"
            case .reminder: return "bell"
            case .other: return "tag"
            }
        }
        
        var color: Color {
            switch self {
            case .activity: return .orange
            case .homework: return .blue
            case .exam: return .red
            case .meeting: return .purple
            case .reminder: return .yellow
            case .other: return .gray
            }
        }
    }
    
    enum MemoStatus: String, CaseIterable, Identifiable {
        case todo = "未完成"
        case doing = "進行中"
        case done = "已完成"
        case snoozed = "已延後"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .todo: return "未開始"
            case .doing: return "進行中"
            case .done: return "已完成"
            case .snoozed: return "已延後"
            }
        }
        
        var icon: String {
            switch self {
            case .todo: return "circle"
            case .doing: return "circle.lefthalf.filled"
            case .done: return "checkmark.circle.fill"
            case .snoozed: return "clock.arrow.circlepath"
            }
        }
        
        var color: Color {
            switch self {
            case .todo: return .gray
            case .doing: return .blue
            case .done: return .green
            case .snoozed: return .orange
            }
        }
    }
    
    enum Priority: String, CaseIterable, Identifiable {
        case low = "低"
        case medium = "中"
        case high = "高"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .low: return "flag"
            case .medium: return "flag.fill"
            case .high: return "exclamationmark.3"
            }
        }
        
        var displayName: String {
            switch self {
            case .low: return "一般"
            case .medium: return "重要"
            case .high: return "緊急"
            }
        }
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .orange
            case .high: return .red
            }
        }
        
        var sortOrder: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }
    }
}

// MARK: - 提醒規則
struct ReminderRule: Identifiable, Equatable, Codable {
    var id: String
    var triggerAt: Date
    var enabled: Bool
    var kind: ReminderKind
    var repeatType: RepeatType
    
    enum ReminderKind: String, CaseIterable, Identifiable, Codable {
        case beforeDue = "截止前"
        case atPlan = "計劃時間"
        case custom = "自訂"
        
        var id: String { self.rawValue }
    }
    
    enum RepeatType: String, CaseIterable, Identifiable, Codable {
        case none = "不重複"
        case daily = "每天"
        case weekly = "每週"
        case monthly = "每月"
        
        var id: String { self.rawValue }
    }
    
    init(id: String = UUID().uuidString, triggerAt: Date, enabled: Bool = true, kind: ReminderKind = .custom, repeatType: RepeatType = .none) {
        self.id = id
        self.triggerAt = triggerAt
        self.enabled = enabled
        self.kind = kind
        self.repeatType = repeatType
    }
}

// MARK: - 預設建構
extension Memo {
    static func create(
        title: String,
        content: String = "",
        tagType: TagType = .other,
        courseLink: String? = nil,
        priority: Priority = .medium,
        dueAt: Date? = nil,
        planAt: Date? = nil
    ) -> Memo {
        let now = Date()
        return Memo(
            id: UUID().uuidString,
            title: title,
            content: content,
            tagType: tagType,
            courseLink: courseLink,
            status: .todo,
            priority: priority,
            createdAt: now,
            updatedAt: now,
            dueAt: dueAt,
            planAt: planAt,
            doneAt: nil,
            reminderRules: []
        )
    }
}
