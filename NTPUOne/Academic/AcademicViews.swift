import SwiftUI
import SwiftSoup
import WebKit
import QuickLook

struct AcademicConnectionView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    @Environment(\.dismiss) private var dismiss
    @State private var schoolUsername = ""
    @State private var schoolPassword = ""
    @State private var moodleUsername = ""
    @State private var moodlePassword = ""
    @State private var confirmUnlink = false
    @State private var loggingIn: String?
    @State private var editingSchool = false
    @State private var editingMoodle = false
    var body: some View {
        Form {
            if academic.uid.isEmpty {
                Section { Text("請先在「我的」登入 Google 帳號，再連結學校資料。") }
            } else {
                Section {
                    Text("連結學校帳號，讓課表與作業保持更新。")
                    DisclosureGroup("登入資料與隱私") {
                        Text("登入資料只保存在這台裝置的 Keychain；已匯入的課程與備忘錄沿用私人 iCloud 同步。")
                        Text("校務登入送往 my.ntpu.edu.tw，官方橋接限 cof.ntpu.edu.tw／ohs01.ntpu.edu.tw；Moodle 帳密只送往 lms3.ntpu.edu.tw，驗證後只保存 token。")
                    }.font(.caption).foregroundStyle(.secondary)
                }
                Section("學生資訊系統") {
                    Label(academic.schoolLinked ? "已連結" : "尚未連結", systemImage: academic.schoolLinked ? "checkmark.shield" : "person.badge.key")
                    if academic.schoolLinked && !editingSchool {
                        Button("重新登入") { editingSchool = true }
                    } else {
                    TextField("新版校務帳號", text: $schoolUsername).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username).disabled(academic.busy || loggingIn != nil)
                    SecureField("新版校務密碼", text: $schoolPassword).textContentType(.password).disabled(academic.busy || loggingIn != nil)
                    Button {
                        loggingIn = "school"
                        let username = schoolUsername, password = schoolPassword
                        Task {
                            if await academic.connectSchool(username: username, password: password) { schoolPassword = ""; editingSchool = false }
                            loggingIn = nil
                        }
                    } label: {
                        HStack {
                            if loggingIn == "school" { ProgressView() }
                            Text(loggingIn == "school" ? "正在登入校務系統…" : "登入校務系統")
                        }
                    }.disabled(academic.busy || loggingIn != nil || schoolUsername.isEmpty || schoolPassword.isEmpty)
                    }
                    Text("使用新版學生資訊系統帳號。只讀取個人資料，不會執行選課操作。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Moodle 數位學苑") {
                    Label(academic.moodleLinked ? "已連結" : "尚未連結", systemImage: academic.moodleLinked ? "checkmark.shield" : "person.badge.key")
                    if academic.moodleLinked && !editingMoodle {
                        Button("重新登入") { editingMoodle = true }
                    } else {
                    TextField("Moodle 帳號", text: $moodleUsername).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username).disabled(academic.busy || loggingIn != nil)
                    SecureField("Moodle 密碼", text: $moodlePassword).textContentType(.password).disabled(academic.busy || loggingIn != nil)
                    Button {
                        loggingIn = "moodle"
                        let username = moodleUsername, password = moodlePassword
                        Task {
                            if await academic.connectMoodle(username: username, password: password) { moodlePassword = ""; editingMoodle = false }
                            loggingIn = nil
                        }
                    } label: {
                        HStack {
                            if loggingIn == "moodle" { ProgressView() }
                            Text(loggingIn == "moodle" ? "正在登入 Moodle…" : "登入 Moodle")
                        }
                    }.disabled(academic.busy || loggingIn != nil || moodleUsername.isEmpty || moodlePassword.isEmpty)
                    }
                    Text("登入後將本學期作業加入備忘錄，保留你修改過的內容；請先完成校務登入以核對課號。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                AcademicStatusSection()

            }
        }
        .navigationTitle("學校帳號與同步")
        .onDisappear { schoolPassword = ""; moodlePassword = "" }
        .onChange(of: academic.uid) { _ in
            schoolUsername = ""; schoolPassword = ""; moodleUsername = ""; moodlePassword = ""
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            ToolbarItem(placement: .navigationBarLeading) {
                if academic.schoolLinked || academic.moodleLinked {
                    Menu { Button("解除學校連結", role: .destructive) { confirmUnlink = true } }
                    label: { Image(systemName: "ellipsis.circle").accessibilityLabel("帳號選項") }
                    .disabled(academic.busy || loggingIn != nil)
                }
            }
        }
        .confirmationDialog("解除這台裝置的學校連結？", isPresented: $confirmUnlink, titleVisibility: .visible) {
            Button("解除連結", role: .destructive) { academic.unlink() }
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
            } footer: { Text("只列出已核對的本學期本人課程。同一課程的其他節次也會使用此配對，並重新連結未手動改過的作業。") }
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
                } footer: { Text("受保護檔案可在 App 內開啟與預覽；首次可能需登入 Moodle 網頁。") }
            }.refreshable { await load(force: true) }
        }
        .navigationTitle("Moodle · \(tab.title)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: academic.sourceScope + ":" + tab.rawValue) {
            if loadedScope != academic.sourceScope {
                loadedScope = academic.sourceScope
                sections = []; announcements = []; grades = []; didLoadContent = false; didLoadGrades = false
            }
            await load()
        }
        .onDisappear { requestID = UUID(); grades = []; didLoadGrades = false }
    }
    @ViewBuilder private var announcementSections: some View {
        Section("最新公告 · 每個公告區最多 10 則") {
            if didLoadContent && announcements.isEmpty { Text("目前沒有公告。") }
            ForEach(announcements) { announcement in
                VStack(alignment: .leading, spacing: 8) {
                    Text(announcement.name).font(.headline)
                    Text(text(announcement.message)).font(.subheadline)
                    if let attachments = announcement.attachments, !attachments.isEmpty {
                        Text(attachments.map(\.filename).joined(separator: "、")).font(.caption).foregroundStyle(.secondary)
                    }
                    MoodleInAppLink(title: "查看完整公告與附件", url: URL(string: "https://lms3.ntpu.edu.tw/mod/forum/discuss.php?d=\(announcement.discussion)")!)
                }.padding(.vertical, 3)
            }
        }
    }
    @ViewBuilder private var materialSections: some View {
        if didLoadContent && sections.isEmpty { Section { Text("目前沒有可讀取的教材。") } }
        ForEach(sections) { section in
            Section(section.name.isEmpty ? "課程教材" : section.name) {
                if let summary = section.summary, !text(summary).isEmpty { Text(text(summary)).font(.subheadline) }
                ForEach(section.modules) { module in
                    VStack(alignment: .leading, spacing: 5) {
                        if let url = resourceURL(module.url) { MoodleInAppLink(title: module.name, url: url) }
                        else { Text(module.name).font(.subheadline.weight(.medium)) }
                        if let description = module.description, !text(description).isEmpty { Text(text(description)).font(.caption).foregroundStyle(.secondary) }
                        if let files = module.contents, !files.isEmpty {
                            Text(files.map(\.filename).joined(separator: "、")).font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 3)
                }
            }
        }
    }
    @ViewBuilder private var assignmentSections: some View {
        Section {
            if let date = academic.cache.moodleCheckedAt { Text("更新：\(date.formatted())").font(.caption).foregroundStyle(.secondary) }
            let tasks = academic.courseTasks(course)
            if tasks.isEmpty { Text("目前沒有已同步的作業，可下拉重新整理。") }
            ForEach(tasks) { task in
                NavigationLink { AcademicTaskView(task: task) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title).font(.subheadline.weight(.medium))
                        if let due = task.due { Text("截止：\(due.formatted())").font(.caption).foregroundStyle(.secondary) }
                        Label(task.sourceMissing == true ? "來源待確認" : (["submitted": "已繳交", "draft": "草稿", "new": "未繳交", "reopened": "重新開放"][task.status] ?? "狀態待確認"),
                              systemImage: task.reliableSubmitted ? "checkmark.circle.fill" : "clock")
                            .font(.caption).foregroundStyle(task.reliableSubmitted ? .green : .secondary)
                    }
                }
            }
        } header: { Text("作業與繳交狀態") }
    }
    @ViewBuilder private var gradeSections: some View {
        Section {
            if didLoadGrades && grades.isEmpty { Text("目前沒有已公布且允許本人查看的成績。") }
            ForEach(grades) { grade in
                VStack(alignment: .leading, spacing: 7) {
                    LabeledContent(grade.itemname?.isEmpty == false ? text(grade.itemname!) : "課程總計",
                                   value: text(grade.gradeformatted ?? "尚未公布"))
                    if let percentage = grade.percentageformatted, !percentage.isEmpty {
                        Text("百分比：\(text(percentage))").font(.caption).foregroundStyle(.secondary)
                    }
                    if let feedback = grade.feedback, !text(feedback).isEmpty {
                        DisclosureGroup("教師回饋") { Text(text(feedback)).font(.subheadline) }
                    }
                }.privacySensitive()
            }
        } header: { Text("本人成績") }
          footer: { Text("只讀取校方允許本人查看的成績，暫存於此頁記憶體；尚未公布的分數不自行推算。") }
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
            if let date = academic.cache.schoolCheckedAt { LabeledContent("課表來源更新", value: date.formatted(date: .abbreviated, time: .shortened)) }
            if let message = academic.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            Button("立即重新整理") { Task { await academic.refresh(force: true) } }
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
            Text("只套用可辨識且沒有衝突的時段。保留現有課程 ID、提醒及私人修改，不自動刪除來源已移除的舊課程。")
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
                Toggle("截止前提醒", isOn: $enabled)
                Stepper("截止前 \(days) 天", value: $days, in: 1...30).disabled(!enabled)
                Button("儲存提醒設定") {
                    saved = academic.saveReminderPreferences(days: days, enabled: enabled)
                }.disabled(academic.busy || academic.uid.isEmpty)
                if saved { Label("已儲存", systemImage: "checkmark.circle").foregroundStyle(.green) }
            } header: { Text("Moodle 作業預設提醒") }
              footer: { Text("於截止前指定天數的同一時間提醒。設定套用至新作業及既有未手動修改的預設提醒；單筆自訂、停用或刪除的提醒會保留你的設定。已完成作業不發送提醒。") }
            Section {
                Text("已繳交的個人作業會自動標記完成；未繳交、草稿或重新開放則維持或恢復未完成。")
                Text("團體作業或無法確認的狀態保留原有標記，暫不自行推論。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("立即同步作業") { Task { await academic.refresh(force: true) } }
                    .disabled(academic.busy || !academic.moodleLinked)
                if academic.busy { ProgressView("正在同步…") }
                if let message = academic.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            } header: { Text("自動同步完成狀態") }
        }
        .navigationTitle("Moodle 作業設定")
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
                    Label("來源此次未回傳，保留上次內容；請在 Moodle 確認。", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                if !task.description.isEmpty { Text(task.description) }
                if let due = task.due { LabeledContent("來源截止時間", value: due.formatted()) }
                LabeledContent("來源狀態", value: ["new": "尚未提交", "draft": "草稿", "submitted": "已繳交", "reopened": "重新開放" ][task.status] ?? "無法判定")
                if task.isTeam == true { Text("這是團體作業；來源狀態不代表已確認本人完成，App 不會自行改變完成標記。")
                    .font(.caption).foregroundStyle(.secondary) }
                MoodleInAppLink(title: "在 App 內查看 Moodle 作業", url: task.url)
            } header: { Text("Moodle 來源") }
              footer: { Text("來源說明與你的私人筆記分開保存。個人作業依繳交狀態同步完成標記；已評分或逾期不代表已繳交。") }
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
    let kind: SchoolReportKind
    private var report: SchoolReport? { academic.cache.reports?.first { $0.kind == kind && $0.isNative } }
    var body: some View {
        List {
            Section {
                if !academic.schoolLinked {
                    NavigationLink("登入學校帳號以更新資料") { AcademicConnectionView() }
                }
                if let report { Text("更新：\(report.checkedAt.formatted())").font(.caption).foregroundStyle(.secondary) }
                if let error = academic.reportErrors[kind] {
                    Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
                if academic.busy { ProgressView("正在更新學校資料…") }
                Button("重新整理") { Task { await academic.refreshReport(kind) } }
                    .disabled(academic.busy || !academic.schoolLinked)
            } footer: {
                Text(kind == .graduation ? "門檻與學分分類依校方資料顯示，正式畢業資格以學校審查為準。" : "成績與排名依校方公布資料顯示；尚未公布的數值不自行推算。")
            }
            if let sections = report?.sections {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.fields) { field in
                            LabeledContent(field.label, value: field.value.isEmpty ? "尚未公布" : field.value)
                        }
                        ForEach(Array(section.notes.enumerated()), id: \.offset) { _, note in
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                        if kind == .graduation && !section.subjects.isEmpty {
                            DisclosureGroup("課程明細（\(section.subjects.count)）") {
                                ForEach(section.subjects) { subject in AcademicReportSubjectRow(subject: subject) }
                            }
                        } else {
                            ForEach(section.subjects) { subject in AcademicReportSubjectRow(subject: subject) }
                        }
                    } header: { Text(section.title) }
                }
            } else if !academic.busy {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("尚無可顯示的資料", systemImage: "doc.text")
                        Text("請登入學校帳號並重新整理。暫時無法更新時，會保留上次成功的資料。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .privacySensitive()
        .navigationTitle(kind == .graduation ? kind.title : "成績與排名")
        .task(id: academic.uid + ":" + kind.rawValue) { await academic.prepareReport(kind) }
    }
}

private struct AcademicReportSubjectRow: View {
    let subject: AcademicReportSubject
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(subject.title).font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                if let grade = subject.grade {
                    Text(grade.isEmpty ? "尚未公布" : grade).font(.headline).monospacedDigit()
                }
            }
            HStack(spacing: 12) {
                if let category = subject.category, !category.isEmpty { Text(category) }
                if let credits = subject.credits, !credits.isEmpty { Text("\(credits) 學分") }
            }.font(.caption).foregroundStyle(.secondary)
            ForEach(Array(subject.details.enumerated()), id: \.offset) { _, detail in
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 3)
    }
}

struct MoodleInAppLink: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    let title: String
    let url: URL
    @State private var presented = false
    @State private var preview: MoodlePreviewFile?
    var body: some View {
        Button { presented = true } label: { Label(title, systemImage: "doc.text.magnifyingglass") }
            .sheet(isPresented: $presented) {
                NavigationStack {
                    VStack(spacing: 0) {
                        Text("此頁直接由 Moodle 提供。首次查看受保護教材可能需在此登入；此瀏覽工作階段只保留至 App 關閉，學校 token 不會加入網址。")
                            .font(.caption).foregroundStyle(.secondary).padding()
                        MoodleWebsite(url: url, dataStore: academic.moodleWebDataStore) { preview = MoodlePreviewFile(url: $0) }.id(academic.sourceScope)
                    }
                    .navigationTitle("Moodle")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { presented = false } } }
                    .sheet(item: $preview) { file in
                        NavigationStack {
                            AcademicFilePreview(url: file.url)
                                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { preview = nil } } }
                        }.onDisappear { try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent()) }
                    }
                }
            }
            .onChange(of: academic.sourceScope) { _ in presented = false }
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
