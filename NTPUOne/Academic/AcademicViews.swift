import SwiftUI
import SwiftSoup
import WebKit
import QuickLook

/// Matches the Google welcome prompt; the actual account form opens only on request.
struct AcademicConnectionPromptView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    @Environment(\.dismiss) private var dismiss
    @State private var connecting = false
    var body: some View {
        Group {
            if connecting { AcademicConnectionView() }
            else {
                VStack(spacing: 22) {
                    Text("連結學校服務").font(.largeTitle.bold()).padding(.top, 24)
                    VStack(spacing: 20) {
                        Spacer(minLength: 10)
                        Image(systemName: "graduationcap.fill").font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(.blue).frame(width: 94, height: 94)
                            .background(Color.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 24))
                        Text("課程、作業與成績，一起掌握").font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                        Text("輸入一次學校帳號，連結學生資訊系統與 Moodle。之後也能用已儲存的帳號登入 NTPU AI。")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(3)
                        Text("帳密只保存在這台手機，不會更改校方密碼。")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer(minLength: 10)
                    }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.blue.opacity(0.18)))
                    Button { connecting = true } label: {
                        Label(academic.schoolLinked || academic.moodleLinked ? "確認學校連結" : "連結學校帳號", systemImage: "person.badge.key")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                    }
                    Button("稍後再說") { dismiss() }.font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }.padding(.horizontal, 20).padding(.bottom, 24).background(Color(.systemGroupedBackground))
            }
        }
    }
}

struct AcademicConnectionView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var editing = false
    @State private var confirmUnlink = false
    @State private var loggingIn = false
    @State private var loginStatus: String?

    var body: some View {
        Form {
            if academic.uid.isEmpty {
                Section { Text("請先在「我的」登入 Google 帳號，再連結學校資料。") }
            } else {
                Section("學校帳號") {
                    if !editing && (academic.schoolLinked || academic.moodleLinked) {
                        if let saved = academic.savedSchoolUsername() { LabeledContent("帳號", value: saved) }
                        Button("更新本機登入資料") { editing = true; loginStatus = nil }
                    } else {
                        TextField("學校帳號", text: $username)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username).disabled(loggingIn || academic.busy)
                        SecureField("學校密碼", text: $password).textContentType(.password).disabled(loggingIn || academic.busy)
                        Button {
                            let user = username.trimmingCharacters(in: .whitespacesAndNewlines), secret = password
                            loggingIn = true; loginStatus = "正在登入學生資訊系統…"
                            Task {
                                let schoolOK = await academic.connectSchool(username: user, password: secret)
                                let schoolMessage = academic.message
                                loginStatus = "正在連結 Moodle…"
                                let moodleOK = await academic.connectMoodle(username: user, password: secret)
                                let moodleMessage = academic.message
                                if schoolOK && moodleOK {
                                    loginStatus = "學校帳號已驗證。同步狀態請見下方。"; password = ""; editing = false
                                } else {
                                    loginStatus = [schoolOK ? nil : "校務：\(schoolMessage ?? "登入未完成")", moodleOK ? nil : "Moodle：\(moodleMessage ?? "登入未完成")"].compactMap { $0 }.joined(separator: "\n")
                                }
                                loggingIn = false
                            }
                        } label: {
                            HStack { if loggingIn { ProgressView() }; Text(loggingIn ? "正在連結…" : "儲存並連結") }
                        }.disabled(loggingIn || academic.busy || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                        Text("這只更新手機上的登入資料，不會更改校方密碼。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let loginStatus { Text(loginStatus).font(.caption).foregroundStyle(.secondary) }
                }
                Section("連線狀態") {
                    Label(academic.schoolConnectionStatus, systemImage: academic.cache.schoolCheckedAt != nil ? "checkmark.circle.fill" : "clock")
                    Label(academic.moodleConnectionStatus, systemImage: academic.cache.moodleCheckedAt != nil ? "checkmark.circle.fill" : "clock")
                    Text("NTPU AI 可使用手機保存的學校帳號登入；額外驗證依校方頁面完成。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    DisclosureGroup("登入資料與隱私") {
                        Text("帳密僅保存在這台裝置的 Keychain，不會上傳至 Firebase 或 GitHub。Moodle 另外保存登入 token。")
                        Text("登入資料僅傳送至校方服務。NTPU AI 使用官方登入頁及自己的網站登入狀態。")
                    }.font(.caption).foregroundStyle(.secondary)
                }
                AcademicStatusSection()
            }
        }
        .navigationTitle("學校帳號與同步")
        .onAppear { username = academic.savedSchoolUsername() ?? ""; editing = !(academic.schoolLinked || academic.moodleLinked) }
        .onDisappear { password = "" }
        .onChange(of: academic.uid) { _ in username = ""; password = ""; loginStatus = nil; editing = true }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            ToolbarItem(placement: .navigationBarLeading) {
                if academic.schoolLinked || academic.moodleLinked {
                    Menu { Button("解除學校連結", role: .destructive) { confirmUnlink = true } }
                    label: { Image(systemName: "ellipsis.circle").accessibilityLabel("帳號選項") }
                    .disabled(academic.busy || loggingIn)
                }
            }
        }
        .confirmationDialog("解除這台裝置的學校連結？", isPresented: $confirmUnlink, titleVisibility: .visible) {
            Button("解除連結", role: .destructive) { academic.unlink(); username = ""; password = ""; editing = true }
        }
    }
}

