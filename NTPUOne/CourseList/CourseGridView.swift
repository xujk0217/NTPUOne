//
//  CourseGridView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI

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
        VStack {
            LazyVGrid(columns: columns) {
                ForEach(displayedShortDays, id: \.self) { day in
                    DayBadge(text: day)
                }
                ForEach(displayedDays, id: \.self) { day in
                    MorningCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager)
                }
            }
            LunchButtonView()
            LazyVGrid(columns: columns) {
                ForEach(displayedDays, id: \.self) { day in
                    AfternoonCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager)
                }
            }
            if includeNight{
                DinnerButtonView()
                LazyVGrid(columns: columns) {
                    ForEach(displayedDays, id: \.self) { day in
                        EveningCourseColumnView(day: day, courseData: courseData, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager)
                    }
                }
            }
        }
        .padding()
        .cornerRadius(8)
        .sheet(isPresented: $showingSheet) {
            CourseFormSheet(isNewCourse: $isNewCourse, selectedCourse: $selectedCourse, newCourse: $newCourse, courseData: courseData, showingSheet: $showingSheet)
        }
        .sheet(item: $peekCourse) { course in
            CourseDetailSheet(course: course, memoManager: memoManager, courseData: courseData)
                .presentationDetents([.medium])
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
        VStack{
            ForEach(Course.TimeSlot.allCases.prefix(4), id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager)
                
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
        VStack{
            ForEach(Course.TimeSlot.allCases[4..<9], id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager)
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
        VStack{
            ForEach(Course.TimeSlot.allCases[9..<13], id: \.self) { slot in
                let filteredCourses = courseData.courses.filter {
                    $0.day == day && $0.timeSlot == slot
                }
                CourseSlotView(day: day, slot: slot, filteredCourses: filteredCourses, isEdit: $isEdit, showingSheet: $showingSheet, showingAlert: $showingAlert, selectedCourse: $selectedCourse, isNewCourse: $isNewCourse, newCourse: $newCourse, peekCourse: $peekCourse, memoManager: memoManager)
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
                                
                                // 顯示備忘錄相關的顏色點
                                if !getRelatedMemos(for: course).isEmpty {
                                    HStack(spacing: 2) {
                                        ForEach(getRelatedMemos(for: course).prefix(3), id: \.id) { memo in
                                            Circle()
                                                .fill(memo.tagType.color)
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
                                    
                                    // 顯示備忘錄相關的顏色點
                                    if !getRelatedMemos(for: course).isEmpty {
                                        HStack(spacing: 2) {
                                            ForEach(getRelatedMemos(for: course).prefix(3), id: \.id) { memo in
                                                Circle()
                                                    .fill(memo.tagType.color)
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
        .id(memoManager.memos.map { $0.id }.joined())
    }
    
    // 取得與課程相關的備忘錄
    func getRelatedMemos(for course: Course) -> [Memo] {
        return memoManager.memos.filter { memo in
            memo.courseLink == course.id && memo.status != .done
        }
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
    
    var body: some View {
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
                courseData.deleteCourse(selectedCourse)
                showingSheet = false
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
}

struct LunchButtonView: View {
    var body: some View {
        NavigationLink {
            LunchView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .imageScale(.medium)
                Text("午餐時間").font(.subheadline.weight(.semibold))
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
                Text("晚餐時間").font(.subheadline.weight(.semibold))
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
                Text("新增").font(.caption2)
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
    let course: Course
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // 標題
            HStack(alignment: .firstTextBaseline) {
                Text(course.name.isEmpty ? "未命名課程" : course.name)
                    .font(.title3.bold())
                    .lineLimit(2)
                Spacer()
            }

            // 資訊卡
            VStack(spacing: 10) {
                infoRow(icon: "person.fill", title: "教授",  value: course.teacher.isEmpty ? "—" : "\(course.teacher) 教授")
                infoRow(icon: "calendar",   title: "時間",  value: "\(course.day), \(course.startTime.rawValue)")
                infoRow(icon: "mappin.and.ellipse", title: "地點",  value: course.location.isEmpty ? "—" : course.location)
                infoRow(icon: course.isNotification ? "bell.fill" : "bell.slash.fill",
                        title: "通知", value: course.isNotification ? "開啟" : "關閉")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            
            // 相關任務列表
            let relatedMemos = getRelatedMemos()
            if !relatedMemos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checklist")
                            .font(.headline)
                        Text("相關任務")
                            .font(.headline)
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(relatedMemos) { memo in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: memo.status.icon)
                                    .font(.caption)
                                    .foregroundStyle(memo.status.color)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(memo.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    
                                    HStack(spacing: 8) {
                                        Label(memo.tagType.rawValue, systemImage: memo.tagType.icon)
                                            .font(.caption2)
                                            .foregroundStyle(memo.tagType.color)
                                        
                                        if let desc = memo.dueDateDescription {
                                            Text("• \(desc)")
                                                .font(.caption2)
                                                .foregroundStyle(memo.isOverdue ? .red : .secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(.tertiarySystemBackground))
                            )
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.quaternary)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .padding(.top, 16)
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
    
    // 取得與課程相關的備忘錄
    func getRelatedMemos() -> [Memo] {
        return memoManager.memos.filter { memo in
            memo.courseLink == course.id && memo.status != .done
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
