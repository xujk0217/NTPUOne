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
    var body: some View {
        Form {
            if academic.uid.isEmpty {
                Section { Text("請先在「我的」登入 Google 帳號，再連結學校資料。") }
            } else {
                Section {
                    Text("連結後，App 開啟時更新作業；課表來源每 30 天檢查一次，也可隨時手動更新。")
                    Text("學校帳密與 token 只存這台裝置的 Keychain，不上傳 Firebase，也不交給 Google。已匯入的課程與待辦會沿用 App 原有的私人 iCloud 同步。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("學生資訊系統") {
                    Label(academic.schoolLinked ? "已連結" : "尚未連結", systemImage: academic.schoolLinked ? "checkmark.shield" : "person.badge.key")
                    TextField("新版校務帳號", text: $schoolUsername).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username)
                    SecureField("新版校務密碼", text: $schoolPassword).textContentType(.password)
                    Button("驗證並在本機保存校務登入資料") {
                        let username = schoolUsername, password = schoolPassword
                        schoolPassword = ""
                        Task { await academic.connectSchool(username: username, password: password) }
                    }.disabled(academic.busy || schoolUsername.isEmpty || schoolPassword.isEmpty)
                    Text("送往 my.ntpu.edu.tw；校方登入橋接目前限 cof.ntpu.edu.tw／ohs01.ntpu.edu.tw。只讀取已核准選課、成績、排名與畢業學分，不執行加退選。其他目的地會停止連線。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Moodle 數位學苑") {
                    Label(academic.moodleLinked ? "已連結" : "尚未連結", systemImage: academic.moodleLinked ? "checkmark.shield" : "person.badge.key")
                    TextField("Moodle 帳號", text: $moodleUsername).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username)
                    SecureField("Moodle 密碼", text: $moodlePassword).textContentType(.password)
                    Button("連結 Moodle 並將作業同步至待辦") {
                        let username = moodleUsername, password = moodlePassword
                        moodlePassword = ""
                        Task { await academic.connectMoodle(username: username, password: password) }
                    }.disabled(academic.busy || moodleUsername.isEmpty || moodlePassword.isEmpty)
                    Text("這組帳密只送往 lms3.ntpu.edu.tw，驗證後只保存 token。請先完成校務連結，以正式課號核對本學期作業。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                AcademicStatusSection()
                if academic.schoolLinked {
                    Section("本人成績與畢業門檻") {
                        ForEach(SchoolReportKind.allCases) { kind in
                            NavigationLink(kind.title) { AcademicSchoolReportView(kind: kind) }
                        }
                    }
                }
                if academic.schoolLinked {
                    AcademicCoursePreviewSection()
                }
                if academic.moodleLinked {
                    AcademicCompletionSection()
                    Section("課程公告與教材") {
                        ForEach(academic.cache.moodleCourses ?? []) { course in
                            NavigationLink(course.fullname) { AcademicCourseContentView(course: course) }
                        }
                    }
                    Section("Moodle 作業") {
                        ForEach(academic.cache.tasks) { task in
                            NavigationLink { AcademicTaskView(task: task) } label: {
                                VStack(alignment: .leading) {
                                    Text(task.title)
                                    Text(task.courseName).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if academic.schoolLinked || academic.moodleLinked {
                    Section {
                        Button("解除學校連結", role: .destructive) { confirmUnlink = true }.disabled(academic.busy)
                    } footer: { Text("解除本機連結會停止同步並移除本機憑證，保留已匯入課表及待辦。") }
                }
            }
        }
        .navigationTitle("學校帳號與同步")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        .confirmationDialog("解除這台裝置的學校連結？", isPresented: $confirmUnlink, titleVisibility: .visible) {
            Button("解除連結", role: .destructive) { academic.unlink() }
        }
    }
}

struct AcademicCourseContentView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    let course: MoodleCourse
    @State private var sections: [MoodleAPI.ContentSection] = []
    @State private var announcements: [MoodleAPI.Announcement] = []
    @State private var grades: [MoodleAPI.Grade] = []
    @State private var errorMessage: String?
    @State private var loading = false
    @State private var didLoadGrades = false
    private func text(_ html: String) -> String { (try? SwiftSoup.parseBodyFragment(html).text()) ?? "" }
    private func resourceURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme == "https", url.host == "lms3.ntpu.edu.tw",
              url.user == nil, url.password == nil, url.port == nil, url.path.hasPrefix("/mod/"),
              url.path.hasSuffix("/view.php"),
              URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { ["token", "wstoken"].contains($0.name.lowercased()) }) != true else { return nil }
        return url
    }
    var body: some View {
        List {
            Section {
                MoodleInAppLink(title: "在 App 內查看完整 Moodle 課程", url: URL(string: "https://lms3.ntpu.edu.tw/course/view.php?id=\(course.id)")!)
            }
            if loading { ProgressView("正在讀取課程內容…") }
            if let errorMessage { Text(errorMessage).foregroundStyle(.secondary) }
            Section("公告 · 最新 10 則／公告區") {
                if announcements.isEmpty && !loading { Text("目前沒有可顯示的公告。") }
                ForEach(announcements) { announcement in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(announcement.name).font(.headline)
                        Text(text(announcement.message)).font(.subheadline)
                        if announcement.discussion > 0 {
                            MoodleInAppLink(title: "查看公告與附件", url: URL(string: "https://lms3.ntpu.edu.tw/mod/forum/discuss.php?d=\(announcement.discussion)")!)
                        }
                    }
                }
            }
            ForEach(sections) { section in
                Section(section.name) {
                    ForEach(section.modules) { module in
                        VStack(alignment: .leading, spacing: 4) {
                            if let url = resourceURL(module.url) {
                                MoodleInAppLink(title: module.name, url: url)
                            } else { Text(module.name) }
                            if let files = module.contents, !files.isEmpty {
                                Text(files.map(\.filename).joined(separator: "、")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section {
                Button("讀取我在這門課可查看的成績") {
                    Task {
                        loading = true; errorMessage = nil
                        defer { loading = false }
                        do { grades = try await academic.courseGrades(course); didLoadGrades = true }
                        catch { grades = []; errorMessage = "目前無法讀取本人成績，可能尚未公布或沒有權限。" }
                    }
                }.disabled(loading)
                if didLoadGrades && grades.isEmpty { Text("目前沒有可顯示的成績項目。") }
                ForEach(grades) { grade in
                    LabeledContent(grade.itemname?.isEmpty == false ? grade.itemname! : "課程總計",
                                   value: grade.gradeformatted ?? "尚未公布")
                        .privacySensitive()
                }
            } header: { Text("本人成績") }
              footer: { Text("只讀取校方允許本人查看的 Moodle 成績，暫存於此頁記憶體；不寫入 Firebase、待辦、Widget 或 iCloud。教材連結在 Moodle 開啟，可能需要瀏覽器登入。") }
        }
        .navigationTitle("課程內容")
        .task(id: academic.sourceScope) {
            sections = []; announcements = []; grades = []; didLoadGrades = false
            loading = true
            defer { loading = false }
            do { (sections, announcements) = try await academic.courseContent(course) }
            catch { errorMessage = "目前無法讀取課程內容，請確認學校連結並稍後重新整理。" }
        }
        .refreshable {
            do { (sections, announcements) = try await academic.courseContent(course); errorMessage = nil }
            catch { errorMessage = "更新失敗，保留本次已載入的內容。" }
        }
        .onDisappear { grades = []; didLoadGrades = false }
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

struct AcademicCompletionSection: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    @State private var selection: AcademicRemoteTask?
    var body: some View {
        if !academic.completionCandidates.isEmpty {
            Section("Moodle 已繳交") {
                ForEach(academic.completionCandidates) { task in
                    Button { selection = task } label: { Label(task.title, systemImage: "checkmark.circle") }
                }
            }
            .confirmationDialog("Moodle 顯示已繳交，要將這筆待辦標記完成嗎？", isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } }), titleVisibility: .visible) {
                if let task = selection {
                    Button("標記完成") { academic.acknowledge(task, complete: true); selection = nil }
                    Button("保留未完成，本次不再提醒") { academic.acknowledge(task, complete: false); selection = nil }
                }
                Button("取消", role: .cancel) { selection = nil }
            }
        }
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
                if task.isTeam == true { Text("這是團體作業；來源狀態不代表已確認本人完成，App 不會自動提出完成建議。")
                    .font(.caption).foregroundStyle(.secondary) }
                MoodleInAppLink(title: "在 App 內查看 Moodle 作業", url: task.url)
            } header: { Text("Moodle 來源") }
              footer: { Text("來源說明與你的私人筆記分開保存。已評分或逾期不代表已繳交；未驗證的團體狀態不會自動建議完成。") }
        }.navigationTitle("作業來源")
    }
}

struct AcademicHomeSection: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    var body: some View {
        if !academic.uid.isEmpty {
            Section {
                NavigationLink { AcademicConnectionView() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("學校帳號與同步", systemImage: "graduationcap")
                        if academic.busy { Text("正在更新…").font(.caption).foregroundStyle(.secondary) }
                        else if let date = academic.cache.moodleCheckedAt {
                            Text("作業上次更新 \(date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        } else { Text("連結校務與 Moodle，整合作業及課表").font(.caption).foregroundStyle(.secondary) }
                        if let message = academic.message { Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                    }
                }
                if academic.schoolLinked {
                    ForEach(SchoolReportKind.allCases) { kind in
                        NavigationLink { AcademicSchoolReportView(kind: kind) } label: {
                            Label(kind.title, systemImage: kind == .graduation ? "checklist" : "chart.bar")
                        }
                    }
                }
            }
            AcademicCompletionSection()
        }
    }
}

struct AcademicSchoolReportView: View {
    @EnvironmentObject private var academic: AcademicSyncStore
    let kind: SchoolReportKind
    private var report: SchoolReport? { academic.cache.reports?.first { $0.kind == kind } }
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                if let report { Text("校務資料更新：\(report.checkedAt.formatted())").font(.caption) }
                if let error = academic.reportErrors[kind] { Text(error).font(.caption).foregroundStyle(.orange) }
                if kind == .graduation {
                    Text("依校務系統的學分歸類及門檻提供預覽；正式畢業資格仍以學校審查為準。未自行假設或換算通識、跨域及其他門檻。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("顯示校方公布的本人成績與排名；未公布的項目不推算，未提供的 GPA 不自行換算。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("重新整理\(kind.title)") { Task { await academic.refreshReport(kind) } }.disabled(academic.busy || !academic.schoolLinked)
                if academic.busy { ProgressView() }
            }.frame(maxWidth: .infinity, alignment: .leading).padding()
            if let report {
                StaticAcademicReport(html: report.html).id(academic.uid + report.id + report.checkedAt.description)
                    .privacySensitive()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text").font(.largeTitle)
                    Text("尚未取得校務報表").font(.headline)
                    Text("請先連結學生資訊系統，再重新整理；資料格式尚未核對時會保留空白。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.navigationTitle(kind.title)
    }
}

/// Already sanitised, static local HTML only: no JavaScript, remote loads, forms or navigation.
struct StaticAcademicReport: UIViewRepresentable {
    let html: String
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.loadHTMLString(html, baseURL: nil)
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
        }
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