enum AcademicCourseTab: String, CaseIterable, Identifiable {
    case announcements, materials, assignments, grades
    var id: String { rawValue }
    var title: String {
        switch self { case .announcements: return "公告"; case .materials: return "教材"; case .assignments: return "作業"; case .grades: return "成績" }
    }
    var icon: String {
        switch self { case .announcements: return "megaphone"; case .materials: return "books.vertical"; case .assignments: return "checklist"; case .grades: return "chart.bar" }
    }
}

struct AcademicCourseMappingView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    @Environment(\.dismiss) private var dismiss
    let courseID: String
    var body: some View {
        List {
            Section {
                Button("使用自動配對") {
                    if academic.selectMoodleCourse(nil, forCourseID: courseID) { dismiss() }
                }
                ForEach(academic.cache.moodleCourses ?? []) { source in
                    Button {
                        if academic.selectMoodleCourse(source, forCourseID: courseID) { dismiss() }
                    } label: {
                        HStack {
                            Text(source.fullname)
                            Spacer()
                            if academic.moodleCourse(forCourseID: courseID)?.id == source.id { Image(systemName: "checkmark") }
                        }
                    }
                }
            } footer: { Text("同一課程的各節次與作業會一併連結。") }
            if academic.cache.moodleCourses?.isEmpty != false {
                Section {
                    Text("尚無已同步的 Moodle 課程，請先完成校務與 Moodle 登入。")
                    Button("重新同步") { Task { await academic.refresh(force: true) } }
                }
            }
            if let message = academic.message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }.disabled(academic.busy)
        .navigationTitle("配對 Moodle 課程")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
    }
}

