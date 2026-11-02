//
//  CourseGridView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI
import UIKit

struct UnifiedCourseGridView: View {
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @State private var showingAlert = false
    @State private var showingSheet = false
    @State private var selectedCourse = Course(id: "", name: "", day: "Friday", startTime: .none, timeSlot: .morning1, location: "", teacher: "", isNotification: true)
    @State private var newCourse = Course(id: "", name: "", day: "Monday", startTime: .none, timeSlot: .morning1, location: "", teacher: "", isNotification: true)
    @State private var isNewCourse = false
    
    @Binding var includeSaturday: Bool

    @State var peekCourse: Course? = nil

    @Binding var includeNight: Bool
    
    @ObservedObject var memoManager: MemoManager  // 新增

    var body: some View {
        VStack(spacing: 8) {
            // A small eager grid keeps row heights stable through keyboard/tab transitions.
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(displayedDays.enumerated()), id: \.element) { index, day in
                    VStack(spacing: 8) {
                        DayBadge(text: displayedShortDays[index])
                        MorningCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager)
                    }.frame(maxWidth: .infinity, alignment: .top)
                }
            }.fixedSize(horizontal: false, vertical: true)
            LunchButtonView()
            HStack(alignment: .top, spacing: 8) {
                ForEach(displayedDays, id: \.self) { day in
                    AfternoonCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }.fixedSize(horizontal: false, vertical: true)
            if includeNight {
                DinnerButtonView()
                HStack(alignment: .top, spacing: 8) {
                    ForEach(displayedDays, id: \.self) { day in
                        EveningCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                }.fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .cornerRadius(8)
        .sheet(isPresented: $showingSheet) {
            CourseFormSheet(isNewCourse: $isNewCourse, selectedCourse: $selectedCourse, newCourse: $newCourse, courseData: courseData, showingSheet: $showingSheet, memoManager: memoManager)
        }
        .sheet(item: $peekCourse, onDismiss: {
            // 當課程詳情 sheet 關閉時，重新加載備忘錄數據以確保點點更新
            memoManager.loadMemosFromCoreData()
        }) { course in
            CourseDetailSheet(course: course, memoManager: memoManager, courseData: courseData)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    var displayedDays: [String] {
        includeSaturday ? ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"] : ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    }

    var displayedShortDays: [String] {
        includeSaturday ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] : ["Mon", "Tue", "Wed", "Thu", "Fri"]
    }

    var columns: [GridItem] {
        Array(repeating: .init(.flexible()), count: displayedDays.count)
    }
}


struct MorningCourseColumnView: View {
    var day: String
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @Binding var showingSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var selectedCourse: Course
    @Binding var isNewCourse: Bool
    @Binding var newCourse: Course
    @Binding var peekCourse: Course?
    @ObservedObject var memoManager: MemoManager

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Course.TimeSlot.allCases.prefix(4), id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager, courseData: courseData)
                
            }
        }
    }
}

struct AfternoonCourseColumnView: View {
    var day: String
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @Binding var showingSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var selectedCourse: Course
    @Binding var isNewCourse: Bool
    @Binding var newCourse: Course
    @Binding var peekCourse: Course?
    @ObservedObject var memoManager: MemoManager

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Course.TimeSlot.allCases[4..<9], id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager, courseData: courseData)
            }
        }
    }
}

struct EveningCourseColumnView: View {
    var day: String
    @ObservedObject var courseData: CourseData
    @Binding var isEdit: Bool
    @Binding var showingSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var selectedCourse: Course
    @Binding var isNewCourse: Bool
    @Binding var newCourse: Course
    @Binding var peekCourse: Course?
    @ObservedObject var memoManager: MemoManager

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Course.TimeSlot.allCases[9..<13], id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager, courseData: courseData)
            }
        }
    }
}

struct CourseSlotView: View {
    var day: String
    var slot: Course.TimeSlot
    var filteredCourses: [Course]
    @Binding var isEdit: Bool
    @Binding var showingSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var selectedCourse: Course
    @Binding var isNewCourse: Bool
    @Binding var newCourse: Course
    @Binding var peekCourse: Course?
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData

