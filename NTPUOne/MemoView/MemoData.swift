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
    
    // 自動提醒設定
    var disableAutoDueReminder: Bool = false  // 是否禁用自動截止前提醒
    var disableAutoPlanReminder: Bool = false // 是否禁用自動計劃時間提醒
    
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
            return String(localized: "status_done")
        }
        
        if dueAt < now {
            let components = calendar.dateComponents([.day, .hour], from: dueAt, to: now)
            if let days = components.day, days > 0 {
                return String(localized: "overdue_days \(days)")
            } else if let hours = components.hour, hours > 0 {
                return String(localized: "overdue_hours \(hours)")
            } else {
                return String(localized: "just_overdue")
            }
        } else {
            let components = calendar.dateComponents([.day, .hour], from: now, to: dueAt)
            if let days = components.day, days > 0 {
                return String(localized: "days_remaining \(days)")
            } else if let hours = components.hour, hours > 0 {
                return String(localized: "hours_remaining \(hours)")
            } else {
                return String(localized: "about_to_expire")
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
        
        var displayName: String {
            switch self {
            case .activity: return String(localized: "tag_type_activity")
            case .homework: return String(localized: "tag_type_homework")
            case .exam: return String(localized: "tag_type_exam")
            case .meeting: return String(localized: "tag_type_meeting")
            case .reminder: return String(localized: "tag_type_reminder")
            case .other: return String(localized: "tag_type_other")
            }
        }
        
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
            case .todo: return String(localized: "status_not_started")
            case .doing: return String(localized: "status_doing")
            case .done: return String(localized: "status_done")
            case .snoozed: return String(localized: "status_snoozed")
            }
        }
        
        var icon: String {
            switch self {
            case .todo: return "circle"
            case .doing: return "hourglass.circle"
            case .done: return "checkmark.circle"
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
            case .medium: return "flag"
            case .high: return "exclamationmark.3"
            }
        }
        
        var displayName: String {
            switch self {
            case .low: return String(localized: "priority_normal")
            case .medium: return String(localized: "priority_important")
            case .high: return String(localized: "priority_urgent")
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

// MARK: - Memo Templates
struct MemoTemplate: Identifiable, CaseIterable, Equatable {
    let id: String
    let titleKey: String
    let tagType: Memo.TagType
    let priority: Memo.Priority
    let enablesAutoDueReminder: Bool
    let enablesAutoPlanReminder: Bool
    let icon: String

    var title: String { String(localized: String.LocalizationValue(titleKey)) }
    var presetDisableAutoDueReminder: Bool? { enablesAutoDueReminder ? false : nil }
    var presetDisableAutoPlanReminder: Bool? { enablesAutoPlanReminder ? false : nil }

    static let homework = MemoTemplate(
        id: "homework",
        titleKey: "memo_template_homework",
        tagType: .homework,
        priority: .medium,
        enablesAutoDueReminder: true,
        enablesAutoPlanReminder: false,
        icon: "doc.text"
    )

    static let exam = MemoTemplate(
        id: "exam",
        titleKey: "memo_template_exam",
        tagType: .exam,
        priority: .high,
        enablesAutoDueReminder: false,
        enablesAutoPlanReminder: true,
        icon: "pencil.and.list.clipboard"
    )

    static let report = MemoTemplate(
        id: "report",
        titleKey: "memo_template_report",
        tagType: .homework,
        priority: .high,
        enablesAutoDueReminder: false,
        enablesAutoPlanReminder: false,
        icon: "doc.richtext"
    )

    static let clubActivity = MemoTemplate(
        id: "clubActivity",
        titleKey: "memo_template_club_activity",
        tagType: .activity,
        priority: .low,
        enablesAutoDueReminder: false,
        enablesAutoPlanReminder: false,
        icon: "person.3"
    )

    static let courseAddDrop = MemoTemplate(
        id: "courseAddDrop",
        titleKey: "memo_template_course_add_drop",
        tagType: .reminder,
        priority: .high,
        enablesAutoDueReminder: false,
        enablesAutoPlanReminder: false,
        icon: "arrow.left.arrow.right.circle"
    )

    static let withdrawal = MemoTemplate(
        id: "withdrawal",
        titleKey: "memo_template_withdrawal",
        tagType: .reminder,
        priority: .high,
        enablesAutoDueReminder: false,
        enablesAutoPlanReminder: false,
        icon: "exclamationmark.triangle"
    )

    static let quiz = MemoTemplate(
        id: "quiz",
        titleKey: "memo_template_quiz",
        tagType: .exam,
        priority: .high,
        enablesAutoDueReminder: false,
        enablesAutoPlanReminder: true,
        icon: "questionmark.app"
    )

    static let midtermFinal = MemoTemplate(
        id: "midtermFinal",
        titleKey: "memo_template_midterm_final",
        tagType: .exam,
        priority: .high,
        enablesAutoDueReminder: false,
        enablesAutoPlanReminder: true,
        icon: "calendar.badge.clock"
    )

    static let groupReport = MemoTemplate(
        id: "groupReport",
        titleKey: "memo_template_group_report",
        tagType: .homework,
        priority: .high,
        enablesAutoDueReminder: false,
        enablesAutoPlanReminder: false,
        icon: "person.2.wave.2"
    )

    static let allCases: [MemoTemplate] = [
        .homework,
        .exam,
        .report,
        .clubActivity,
        .courseAddDrop,
        .withdrawal,
        .quiz,
        .midtermFinal,
        .groupReport
    ]
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
        
        var displayName: String {
            switch self {
            case .beforeDue: return String(localized: "reminder_before_due")
            case .atPlan: return String(localized: "reminder_at_plan")
            case .custom: return String(localized: "reminder_custom")
            }
        }
    }
    
    enum RepeatType: String, CaseIterable, Identifiable, Codable {
        case none = "不重複"
        case daily = "每天"
        case weekly = "每週"
        case monthly = "每月"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .none: return String(localized: "repeat_none")
            case .daily: return String(localized: "repeat_daily")
            case .weekly: return String(localized: "repeat_weekly")
            case .monthly: return String(localized: "repeat_monthly")
            }
        }
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