struct AcademicCourseContentView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    let course: MoodleCourse
    @State private var tab: AcademicCourseTab
    @State private var sections: [MoodleAPI.ContentSection] = []
    @State private var announcements: [MoodleAPI.Announcement] = []
    @State private var expandedAnnouncements: Set<Int> = []
    @State private var grades: [MoodleAPI.Grade] = []
    @State private var errorMessage: String?
    @State private var loading = false
    @State private var didLoadContent = false
    @State private var didLoadGrades = false
    @State private var loadedScope = ""
    @State private var requestID = UUID()
    init(course: MoodleCourse, initialTab: AcademicCourseTab = .announcements) {
        self.course = course; _tab = State(initialValue: initialTab)
    }
    private func text(_ html: String) -> String { (try? SwiftSoup.parseBodyFragment(html).text()) ?? "" }
    private func resourceURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme == "https", url.host == "lms3.ntpu.edu.tw",
              url.user == nil, url.password == nil, url.port == nil, url.path.hasPrefix("/mod/"),
              url.path.hasSuffix("/view.php"),
              URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { ["token", "wstoken"].contains($0.name.lowercased()) }) != true else { return nil }
        return url
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "books.vertical.fill").foregroundStyle(.tint)
                Text(course.fullname).font(.subheadline.weight(.semibold)).lineLimit(2)
                Spacer(minLength: 0)
            }.padding(.horizontal, 16).padding(.top, 12)
            Picker("課程內容", selection: $tab) {
                ForEach(AcademicCourseTab.allCases) { item in Text(item.title).tag(item) }
            }.pickerStyle(.segmented).padding()
            List {
                if loading { ProgressView("正在讀取…") }
                if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.secondary) }
                switch tab {
                case .announcements: announcementSections
                case .materials: materialSections
                case .assignments: assignmentSections
                case .grades: gradeSections
                }
                Section {
                    MoodleInAppLink(title: "查看完整 Moodle 課程", url: URL(string: "https://lms3.ntpu.edu.tw/course/view.php?id=\(course.id)")!)
                }
            }.listStyle(.insetGrouped).refreshable { await load(force: true) }
        }
        .navigationTitle("課程內容")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: academic.sourceScope + ":" + tab.rawValue) {
            if loadedScope != academic.sourceScope {
                loadedScope = academic.sourceScope
                sections = []; announcements = []; grades = []; expandedAnnouncements = []; didLoadContent = false; didLoadGrades = false
            }
            await load()
        }
        .onDisappear { requestID = UUID(); grades = []; didLoadGrades = false }
    }
    @ViewBuilder private var announcementSections: some View {
        Section("最新公告") {
            if didLoadContent && announcements.isEmpty { Text("目前沒有公告。") }
            ForEach(announcements) { announcement in
                VStack(alignment: .leading, spacing: 8) {
                    Text(announcement.name).font(.headline)
                    let message = text(announcement.message)
                    if !message.isEmpty {
                        Text(message).font(.subheadline).lineLimit(expandedAnnouncements.contains(announcement.id) ? nil : 4).textSelection(.enabled)
                        if message.count > 160 {
                            Button(expandedAnnouncements.contains(announcement.id) ? "收合" : "顯示全文") {
                                if expandedAnnouncements.contains(announcement.id) { expandedAnnouncements.remove(announcement.id) }
                                else { expandedAnnouncements.insert(announcement.id) }
                            }.buttonStyle(.borderless).font(.caption.weight(.semibold))
                        }
                    }
                    if let attachments = announcement.attachments, !attachments.isEmpty {
                        ForEach(Array(attachments.enumerated()), id: \.offset) { _, attachment in
                            MoodleNativeFileButton(attachment: attachment, course: course)
                        }
                    }
                    MoodleInAppLink(title: "查看完整公告與附件", url: URL(string: "https://lms3.ntpu.edu.tw/mod/forum/discuss.php?d=\(announcement.discussion)")!)
                }.padding(.vertical, 3)
            }
        }
    }
    @ViewBuilder private var materialSections: some View {
        if didLoadContent && sections.isEmpty { Section { Label("目前沒有可讀取的教材", systemImage: "folder") .foregroundStyle(.secondary) } }
        ForEach(sections) { section in
            Section {
                DisclosureGroup {
                    if let summary = section.summary, !text(summary).isEmpty {
                        Text(text(summary)).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    if section.modules.isEmpty { Text("此單元沒有教材").font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(section.modules) { module in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(module.name, systemImage: "doc.text").font(.subheadline.weight(.semibold))
                            if let description = module.description, !text(description).isEmpty {
                                Text(text(description)).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            ForEach(Array((module.contents ?? []).enumerated()), id: \.offset) { _, attachment in
                                if attachment.type == "content", let content = attachment.content, !text(content).isEmpty {
                                    Text(text(content)).font(.subheadline).textSelection(.enabled)
                                } else if !attachment.filename.isEmpty {
                                    MoodleNativeFileButton(attachment: attachment, course: course)
                                }
                            }
                            if let url = resourceURL(module.url) { MoodleInAppLink(title: "在 Moodle 查看", url: url) }
                        }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
                    }
                } label: {
                    HStack {
                        Label(section.name.isEmpty ? "課程教材" : section.name, systemImage: "folder")
                        Spacer(); Text("\(section.modules.count)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    @ViewBuilder private var assignmentSections: some View {
        Section {
            if let date = academic.cache.moodleCheckedAt { Text("更新：\(date.formatted())").font(.caption).foregroundStyle(.secondary) }
            let tasks = academic.courseTasks(course)
            if tasks.isEmpty { Label("目前沒有已同步的作業", systemImage: "checkmark.circle").foregroundStyle(.secondary) }
            ForEach(tasks.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }) { task in
                NavigationLink { AcademicTaskView(task: task) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title).font(.subheadline.weight(.medium))
                        if let due = task.due { Label("截止 \(due.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar").font(.caption).foregroundStyle(.secondary) }
                        Label(task.sourceMissing == true ? "來源待確認" : (["submitted": "已繳交", "draft": "草稿", "new": "未繳交", "reopened": "重新開放"][task.status] ?? "狀態待確認"),
                              systemImage: task.reliableSubmitted ? "checkmark.circle.fill" : "clock")
                            .font(.caption.weight(.medium)).foregroundStyle(task.reliableSubmitted ? .green : .secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background((task.reliableSubmitted ? Color.green : Color.secondary).opacity(0.09), in: Capsule())
                    }
                }
            }
        } header: { Text("作業與繳交狀態") }
    }
    @ViewBuilder private var gradeSections: some View {
        Section {
            if didLoadGrades && grades.isEmpty { Label("尚無已公布成績", systemImage: "chart.bar").foregroundStyle(.secondary) }
            ForEach(grades) { grade in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(grade.itemname?.isEmpty == false ? text(grade.itemname!) : "課程總計").font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(text(grade.gradeformatted ?? "尚未公布")).font(.subheadline.weight(.semibold)).monospacedDigit().multilineTextAlignment(.trailing)
                    }
                    if let percentage = grade.percentageformatted, !percentage.isEmpty {
                        Text("百分比：\(text(percentage))").font(.caption).foregroundStyle(.secondary)
                    }
                    if let feedback = grade.feedback, !text(feedback).isEmpty {
                        DisclosureGroup("教師回饋") { Text(text(feedback)).font(.subheadline) }
                    }
                }.privacySensitive()
            }
        } header: { Text("本人成績") }
          footer: { Text("僅顯示已公布的本人成績。") }
    }
    @MainActor private func load(force: Bool = false) async {
        let request = UUID(); requestID = request
        errorMessage = nil; loading = true
        defer { if requestID == request { loading = false } }
        do {
            switch tab {
            case .grades:
                if force || !didLoadGrades {
                    let result = try await academic.courseGrades(course)
                    guard requestID == request, !Task.isCancelled else { return }
                    grades = result; didLoadGrades = true
                }
            case .assignments:
                if force { await academic.refresh(force: true) }
                guard requestID == request, !Task.isCancelled else { return }
                errorMessage = academic.message
            case .announcements, .materials:
                if force || !didLoadContent {
                    let result = try await academic.courseContent(course)
                    guard requestID == request, !Task.isCancelled else { return }
                    sections = result.0; announcements = result.1; didLoadContent = true
                }
            }
        } catch {
            if requestID == request && !Task.isCancelled { errorMessage = "暫時無法更新此項內容，請稍後下拉重新整理。" }
        }
    }
}

struct AcademicStatusSection: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    var body: some View {
        Section("學校資料同步") {
            if academic.busy { ProgressView("正在更新學校資料…") }
            if let date = academic.cache.moodleCheckedAt { LabeledContent("作業更新", value: date.formatted(date: .abbreviated, time: .shortened)) }
            if let date = academic.cache.schoolCheckedAt { LabeledContent("課表更新", value: date.formatted(date: .abbreviated, time: .shortened)) }
            if let message = academic.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            Button("更新資料") { Task { await academic.refresh(force: true) } }
                .disabled(academic.busy || !(academic.schoolLinked || academic.moodleLinked))
        }
    }
}

struct AcademicCoursePreviewSection: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    @State private var confirmImport = false
    var body: some View {
        Section {
            ForEach(academic.cache.courses) { course in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(course.code) · \(course.name)").font(.subheadline.weight(.semibold))
                    Text(course.schedule).font(.caption).foregroundStyle(.secondary)
                    if let issue = academic.previewIssue(course) { Label(issue, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
                }
            }
            Button("匯入可用時段至課表") { confirmImport = true }
                .disabled(academic.busy || academic.cache.courses.isEmpty || academic.cache.courses.allSatisfy { academic.previewIssue($0) != nil })
        } header: {
            Text("\(academic.cache.year ?? "") 學年度第 \(academic.cache.term ?? "") 學期 · 匯入預覽")
        } footer: {
            Text("僅匯入無衝突時段，保留你的課程修改與提醒。")
        }
        .confirmationDialog("將預覽中可用的時段加入課表？", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("套用可用時段") { academic.importCourses() }
        }
    }
}

struct AcademicMemoSettingsView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    @State private var days = 3
    @State private var enabled = true
    @State private var saved = false
    var body: some View {
        Form {
            Section {
                Toggle("作業提醒", isOn: $enabled)
                if enabled {
                    Stepper(value: $days, in: 1...30) {
                        HStack {
                            Text("提前天數")
                            Spacer()
                            Text("\(days) 天").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                Button {
                    saved = academic.saveReminderPreferences(days: days, enabled: enabled)
                } label: {
                    Label(saved ? "已儲存" : "儲存", systemImage: saved ? "checkmark" : "bell")
                }.disabled(saved || academic.busy || academic.uid.isEmpty)
            } header: { Text("預設提醒") }
              footer: { Text("已完成作業不提醒；單筆自訂設定優先。") }
            Section {
                Label("繳交後自動完成", systemImage: "checkmark.circle.fill").foregroundStyle(.primary)
                Button { Task { await academic.refresh(force: true) } } label: {
                    HStack {
                        Text("更新作業")
                        Spacer()
                        if academic.busy { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                }.disabled(academic.busy || !academic.moodleLinked)
                if let message = academic.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            } header: { Text("Moodle 同步") }
              footer: { Text("未繳交會恢復未完成，團體作業需手動確認。") }
        }
        .navigationTitle("作業設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { days = academic.reminderLeadDays; enabled = academic.remindersEnabled }
        .onChange(of: days) { _ in saved = false }
        .onChange(of: enabled) { _ in saved = false }
    }
}

struct AcademicTaskView: View {
    let task: AcademicRemoteTask
    var body: some View {
        List {
            Section {
                Text(task.courseName)
                Text(task.title).font(.headline)
                if task.sourceMissing == true {
                    Label("來源暫無資料，保留上次內容。", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                if !task.description.isEmpty { Text(task.description) }
                if let due = task.due { LabeledContent("來源截止時間", value: due.formatted()) }
                LabeledContent("來源狀態", value: ["new": "尚未提交", "draft": "草稿", "submitted": "已繳交", "reopened": "重新開放" ][task.status] ?? "無法判定")
                if task.isTeam == true { Text("團體作業請手動標記完成。")
                    .font(.caption).foregroundStyle(.secondary) }
                MoodleInAppLink(title: "在 App 內查看 Moodle 作業", url: task.url)
            } header: { Text("Moodle 來源") }
              footer: { Text("個人作業依 Moodle 繳交狀態同步。") }
        }.navigationTitle("作業來源")
    }
}

struct AcademicCourseImportView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    var body: some View {
        List {
            if academic.schoolLinked {
                AcademicStatusSection()
                AcademicCoursePreviewSection()
            } else {
                Section { NavigationLink("登入學校帳號") { AcademicConnectionView() } }
            }
        }.navigationTitle("校務課表匯入")
    }
}

struct AcademicGradesView: View {
    @State private var selection: SchoolReportKind = .grades
    var body: some View {
        VStack(spacing: 0) {
            Picker("成績資訊", selection: $selection) {
                Text("學期成績").tag(SchoolReportKind.grades)
                Text("成績排名").tag(SchoolReportKind.rank)
            }.pickerStyle(.segmented).padding()
            AcademicSchoolReportView(kind: selection).id(selection)
        }.navigationTitle("成績與排名")
    }
}

struct AcademicSchoolReportView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let kind: SchoolReportKind
    @State private var selectedSectionID: String?
    private var report: SchoolReport? { academic.cache.reports?.first { $0.kind == kind && $0.isCurrent } }
    private var sections: [AcademicReportSection] { report?.sections ?? [] }
    private var selectedSection: AcademicReportSection? {
        sections.first { $0.id == selectedSectionID } ?? AcademicReportOrdering.latestTerm(sections)
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                reportHeader
                if kind == .graduation {
                    graduationContent
                } else if let section = selectedSection {
                    termPicker
                    AcademicReportCard(section: section, kind: kind)
                }
                if sections.isEmpty && !academic.busy { emptyState }
                if !sections.isEmpty {
                    Text(kind == .graduation ? "正式畢業資格以校方審查為準。" : "依校方公布資料顯示。")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }.padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await academic.refreshReport(kind) }
        .privacySensitive()
        .navigationTitle(kind == .graduation ? kind.title : "成績與排名")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: academic.uid + ":" + kind.rawValue) { await academic.prepareReport(kind) }
    }
    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: kind == .graduation ? "graduationcap.fill" : "chart.bar.xaxis")
                    .font(.title2).foregroundStyle(.indigo)
                    .frame(width: 48, height: 48).background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind == .graduation ? "畢業進度" : (kind == .rank ? "成績排名" : "學期成績")).font(.title2.bold())
                    if let report {
                        Text("更新於 \(report.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button { Task { await academic.refreshReport(kind) } } label: {
                    if academic.busy { ProgressView() }
                    else { Image(systemName: "arrow.clockwise").font(.body.weight(.semibold)) }
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("更新\(kind.title)")
                .disabled(academic.busy || !academic.schoolLinked)
            }
            if !academic.schoolLinked {
                NavigationLink { AcademicConnectionView() } label: {
                    Label("登入學校帳號", systemImage: "person.badge.key")
                }.buttonStyle(.bordered)
            }
            if let error = academic.reportErrors[kind] {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }
    private var termPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AcademicReportOrdering.sorted(sections)) { section in
                        let selected = section.id == selectedSection?.id
                        Button { selectedSectionID = section.id } label: {
                            Text(section.title).font(.subheadline.weight(selected ? .semibold : .regular))
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(selected ? Color.indigo : Color(.secondarySystemGroupedBackground), in: Capsule())
                        }.buttonStyle(.plain)
                            .id(section.id)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }.accessibilityLabel("選擇學期")
            .task(id: selectedSection?.id) {
                await Task.yield()
                if let id = selectedSection?.id { proxy.scrollTo(id, anchor: .trailing) }
            }
        }
    }
    @ViewBuilder private var graduationContent: some View {
        if let total = sections.first(where: { $0.id == "summary_total" }) {
            AcademicGraduationSummaryCard(section: total, prominent: true)
        }
        if let requirements = sections.first(where: { $0.id == "requirements" }) {
            AcademicGraduationRequirementsCard(section: requirements)
        }
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 150), alignment: .top)], spacing: 12) {
            ForEach(sections.filter { ["summary_required", "summary_option", "tag_total", "summary_other", "tag_chinese", "tag_english", "tag_pe", "tag_general", "mini_general"].contains($0.id) }) { section in
                AcademicGraduationSummaryCard(section: section)
            }
        }
        ForEach(sections.filter { ["required", "option", "common", "other"].contains($0.id) }) { section in
            AcademicReportCard(section: section, kind: kind)
        }
    }
    private var needsGraduationRefresh: Bool {
        kind == .graduation && academic.cache.reports?.contains(where: { $0.kind == .graduation && !$0.isCurrent }) == true
    }
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass").font(.largeTitle).foregroundStyle(.secondary)
            Text(academic.schoolLinked ? (needsGraduationRefresh ? "畢業門檻資料需更新" : "尚無資料") : "登入後查看學校資料").font(.headline)
            if academic.schoolLinked { Text("下拉即可更新").font(.subheadline).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity).padding(.vertical, 44)
    }
}