    // 時間格式器（避免每次 new）
    private let weekFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE"; f.locale = Locale(identifier: "en_US"); return f
    }()
    private let hourFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH"; return f }()
    private let minuteFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "mm"; return f }()

    var body: some View {
        let isNow = setCurrentCourse(day: day, slot: slot)

        VStack(spacing: 4) {
            if filteredCourses.isEmpty {
                if isEdit {
                    AddCourseTile(tint: slotTint(slot)) { addNewCourse() }
                } else {
                    // 留空但顯示 NOW 標籤（若命中）
                    if isNow {
                        Text("NOW")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red.opacity(0.15), in: Capsule())
                            .foregroundStyle(.red)
                    } else {
                        Spacer(minLength: 0)
                        Text("").font(.caption)
                        Spacer(minLength: 0)
                    }
                }
            } else {
                ForEach(filteredCourses) { course in
                    if isEdit {
                        Button { editCourse(course) } label: {
                            VStack(spacing: 2) {
                                Text(course.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(slotTint(slot))          // 保持原本 tint 給課名

                                Text(course.location.isEmpty ? "—" : course.location)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.secondary)              // 教室用次要色
                                
                                // 顯示備忘錄相關的顏色點（每個顏色只顯示一個）
                                let uniqueTagTypes = getUniqueTagTypes(for: course)
                                if !uniqueTagTypes.isEmpty {
                                    HStack(spacing: 2) {
                                        ForEach(uniqueTagTypes, id: \.self) { tagType in
                                            Circle()
                                                .fill(tagType.color)
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(6)
                            
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { viewCourseDetails(course) } label: {
                            VStack(spacing: 4) {
                                if isNow {
                                    Text("NOW")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.red.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.red)
                                }
                                VStack(spacing: 2) {
                                    Text(course.name)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.primary)

                                    Text(course.location.isEmpty ? "—" : course.location)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .foregroundStyle(.secondary)
                                    
                                    // 顯示備忘錄相關的顏色點（每個顏色只顯示一個）
                                    let uniqueTagTypes = getUniqueTagTypes(for: course)
                                    if !uniqueTagTypes.isEmpty {
                                        HStack(spacing: 2) {
                                            ForEach(uniqueTagTypes, id: \.self) { tagType in
                                                Circle()
                                                    .fill(tagType.color)
                                                    .frame(width: 4, height: 4)
                                            }
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 6).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .frame(height: 100)
        .frame(minWidth: 35, maxWidth: 80)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isNow ? slotTint(slot).opacity(0.08) : Color.gray.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isNow ? slotTint(slot).opacity(0.35) : Color.gray.opacity(0.25))
        )
        .id("\(memoManager.memos.count)_\(memoManager.memos.map { "\($0.id)_\($0.status.rawValue)_\($0.courseLink ?? "")" }.joined(separator: "_"))")
    }
    
    // 判斷兩個時段是否相連
    func areTimeSlotsConnected(_ slot1: Course.TimeSlot, _ slot2: Course.TimeSlot) -> Bool {
        let slots = Course.TimeSlot.allCases
        guard let index1 = slots.firstIndex(of: slot1),
              let index2 = slots.firstIndex(of: slot2) else {
            return false
        }
        return abs(index1 - index2) == 1
    }
    
    // 找出同一天所有同名課程
    func findConnectedCourseGroup(for course: Course) -> Set<String> {
        // 找出所有與當前課程同名且在同一天的課程
        let sameNameSameDayCourses = courseData.courses.filter { otherCourse in
            otherCourse.name == course.name && otherCourse.day == course.day
        }
        
        if sameNameSameDayCourses.isEmpty {
            return [course.id]
        }
        
        // 返回同一天所有同名課程的 ID
        return Set(sameNameSameDayCourses.map { $0.id })
    }
    
    // 取得與課程相關的備忘錄（檢查同一天的同名課程）
    func getRelatedMemos(for course: Course) -> [Memo] {
        // 找出同一天所有同名課程
        let connectedCourseIds = findConnectedCourseGroup(for: course)
        
        // 返回與這些課程關聯的所有未完成備忘錄
        return memoManager.memos.filter { memo in
            connectedCourseIds.contains(memo.courseLink ?? "") && memo.status != .done
        }
    }
    
    // 取得與課程相關的不重複標籤類型（每個顏色只顯示一個）
    func getUniqueTagTypes(for course: Course) -> [Memo.TagType] {
        let relatedMemos = getRelatedMemos(for: course)
        var seenTagTypes = Set<Memo.TagType>()
        var uniqueTagTypes: [Memo.TagType] = []
        
        for memo in relatedMemos {
            if !seenTagTypes.contains(memo.tagType) {
                seenTagTypes.insert(memo.tagType)
                uniqueTagTypes.append(memo.tagType)
            }
        }
        
        return uniqueTagTypes
    }

    // ===== 互動 =====
    func addNewCourse() {
        newCourse = Course(id: UUID().uuidString, name: "", day: day, startTime: .none, timeSlot: slot, location: "", teacher: "", isNotification: true)
        isNewCourse = true
        showingSheet = true
    }
    func editCourse(_ course: Course) {
        selectedCourse = course
        isNewCourse = false
        showingSheet = true
    }
    func viewCourseDetails(_ course: Course) {
//        selectedCourse = course
//        showingAlert = true
        if peekCourse?.id == course.id {
            peekCourse = nil
            DispatchQueue.main.async { peekCourse = course }
        } else {
            peekCourse = course
        }
    }

    // ===== 現在時段判斷（保留你的邏輯，只調整命名）=====
    func setCurrentCourse(day: String, slot: Course.TimeSlot) -> Bool {
        let now = Date()
        if day != weekFmt.string(from: now) { return false }
        let hh = hourFmt.string(from: now)
        let mm = Int(minuteFmt.string(from: now)) ?? 0

        switch slot {
        case .morning1: return hh == "08"
        case .morning2: return hh == "09"
        case .morning3: return hh == "10"
        case .morning4: return hh == "11"
        case .afternoon1: return hh == "13"
        case .afternoon2: return hh == "14"
        case .afternoon3: return hh == "15"
        case .afternoon4: return hh == "16"
        case .afternoon5: return hh == "17"
        case .evening1: return (hh == "18") || (hh == "19" && mm < 25)
        case .evening2: return (hh == "19" && mm >= 25) || (hh == "20" && mm < 20)
        case .evening3: return (hh == "20" && mm >= 20) || (hh == "21" && mm < 15)
        case .evening4: return (hh == "21" && mm >= 15) || (hh == "22" && mm < 15)
        }
    }
}


struct CourseFormSheet: View {
    @Binding var isNewCourse: Bool
    @Binding var selectedCourse: Course
    @Binding var newCourse: Course
    var courseData: CourseData
    @Binding var showingSheet: Bool
    var memoManager: MemoManager
    
    @State private var showDeleteAlert = false
    @State private var relatedMemoCount = 0
    @State private var isLastCourseWithName = false
    
    var body: some View {
        ZStack {
            if !isNewCourse {
                CourseFormView(course: $selectedCourse, isNewCourse: false, onSave: {
                    if let index = courseData.courses.firstIndex(where: { $0.id == selectedCourse.id }) {
                        courseData.courses[index] = selectedCourse
                        courseData.updateCourse(selectedCourse)
                    }
                    showingSheet = false
                }, onCancel: {
                    showingSheet = false
                }, onDelete: {
                    handleDeleteCourse()
                }, courseData: courseData)
            } else {
                CourseFormView(course: $newCourse, isNewCourse: true, onSave: {
                    courseData.addCourse(newCourse)
                    showingSheet = false
                }, onCancel: {
                    showingSheet = false
                }, courseData: courseData)
            }
        }
        .alert(String(localized: "alert_confirm_delete_course"), isPresented: $showDeleteAlert) {
            Button(String(localized: "delete"), role: .destructive) {
                performDelete()
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            if isLastCourseWithName && relatedMemoCount > 0 {
                Text(String(localized: "delete_last_course_with_memos \(selectedCourse.name) \(relatedMemoCount)"))
            } else {
                Text(String(localized: "delete_course_confirm"))
            }
        }
    }
    
    private func handleDeleteCourse() {
        // 檢查是否是最後一個同名課程
        let sameNameCourses = courseData.courses.filter { $0.name == selectedCourse.name }
        isLastCourseWithName = sameNameCourses.count == 1
        
        // 如果是最後一個，計算相關任務數量
        // courseLink 存的是課程 ID，需要收集所有同名課程的 ID
        if isLastCourseWithName {
            let sameNameCourseIds = Set(sameNameCourses.map { $0.id })
            relatedMemoCount = memoManager.memos.filter { memo in
                guard let courseLink = memo.courseLink else { return false }
                return sameNameCourseIds.contains(courseLink)
            }.count
        } else {
            relatedMemoCount = 0
        }
        
        print("📋 刪除檢查: 同名課程數=\(sameNameCourses.count), 是最後一個=\(isLastCourseWithName), 相關任務數=\(relatedMemoCount)")
        
        // 顯示確認提示
        showDeleteAlert = true
    }
    
    private func performDelete() {
        print("🗑️ 開始執行刪除: 課程名稱=\(selectedCourse.name)")
        
        let sameNameCourses = courseData.courses.filter { $0.name == selectedCourse.name }
        
        if isLastCourseWithName {
            // 最後一個同名課程，刪除相關任務
            let sameNameCourseIds = Set(sameNameCourses.map { $0.id })
            let relatedMemos = memoManager.memos.filter { memo in
                guard let courseLink = memo.courseLink else { return false }
                return sameNameCourseIds.contains(courseLink)
            }
            print("🗑️ 找到 \(relatedMemos.count) 個相關任務需要刪除")
            for memo in relatedMemos {
                print("🗑️ 刪除任務: \(memo.title)")
                memoManager.deleteMemo(memo)
            }
        } else {
            // 還有其他同名課程，把指向被刪除課程的任務轉移到另一個同名課程
            if let otherCourse = sameNameCourses.first(where: { $0.id != selectedCourse.id }) {
                let affectedMemos = memoManager.memos.filter { $0.courseLink == selectedCourse.id }
                print("🔄 轉移 \(affectedMemos.count) 個任務到課程 ID: \(otherCourse.id)")
                for memo in affectedMemos {
                    var updatedMemo = memo
                    updatedMemo.courseLink = otherCourse.id
                    memoManager.updateMemo(updatedMemo)
                }
            }
        }
        
        // 刪除課程
        print("🗑️ 刪除課程: \(selectedCourse.name)")
        courseData.deleteCourse(selectedCourse)
        
        // 刷新備忘錄數據
        memoManager.loadMemosFromCoreData()
        
        showingSheet = false
    }
}

struct LunchButtonView: View {
    var body: some View {
        NavigationLink {
            LunchView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "takeoutbag.and.cup.and.straw")
                    .imageScale(.medium)
                Text(String(localized: "lunch_time")).font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

struct DinnerButtonView: View {
    var body: some View {
        NavigationLink {
            dinnerView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .imageScale(.medium)
                Text(String(localized: "dinner_time")).font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}


private func slotTint(_ slot: Course.TimeSlot) -> Color {
    switch slot {
    case .morning1, .morning2, .morning3, .morning4: return .blue
    case .afternoon1, .afternoon2, .afternoon3, .afternoon4, .afternoon5: return .orange
    case .evening1, .evening2, .evening3, .evening4: return .purple
    }
}

private struct DayBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.vertical, 6).frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct AddCourseTile: View {
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.headline)
                Text(String(localized: "add")).font(.caption2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .foregroundStyle(tint)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(tint.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

struct CourseDetailSheet: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    @State private var selectedAcademicCourse: MoodleCourse?
    @State private var selectedMoodleTab: AcademicCourseTab = .announcements
    @State private var showMoodlePicker = false
    @State private var showAcademicLogin = false
    let course: Course
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMemo: Memo? = nil
    @State private var selectedTemplate: MemoTemplate? = nil
    @State private var isEditingOrder: Bool = false
    
    // 標籤順序持久化（使用 JSON 字串存儲）
    @AppStorage("courseDetailTagOrder") private var tagOrderData: String = ""
    
    private var tagOrder: [Memo.TagType] {
        get {
            guard !tagOrderData.isEmpty,
                  let data = tagOrderData.data(using: .utf8),
                  let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
                return Memo.TagType.allCases
            }
            let restored = rawValues.compactMap { Memo.TagType(rawValue: $0) }
            return restored + Memo.TagType.allCases.filter { !restored.contains($0) }
        }
    }
    
    private func saveTagOrder(_ order: [Memo.TagType]) {
        let rawValues = order.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(rawValues),
           let string = String(data: data, encoding: .utf8) {
            tagOrderData = string
        }
    }

    private var weekdayLabel: String {
        ["Monday": "週一", "Tuesday": "週二", "Wednesday": "週三", "Thursday": "週四", "Friday": "週五", "Saturday": "週六", "Sunday": "週日"][course.day] ?? course.day
    }
    private var courseTimeLabel: String {
        guard course.startTime == .none else { return course.startTime.rawValue }
        let times = ["8:10", "9:10", "10:10", "11:10", "13:10", "14:10", "15:10", "16:10", "17:10", "18:30", "19:25", "20:25", "21:20"]
        guard let index = Course.TimeSlot.allCases.firstIndex(of: course.timeSlot), times.indices.contains(index) else { return "時間未設定" }
        return times[index]
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(course.name.isEmpty ? String(localized: "unnamed_course") : course.name)
                        .font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        Label(course.teacher.isEmpty ? "未設定教師" : course.teacher, systemImage: "person")
                        Label(course.isNotification ? "提醒開啟" : "提醒關閉", systemImage: course.isNotification ? "bell" : "bell.slash")
                    }.font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 14) {
                        Label("\(weekdayLabel) \(courseTimeLabel)", systemImage: "clock")
                        if !course.location.isEmpty { Label(course.location, systemImage: "mappin.and.ellipse") }
                    }.font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Moodle", systemImage: "books.vertical").font(.headline)
                        Spacer()
                        if academic.moodleLinked {
                            Button("配對") { showMoodlePicker = true }.font(.subheadline)
                        }
                    }
                    if let source = academic.moodleCourse(forCourseID: course.id) {
                        Text(source.fullname).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Button {
                            selectedMoodleTab = .announcements; selectedAcademicCourse = source
                        } label: {
                            HStack {
                                Label("公告、教材、作業與成績", systemImage: "square.grid.2x2")
                                Spacer(); Image(systemName: "chevron.right").font(.caption)
                            }.frame(maxWidth: .infinity).padding(12)
                                .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                    } else if academic.moodleLinked {
                        Text("尚未配對課程").font(.subheadline).foregroundStyle(.secondary)
                        Button("選擇 Moodle 課程") { showMoodlePicker = true }
                    } else {
                        Text("連結後可查看課程內容與作業。").font(.subheadline).foregroundStyle(.secondary)
                        Button("連結學校帳號") { showAcademicLogin = true }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                let relatedMemos = getRelatedMemos()
                let grouped = Dictionary(grouping: relatedMemos) { $0.tagType }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("課程待辦", systemImage: "checklist").font(.headline)
                        Text("\(relatedMemos.count)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if !relatedMemos.isEmpty { Button { isEditingOrder = true } label: { Image(systemName: "arrow.up.arrow.down") }.accessibilityLabel("調整待辦分類順序") }
                        Menu {
                            ForEach(MemoTemplate.allCases) { template in
                                Button { selectedTemplate = template } label: { Label(template.title, systemImage: template.icon) }
                            }
                        } label: { Image(systemName: "plus.circle.fill").font(.title3) }.accessibilityLabel("新增課程待辦")
                    }
                    if relatedMemos.isEmpty {
                        Text("尚無課程待辦").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 6)
                    } else {
                        ForEach(tagOrder.filter { grouped[$0] != nil }, id: \.self) { tag in
                            VStack(alignment: .leading, spacing: 4) {
                                Label(tag.displayName, systemImage: tag.icon).font(.caption.weight(.semibold)).foregroundStyle(tag.color).padding(.top, 4)
                                ForEach(grouped[tag] ?? []) { memo in
                                    Button { selectedMemo = memo } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: memo.status.icon).foregroundStyle(memo.status.color).frame(width: 20)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(memo.title).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                                if let date = memo.dueAt ?? memo.planAt {
                                                    Text(formatShortDate(date)).font(.caption).foregroundStyle(memo.isOverdue ? .red : .secondary)
                                                }
                                            }
                                            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                        }.padding(.vertical, 8).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                Menu {
                    Button("Moodle 網站") { openCourseShortcut("https://lms3.ntpu.edu.tw/") }
                    Button("課程評價") { openCourseShortcut("https://no21.ntpu.org/") }
                    Button("考古題") { openCourseShortcut("https://past-exam.ntpu.cc") }
                } label: { Label("更多課程連結", systemImage: "link").font(.subheadline) }
                .padding(.horizontal, 4)
            }.padding(16)
        }
        .sheet(item: $selectedAcademicCourse) { source in
            NavigationStack { AcademicCourseContentView(course: source, initialTab: selectedMoodleTab) }.environmentObject(academic)
        }
        .sheet(isPresented: $showMoodlePicker) {
            NavigationStack { AcademicCourseMappingView(courseID: course.id) }.environmentObject(academic)
        }
        .sheet(isPresented: $showAcademicLogin) {
            NavigationStack { AcademicConnectionView() }.environmentObject(academic)
        }
        .sheet(item: $selectedMemo) { memo in
            MemoDetailSheet(memoManager: memoManager, courseData: courseData, memo: memo)
        }
        .sheet(isPresented: $isEditingOrder) {
            TagOrderEditSheet(currentOrder: tagOrder, onSave: saveTagOrder)
        }
        .sheet(item: $selectedTemplate) { template in
            MemoFormView(
                memoManager: memoManager,
                courseData: courseData,
                memo: nil,
                presetCourseLink: course.id,
                presetTitle: "\(course.name) \(template.title)",
                presetTagType: template.tagType,
                presetPriority: template.priority,
                presetDisableAutoDueReminder: template.presetDisableAutoDueReminder,
                presetDisableAutoPlanReminder: template.presetDisableAutoPlanReminder
            )
        }
    }

    private func openCourseShortcut(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - 標籤排序編輯 Sheet
    struct TagOrderEditSheet: View {
        @Environment(\.dismiss) private var dismiss
        @State private var editableOrder: [Memo.TagType]
        let onSave: ([Memo.TagType]) -> Void
        
        init(currentOrder: [Memo.TagType], onSave: @escaping ([Memo.TagType]) -> Void) {
            self._editableOrder = State(initialValue: currentOrder)
            self.onSave = onSave
        }
        
        var body: some View {
            NavigationStack {
                List {
                    Section {
                        ForEach(editableOrder, id: \.self) { tagType in
                            HStack(spacing: 8) {
                                Image(systemName: tagType.icon)
                                    .foregroundStyle(tagType.color)
                                    .frame(width: 24)
                                Text(tagType.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .onMove { from, to in
                            editableOrder.move(fromOffsets: from, toOffset: to)
                        }
                    } header: {
                        Text(String(localized: "drag_to_reorder"))
                    } footer: {
                        Text(String(localized: "order_affects_display"))
                    }
                }
                .environment(\.editMode, .constant(.active))
                .navigationTitle(String(localized: "navigation_tag_order"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "cancel")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "save")) {
                            onSave(editableOrder)
                            dismiss()
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            Spacer()
        }
    }
    
    // 格式化簡短日期
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()
        
        // 如果是今天，只顯示時間
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        
        // 如果是明天，顯示「明天 HH:mm」
        if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "HH:mm"
            return String(localized: "tomorrow") + " " + formatter.string(from: date)
        }
        
        // 如果是本週內，顯示星期幾和時間
        if let weekDiff = calendar.dateComponents([.weekOfYear], from: now, to: date).weekOfYear,
           weekDiff == 0 {
            formatter.dateFormat = "E HH:mm"
            formatter.locale = Locale(identifier: "zh_TW")
            return formatter.string(from: date)
        }
        
        // 其他情況顯示月/日 時間
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
    
    // 找出同一天所有同名課程
    func findConnectedCourseGroup(for course: Course) -> Set<String> {
        // 找出所有與當前課程同名且在同一天的課程
        let sameNameSameDayCourses = courseData.courses.filter { otherCourse in
            otherCourse.name == course.name && otherCourse.day == course.day
        }
        
        if sameNameSameDayCourses.isEmpty {
            return [course.id]
        }
        
        // 返回同一天所有同名課程的 ID
        return Set(sameNameSameDayCourses.map { $0.id })
    }
    
    // 取得與課程相關的備忘錄（檢查同一天的同名課程）
    func getRelatedMemos() -> [Memo] {
        // 找出同一天所有同名課程
        let connectedCourseIds = findConnectedCourseGroup(for: course)
        
        // 返回與這些課程關聯的所有未完成備忘錄
        return memoManager.memos.filter { memo in
            connectedCourseIds.contains(memo.courseLink ?? "") && memo.status != .done
        }
        .sorted { memo1, memo2 in
            // 優先顯示逾期的
            if memo1.isOverdue && !memo2.isOverdue { return true }
            if !memo1.isOverdue && memo2.isOverdue { return false }
            
            // 然後按截止時間排序
            if let due1 = memo1.dueAt, let due2 = memo2.dueAt {
                return due1 < due2
            }
            return false
        }
    }
}