private struct AcademicGraduationRequirementsCard: View {
    let section: AcademicReportSection
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(section.title, systemImage: "checklist").font(.headline)
            ForEach(Array(section.fields.enumerated()), id: \.element.id) { index, field in
                if index > 0 { Divider() }
                HStack(alignment: .top, spacing: 12) {
                    Text(field.label).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    Text(field.value).font(.subheadline.weight(.semibold))
                        .foregroundStyle(field.value == "符合" ? Color.green : (field.value == "不符合" ? Color.red : Color.secondary))
                }
            }
        }.padding(18).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct AcademicGraduationSummaryCard: View {
    let section: AcademicReportSection
    var prominent = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(section.title, systemImage: prominent ? "graduationcap" : "bookmark")
                .font(prominent ? .headline : .subheadline.weight(.semibold))
            ForEach(section.fields) { field in
                VStack(alignment: .leading, spacing: 6) {
                    Text(field.value).font(prominent ? .largeTitle.bold() : .title2.bold())
                        .monospacedDigit().foregroundStyle(.indigo)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = field.detail, !detail.isEmpty {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                    if section.fields.count > 1 {
                        Text(field.label).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(prominent ? 22 : 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: prominent ? 22 : 18))
    }
}

private struct AcademicReportCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let section: AcademicReportSection
    let kind: SchoolReportKind
    private var tint: Color { .indigo }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title).font(.headline)
                Spacer()
                if !section.subjects.isEmpty {
                    Text("\(section.subjects.count) 門課").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !section.fields.isEmpty {
                LazyVGrid(columns: section.fields.count == 1 || dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 130), alignment: .top)], alignment: .leading, spacing: 12) {
                    ForEach(section.fields) { field in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(field.label).font(.caption).foregroundStyle(.secondary)
                            Text(field.value.isEmpty ? "尚未公布" : field.value)
                                .font(.title3.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(tint).fixedSize(horizontal: false, vertical: true)
                            if let detail = field.detail, !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
                        }.frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                            .padding(12).background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            if !section.subjects.isEmpty {
                if kind == .graduation {
                    DisclosureGroup("課程明細") { subjectRows.padding(.top, 10) }.tint(tint)
                } else { subjectRows }
            }
            if !section.notes.isEmpty {
                DisclosureGroup("補充說明") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(section.notes.enumerated()), id: \.offset) { _, note in Text(note) }
                    }.font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }.font(.subheadline).tint(tint)
            }
        }.padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
    private var subjectRows: some View {
        VStack(spacing: 14) {
            ForEach(Array(section.subjects.enumerated()), id: \.element.id) { index, subject in
                if index > 0 { Divider() }
                AcademicReportSubjectRow(subject: subject)
            }
        }
    }
}

private struct AcademicReportSubjectRow: View {
    let subject: AcademicReportSubject
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(subject.title).font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    if let category = subject.category, !category.isEmpty { Text(category) }
                    if let credits = subject.credits, !credits.isEmpty { Text("\(credits) 學分") }
                }.font(.caption).foregroundStyle(.secondary)
                ForEach(Array(subject.details.enumerated()), id: \.offset) { _, detail in
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let grade = subject.grade {
                Text(grade.isEmpty ? "—" : grade).font(.title3.bold()).monospacedDigit()
                    .foregroundStyle(.indigo).padding(10)
                    .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("成績 \(grade.isEmpty ? "尚未公布" : grade)")
            }
        }
    }
}

struct MoodleNativeFileButton: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    let attachment: MoodleAPI.Resource.Attachment
    let course: MoodleCourse
    @State private var preview: MoodlePreviewFile?
    @State private var loading = false
    @State private var error: String?
    @State private var download: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading) {
            Button {
                loading = true; error = nil
                download = Task {
                    defer { loading = false; download = nil }
                    do {
                        let file = try await academic.previewMoodleFile(attachment, course: course)
                        if Task.isCancelled { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
                        else { preview = MoodlePreviewFile(url: file) }
                    } catch { if !Task.isCancelled { self.error = "無法直接開啟，請使用 Moodle 網頁查看。" } }
                }
            } label: {
                HStack { if loading { ProgressView() }; Label(attachment.filename, systemImage: "doc") }
            }.buttonStyle(.borderless).disabled(loading || attachment.fileurl == nil)
            if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
        }
        .sheet(item: $preview) { file in
            NavigationStack { AcademicFilePreview(url: file.url).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { preview = nil } } } }
                .onDisappear { try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent()) }
        }
        .onChange(of: academic.sourceScope) { _ in download?.cancel(); preview = nil }
        .onDisappear { download?.cancel() }
    }
}

struct MoodleInAppLink: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    let title: String
    let url: URL
    @State private var presented = false
    @State private var preview: MoodlePreviewFile?
    @State private var presentationID = UUID()
    var body: some View {
        Button { presentationID = UUID(); presented = true } label: { Label(title, systemImage: "arrow.up.right.square") }
            .buttonStyle(.borderless)
            .sheet(isPresented: $presented, onDismiss: { presentationID = UUID(); preview = nil }) {
                let activePresentation = presentationID
                NavigationStack {
                    VStack(spacing: 0) {
                        Text("首次查看教材可能需登入 Moodle。")
                            .font(.caption).foregroundStyle(.secondary).padding()
                        MoodleWebsite(url: url, dataStore: academic.moodleWebDataStore) { file in
                            if presented && activePresentation == presentationID { preview = MoodlePreviewFile(url: file) }
                            else { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
                        }.id(academic.sourceScope)
                    }
                    .navigationTitle("Moodle")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { presentationID = UUID(); presented = false; preview = nil } } }
                    .sheet(item: $preview) { file in
                        NavigationStack {
                            AcademicFilePreview(url: file.url)
                                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { preview = nil } } }
                        }.onDisappear { try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent()) }
                    }
                }
            }
            .onChange(of: academic.sourceScope) { _ in presentationID = UUID(); presented = false; preview = nil }
    }
}

struct MoodleWebsite: UIViewRepresentable {
    let url: URL
    let dataStore: WKWebsiteDataStore
    var onDownload: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onDownload: onDownload) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        if Coordinator.allowed(url) { view.load(URLRequest(url: url)) }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) { view.stopLoading(); coordinator.cancelDownloads() }
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        var onDownload: (URL) -> Void
        var downloads: [ObjectIdentifier: (WKDownload, URL?)] = [:]
        var closed = false
        init(onDownload: @escaping (URL) -> Void) { self.onDownload = onDownload }
        static func allowed(_ url: URL) -> Bool {
            url.scheme == "https" && url.host == "lms3.ntpu.edu.tw" && url.user == nil && url.password == nil && url.port == nil
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.request.url.map(Self.allowed) == true else { decisionHandler(.cancel); return }
            decisionHandler(action.shouldPerformDownload ? .download : .allow)
        }
        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            guard response.response.url.map(Self.allowed) == true else { decisionHandler(.cancel); return }
            decisionHandler(response.canShowMIMEType ? .allow : .download)
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if action.request.url.map(Self.allowed) == true { webView.load(action.request) }
            return nil
        }
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { attach(download) }
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { attach(download) }
        private func attach(_ download: WKDownload) { downloads[ObjectIdentifier(download)] = (download, nil); download.delegate = self }
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            guard !closed, response.url.map(Self.allowed) == true, response.expectedContentLength <= 100 * 1024 * 1024 else { completionHandler(nil); return }
            do {
                var folder = FileManager.default.temporaryDirectory.appendingPathComponent("AcademicPreview-" + UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
                var values = URLResourceValues(); values.isExcludedFromBackup = true; try folder.setResourceValues(values)
                let name = String(URL(fileURLWithPath: suggestedFilename).lastPathComponent.prefix(120))
                guard !name.isEmpty, name != ".", name != ".." else { throw AcademicError.unsupported }
                let file = folder.appendingPathComponent(name)
                downloads[ObjectIdentifier(download)] = (download, file)
                completionHandler(file)
            } catch { completionHandler(nil) }
        }
        func download(_ download: WKDownload, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
            decisionHandler(request.url.map(Self.allowed) == true ? .allow : .cancel)
        }
        func downloadDidFinish(_ download: WKDownload) {
            guard let entry = downloads.removeValue(forKey: ObjectIdentifier(download)), let file = entry.1 else { return }
            if !closed { onDownload(file) } else { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        }
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            if let file = downloads.removeValue(forKey: ObjectIdentifier(download))?.1 { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        }
        func cancelDownloads() {
            closed = true
            for entry in downloads.values {
                entry.0.cancel { _ in }
                if let file = entry.1 { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
            }
            downloads = [:]
        }
    }
}

struct MoodlePreviewFile: Identifiable { let id = UUID(); let url: URL }
struct AcademicFilePreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController { let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
