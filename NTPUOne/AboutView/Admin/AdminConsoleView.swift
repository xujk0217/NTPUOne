//
//  AdminConsoleView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/9/6.
//

import SwiftUI

struct AdminConsoleView: View {
    @ObservedObject private var features = GlobalFeatureSettings.shared
    var body: some View {
        NavigationStack {
            List {
                Section("全體功能設定") {
                    Toggle("顯示廣告", isOn: Binding(get: { features.adsEnabled }, set: { features.save(key: "adsEnabled", value: $0) }))
                    Toggle("啟用 AI 助理", isOn: Binding(get: { features.aiEnabled }, set: { features.save(key: "aiEnabled", value: $0) }))
                    if features.saving { ProgressView("正在更新") }
                    if let error = features.error { Text(error).font(.caption).foregroundStyle(.red) }
                    Text("設定會套用於支援此功能的新版本；離線裝置會在恢復連線後更新。") .font(.caption).foregroundStyle(.secondary)
                }.disabled(!features.available || features.saving)
                Section("交流區管理") {
                    NavigationLink {
                        CommunityAdminView()
                    } label: {
                        Label("貼文與留言管理", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    NavigationLink {
                        RestaurantCommentsAdminView()
                    } label: {
                        Label("餐廳留言管理", systemImage: "text.bubble")
                    }
                }

                Section("資料管理") {
                    NavigationLink {
                        OrdersAdminTab()
                    } label: {
                        Label("投稿管理", systemImage: "tray.full")
                    }

                    NavigationLink {
                        FoodsAdminTab()
                    } label: {
                        Label("餐廳管理", systemImage: "fork.knife")
                    }
                    NavigationLink {
                        ReportBugAdminView()
                    } label: {
                        Label("問題回報管理", systemImage: "ladybug")
                    }
                    NavigationLink {
                        FeaturesAdminView()
                    } label: {
                        Label("功能回報管理", systemImage: "sparkles")
                    }
                }

                if NextCourseLiveActivityManager.isFeatureAvailable {
                    Section("開發測試") {
                        NavigationLink {
                            AdminLiveActivityTestView()
                        } label: {
                            Label("即時課表測試", systemImage: "timer")
                        }
                    }
                }
            }
            .navigationTitle("管理後台")
        }
    }
}

private struct AdminLiveActivityTestView: View {
    @State private var isRunning = NextCourseLiveActivityManager.shared.isAdminLiveActivityTestRunning

    var body: some View {
        Form {
            Section {
                if isRunning {
                    if let startsAt = NextCourseLiveActivityManager.shared.adminLiveActivityTestStartsAt,
                       let endsAt = NextCourseLiveActivityManager.shared.adminLiveActivityTestEndsAt {
                        LabeledContent("第一堂開始") {
                            Text(startsAt, style: .time)
                        }
                        LabeledContent("預計結束") {
                            Text(endsAt, style: .time)
                        }
                    }

                    Label("測試進行中", systemImage: "record.circle.fill")
                        .foregroundStyle(.orange)

                    Button("停止並恢復真實課表", role: .destructive) {
                        NextCourseLiveActivityManager.shared.stopAdminLiveActivityTest()
                        isRunning = false
                    }
                } else {
                    Button {
                        NextCourseLiveActivityManager.shared.startAdminLiveActivityTest()
                        isRunning = true
                    } label: {
                        Label("開始即時課表測試", systemImage: "play.fill")
                    }
                }
            } header: {
                Text("測試流程")
            } footer: {
                Text("開始後五分鐘出現第一堂測試課程，共五堂；每堂十分鐘、堂間五分鐘。測試不會修改既有課表、通知或 Firebase 資料。若原本關閉即時動態，測試結束後會自動還原。")
            }
        }
        .navigationTitle("即時課表測試")
        .task(id: isRunning) {
            guard isRunning else { return }
            while !Task.isCancelled && isRunning {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                isRunning = NextCourseLiveActivityManager.shared.isAdminLiveActivityTestRunning
            }
        }
        .onAppear {
            isRunning = NextCourseLiveActivityManager.shared.isAdminLiveActivityTestRunning
        }
    }
}

// MARK: - 交流區內容管理（貼文＋回覆）

import FirebaseFirestore
import FirebaseFirestoreSwift

private func adminPreview(_ text: String) -> String {
    text.count > 120 ? String(text.prefix(117)) + "..." : text
}

private func adminDateText(_ date: Date?) -> String {
    guard let date else { return "-" }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/MM/dd HH:mm"
    return formatter.string(from: date)
}

struct AdminCommunityTopic: Identifiable {
    let id: String
    var title: String
    var body: String
    var category: String
    var authorName: String
    var createdAt: Date?
    var replyCount: Int
    var isDeleted: Bool

    static func from(id: String, data: [String: Any]) -> AdminCommunityTopic? {
        guard data["title"] is String, data["body"] is String else { return nil }
        return AdminCommunityTopic(
            id: id,
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? "",
            category: data["category"] as? String ?? "",
            authorName: data["authorName"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            replyCount: data["replyCount"] as? Int ?? 0,
            isDeleted: data["isDeleted"] as? Bool ?? false
        )
    }
}

struct AdminCommunityReply: Identifiable {
    let id: String
    let topicId: String
    var body: String
    var authorName: String
    var createdAt: Date?

    static func from(topicId: String, id: String, data: [String: Any]) -> AdminCommunityReply {
        AdminCommunityReply(
            id: id,
            topicId: topicId,
            body: data["body"] as? String ?? "",
            authorName: data["authorName"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }
}

@MainActor
final class CommunityAdminModel: ObservableObject {
    @Published var lastErrorMessage: String?
    @Published var topics: [AdminCommunityTopic] = []
    @Published var isLoading = false
    @Published var statusMessage: String?

    private let db = Firestore.firestore()

    func loadTopics() {
        isLoading = true
        db.collection("communityTopics")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments { [weak self] snapshot, _ in
                let items = snapshot?.documents.compactMap { document in
                    AdminCommunityTopic.from(id: document.documentID, data: document.data())
                } ?? []
                DispatchQueue.main.async {
                    self?.topics = items
                    self?.isLoading = false
                }
            }
    }

    /// 軟刪除主題（比照使用者刪除流程清空個人欄位）並清理所有 owner 紀錄
    func deleteTopic(_ topic: AdminCommunityTopic, completion: ((Bool) -> Void)? = nil) {
        let topicRef = db.collection("communityTopics").document(topic.id)
        let now = Timestamp(date: Date())
        let deletePayload: [String: Any] = [
            "title": "[已刪除]",
            "body": "此主題已由管理員刪除。",
            "authorName": "",
            "authorDeviceId": "",
            "authorDepartment": "",
            "authorEntryYear": "",
            "authorShowsYear": false,
            "authorShowsBadge": false,
            "authorBadgeLevel": 0,
            "isDeleted": true,
            "deletedAt": now,
            "updatedAt": now
        ]

        func finishOwnerCleanup(_ success: Bool) {
            if success {
                Task { @MainActor in
                    await CommunityImageService.shared.deleteImages(topicID: topic.id)
                }
            }
            cleanupOwnerDocs(group: "topics", matchField: "topicId", equals: topic.id) {
                DispatchQueue.main.async { completion?(success) }
            }
        }

        topicRef.updateData(deletePayload) { error in
            if let error {
                self.lastErrorMessage = error.localizedDescription
                // 軟刪除失敗時改嘗試硬刪除（管理員權限）
                topicRef.delete { deleteError in
                    if let deleteError { self.lastErrorMessage = deleteError.localizedDescription }
                    finishOwnerCleanup(deleteError == nil)
                }
                return
            }
            finishOwnerCleanup(true)
        }
    }

    func updateTopic(_ topic: AdminCommunityTopic, title: String, body: String, completion: ((Bool) -> Void)? = nil) {
        let now = Timestamp(date: Date())
        let topicRef = db.collection("communityTopics").document(topic.id)
        let batch = db.batch()
        batch.updateData(["title": title, "body": body, "updatedAt": now], forDocument: topicRef)
        commitOwnerUpdates(batch: batch, group: "topics", matchField: "topicId", equals: topic.id, fields: [
            "title": title,
            "body": body,
            "bodyPreview": adminPreview(body),
            "updatedAt": now
        ]) { [weak self] error in
            if let error { self?.lastErrorMessage = error.localizedDescription }
            DispatchQueue.main.async { completion?(error == nil) }
        }
    }

    func loadReplies(topicId: String, completion: @escaping ([AdminCommunityReply]) -> Void) {
        db.collection("communityTopics").document(topicId).collection("replies")
            .order(by: "createdAt", descending: false)
            .limit(to: 300)
            .getDocuments { snapshot, _ in
                let items = snapshot?.documents.map {
                    AdminCommunityReply.from(topicId: topicId, id: $0.documentID, data: $0.data())
                } ?? []
                DispatchQueue.main.async { completion(items) }
            }
    }

    func deleteReply(_ reply: AdminCommunityReply, completion: ((Bool) -> Void)? = nil) {
        let topicRef = db.collection("communityTopics").document(reply.topicId)
        let group = DispatchGroup()
        let lock = NSLock()
        var currentCount = 0
        var ownerRefs: [DocumentReference] = []

        group.enter()
        topicRef.getDocument { snapshot, _ in
            currentCount = snapshot?.data()?["replyCount"] as? Int ?? 0
            group.leave()
        }
        group.enter()
        queryOwnerDocs(group: "replies", matchField: "replyId", equals: reply.id, extraMatch: ("topicId", reply.topicId)) { refs in
            lock.lock(); ownerRefs = refs; lock.unlock()
            group.leave()
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let batch = self.db.batch()
            batch.deleteDocument(topicRef.collection("replies").document(reply.id))
            if currentCount > 0 {
                batch.updateData(["replyCount": max(0, currentCount - 1)], forDocument: topicRef)
            }
            let now = Timestamp(date: Date())
            ownerRefs.forEach { ref in
                batch.updateData([
                    "body": "",
                    "bodyPreview": "",
                    "isDeleted": true,
                    "deletedAt": now,
                    "updatedAt": now
                ], forDocument: ref)
            }
            batch.commit { [weak self] error in
                if let error { self?.lastErrorMessage = error.localizedDescription }
                DispatchQueue.main.async { completion?(error == nil) }
            }
        }
    }

    func updateReply(_ reply: AdminCommunityReply, body: String, completion: ((Bool) -> Void)? = nil) {
        let now = Timestamp(date: Date())
        queryOwnerDocs(group: "replies", matchField: "replyId", equals: reply.id, extraMatch: ("topicId", reply.topicId)) { [weak self] refs in
            guard let self else { return }
            let batch = self.db.batch()
            let replyRef = self.db.collection("communityTopics")
                .document(reply.topicId)
                .collection("replies")
                .document(reply.id)
            batch.updateData(["body": body, "updatedAt": now], forDocument: replyRef)
            let fields: [String: Any] = [
                "body": body,
                "bodyPreview": adminPreview(body),
                "updatedAt": now
            ]
            refs.forEach { batch.updateData(fields, forDocument: $0) }
            batch.commit { [weak self] error in
                if let error { self?.lastErrorMessage = error.localizedDescription }
                DispatchQueue.main.async { completion?(error == nil) }
            }
        }
    }

    // MARK: owner 文件工具

    private func queryOwnerDocs(group: String, matchField: String, equals value: String, extraMatch: (String, String)? = nil, completion: @escaping ([DocumentReference]) -> Void) {
        var query = db.collectionGroup(group).whereField(matchField, isEqualTo: value)
        query = query.limit(to: 50)
        query.getDocuments { snapshot, _ in
            let refs = snapshot?.documents
                .filter { extraMatch == nil || ($0.data()[extraMatch!.0] as? String) == extraMatch!.1 }
                .map(\.reference) ?? []
            completion(refs)
        }
    }

    private func cleanupOwnerDocs(group: String, matchField: String, equals value: String, completion: @escaping () -> Void) {
        queryOwnerDocs(group: group, matchField: matchField, equals: value) { refs in
            guard !refs.isEmpty else { completion(); return }
            let batch = Firestore.firestore().batch()
            refs.forEach { batch.deleteDocument($0) }
            batch.commit { _ in completion() }
        }
    }



    private func commitOwnerUpdates(batch: WriteBatch, group: String, matchField: String, equals value: String, fields: [String: Any], completion: @escaping (Error?) -> Void) {
        queryOwnerDocs(group: group, matchField: matchField, equals: value) { refs in
            refs.forEach { batch.updateData(fields, forDocument: $0) }
            batch.commit(completion: completion)
        }
    }
}

// MARK: - 餐廳留言管理

struct AdminRestaurantComment: Identifiable {
    let id: String
    let collectionName: String
    let storeId: String
    var name: String
    var body: String
    var date: Double
    var deviceId: String
    var authorUid: String?

    static func from(collectionName: String, storeId: String, id: String, data: [String: Any]) -> AdminRestaurantComment {
        AdminRestaurantComment(
            id: id,
            collectionName: collectionName,
            storeId: storeId,
            name: data["name"] as? String ?? "",
            body: data["body"] as? String ?? "",
            date: data["date"] as? Double ?? 0,
            deviceId: data["deviceId"] as? String ?? "",
            authorUid: data["authorUid"] as? String
        )
    }
}

@MainActor
final class RestaurantCommentAdminModel: ObservableObject {
    @Published var lastErrorMessage: String?
    @Published var stores: [(id: String, name: String)] = []
    @Published var comments: [AdminRestaurantComment] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private let mealCollections: [(label: String, name: String)] = [
        ("早餐", K.FStoreF.collectionNameB),
        ("午餐", K.FStoreF.collectionNamel),
        ("晚餐", K.FStoreF.collectionNamed),
        ("消夜", K.FStoreF.collectionNamem)
    ]
    var mealOptions: [(label: String, name: String)] { mealCollections }

    func loadStores(mealCollection: String, completion: (() -> Void)? = nil) {
        isLoading = true
        db.collection(mealCollection).getDocuments { [weak self] snapshot, _ in
            let items = snapshot?.documents
                .compactMap { doc -> (id: String, name: String)? in
                    guard let name = doc.data()["store"] as? String else { return nil }
                    return (doc.documentID, name)
                }
                .sorted { $0.name < $1.name } ?? []
            DispatchQueue.main.async {
                self?.stores = items
                self?.isLoading = false
                completion?()
            }
        }
    }

    func loadComments(mealCollection: String, storeId: String) {
        isLoading = true
        db.collection(mealCollection).document(storeId).collection("comments")
            .order(by: "date", descending: true)
            .limit(to: 200)
            .getDocuments { [weak self] snapshot, _ in
                let items = snapshot?.documents.map {
                    AdminRestaurantComment.from(collectionName: mealCollection, storeId: storeId, id: $0.documentID, data: $0.data())
                } ?? []
                DispatchQueue.main.async {
                    self?.comments = items
                    self?.isLoading = false
                }
            }
    }

    func updateComment(_ comment: AdminRestaurantComment, newBody: String, completion: ((Bool) -> Void)? = nil) {
        commentRef(comment).updateData([
            "body": newBody,
            "updatedAt": Date().timeIntervalSince1970
        ]) { [weak self] error in
            if let error { self?.lastErrorMessage = error.localizedDescription }
            DispatchQueue.main.async { completion?(error == nil) }
        }
    }

    func deleteComment(_ comment: AdminRestaurantComment, completion: ((Bool) -> Void)? = nil) {
        let batch = db.batch()
        batch.deleteDocument(commentRef(comment))
        // 清理擁有者索引（含已消失帳號的舊紀錄），並收集各擁有者 uid 供統計遞減
        db.collectionGroup("comments")
            .whereField("commentId", isEqualTo: comment.id)
            .limit(to: 10)
            .getDocuments { [weak self] snapshot, _ in
                guard let self else { return }
                var ownerUids: Set<String> = []
                snapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                    // 路徑 restaurantCommentOwners/{uid}/comments/{id}
                    if let uid = document.reference.parent.parent?.documentID, !uid.isEmpty {
                        ownerUids.insert(uid)
                    }
                }
                batch.commit { error in
                    if let error {
                        self.lastErrorMessage = error.localizedDescription
                        DispatchQueue.main.async { completion?(false) }
                        return
                    }
                    // 遞減每個擁有者的 userStats.total
                    let statsBatch = self.db.batch()
                    ownerUids.forEach { uid in
                        statsBatch.updateData(
                            ["total": FieldValue.increment(Int64(-1))],
                            forDocument: self.db.collection("userStats").document(uid)
                        )
                    }
                    statsBatch.commit { statsError in
                        if let statsError { self.lastErrorMessage = statsError.localizedDescription }
                        DispatchQueue.main.async { completion?(statsError == nil) }
                    }
                }
            }
    }

    private func commentRef(_ comment: AdminRestaurantComment) -> DocumentReference {
        db.collection(comment.collectionName)
            .document(comment.storeId)
            .collection("comments")
            .document(comment.id)
    }
}


// MARK: - 交流區管理介面

struct CommunityAdminView: View {
    @StateObject private var model = CommunityAdminModel()
    @State private var editingTopic: AdminCommunityTopic?
    @State private var pendingDeleteTopic: AdminCommunityTopic?

    private var hasPermission: Bool { CommunityProfileManager.isPrivilegedAdminEmail }

    var body: some View {
        List {
            if !hasPermission {
                Section {
                    Label(String(localized: "community_admin_email_required"), systemImage: "lock.shield")
                        .foregroundStyle(.secondary)
                }
            }
            if model.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
            ForEach(model.topics) { topic in
                NavigationLink {
                    CommunityRepliesAdminView(model: model, topic: topic)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(topic.title).font(.headline).lineLimit(1)
                            if topic.isDeleted {
                                Text("已刪除").font(.caption2.bold())
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(.red.opacity(0.15)).foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(topic.authorName) · \(adminDateText(topic.createdAt)) · \(topic.category) · 回覆 \(topic.replyCount)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeleteTopic = topic
                    } label: { Label("刪除", systemImage: "trash") }

                    Button {
                        editingTopic = topic
                    } label: { Label("編輯", systemImage: "pencil") }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("交流貼文")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.loadTopics() } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .onAppear { model.loadTopics() }
        .alert("操作失敗", isPresented: Binding(
            get: { model.lastErrorMessage != nil },
            set: { if !$0 { model.lastErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) { }
        } message: {
            Text(model.lastErrorMessage ?? "")
        }
        .sheet(item: $editingTopic) { topic in
            AdminTextEditSheet(header: "編輯主題", initialTitle: topic.title, initialBody: topic.body) { newTitle, newBody in
                model.updateTopic(topic, title: newTitle, body: newBody) { _ in model.loadTopics() }
            }
        }
        .alert("確認刪除這篇主題？", isPresented: Binding(
            get: { pendingDeleteTopic != nil },
            set: { if !$0 { pendingDeleteTopic = nil } }
        )) {
            Button("刪除", role: .destructive) {
                if let topic = pendingDeleteTopic {
                    model.deleteTopic(topic) { _ in model.loadTopics() }
                }
                pendingDeleteTopic = nil
            }
            Button("取消", role: .cancel) { pendingDeleteTopic = nil }
        } message: {
            Text("將比照作者刪除流程清空內容，並清除擁有者紀錄。")
        }
    }
}

struct CommunityRepliesAdminView: View {
    @ObservedObject var model: CommunityAdminModel
    let topic: AdminCommunityTopic
    @State private var replies: [AdminCommunityReply] = []
    @State private var editingReply: AdminCommunityReply?
    @State private var pendingDeleteReply: AdminCommunityReply?

    var body: some View {
        List {
            if replies.isEmpty && !model.isLoading {
                Text("沒有回覆").foregroundStyle(.secondary)
            }
            ForEach(replies) { reply in
                VStack(alignment: .leading, spacing: 4) {
                    Text(reply.body).font(.subheadline).lineLimit(3)
                    Text("\(reply.authorName) · \(adminDateText(reply.createdAt))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeleteReply = reply
                    } label: { Label("刪除", systemImage: "trash") }

                    Button {
                        editingReply = reply
                    } label: { Label("編輯", systemImage: "pencil") }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("回覆管理")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if model.isLoading { ProgressView() }
        }
        .onAppear { model.loadReplies(topicId: topic.id) { items in replies = items } }
        .alert("操作失敗", isPresented: Binding(
            get: { model.lastErrorMessage != nil },
            set: { if !$0 { model.lastErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) { }
        } message: {
            Text(model.lastErrorMessage ?? "")
        }
        .sheet(item: $editingReply) { reply in
            AdminTextEditSheet(header: "編輯回覆", initialTitle: "", initialBody: reply.body, showsTitleField: false) { _, newBody in
                model.updateReply(reply, body: newBody) { _ in
                    model.loadReplies(topicId: topic.id) { items in replies = items }
                }
            }
        }
        .alert("確認刪除這則回覆？", isPresented: Binding(
            get: { pendingDeleteReply != nil },
            set: { if !$0 { pendingDeleteReply = nil } }
        )) {
            Button("刪除", role: .destructive) {
                if let reply = pendingDeleteReply {
                    model.deleteReply(reply) { _ in
                        model.loadReplies(topicId: topic.id) { items in replies = items }
                    }
                }
                pendingDeleteReply = nil
            }
            Button("取消", role: .cancel) { pendingDeleteReply = nil }
        } message: {
            Text("將同時遞減回覆數並清理擁有者紀錄。")
        }
    }
}

struct RestaurantCommentsAdminView: View {
    @StateObject private var model = RestaurantCommentAdminModel()
    @State private var selectedMeal: String = K.FStoreF.collectionNameB
    @State private var selectedStoreId: String?
    @State private var editingComment: AdminRestaurantComment?
    @State private var pendingDeleteComment: AdminRestaurantComment?

    private var selectedStoreName: String {
        model.stores.first { $0.id == selectedStoreId }?.name ?? "-"
    }

    private var hasPermission: Bool { CommunityProfileManager.isPrivilegedAdminEmail }

    var body: some View {
        Form {
            if !hasPermission {
                Section {
                    Label(String(localized: "community_admin_email_required"), systemImage: "lock.shield")
                        .foregroundStyle(.secondary)
                }
            }
            Section("餐期") {
                Picker("餐期", selection: $selectedMeal) {
                    ForEach(model.mealOptions, id: \.name) { option in
                        Text(option.label).tag(option.name)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedMeal) { newValue in
                    selectedStoreId = nil
                    model.comments = []
                    model.loadStores(mealCollection: newValue)
                }
            }

            Section("店家") {
                if model.stores.isEmpty {
                    Text("此餐期尚無店家").foregroundStyle(.secondary)
                } else {
                    Picker("店家", selection: $selectedStoreId) {
                        ForEach(model.stores, id: \.id) { store in
                            Text(store.name).tag(Optional(store.id))
                        }
                    }
                    .onChange(of: selectedStoreId) { newValue in
                        guard let newValue else { return }
                        model.loadComments(mealCollection: selectedMeal, storeId: newValue)
                    }
                }
            }

            Section("留言（\(selectedStoreName)）") {
                if model.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if model.comments.isEmpty {
                    Text("沒有留言").foregroundStyle(.secondary)
                }
                ForEach(model.comments) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(comment.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(adminDateText(Date(timeIntervalSince1970: comment.date)))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(comment.body).font(.caption).lineLimit(3)
                        if let uid = comment.authorUid, !uid.isEmpty {
                            Text("UID: \(uid.prefix(10))…").font(.caption2).foregroundStyle(.orange)
                        } else if !comment.deviceId.isEmpty {
                            Text("裝置: \(comment.deviceId.prefix(8))…").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeleteComment = comment
                        } label: { Label("刪除", systemImage: "trash") }

                        Button {
                            editingComment = comment
                        } label: { Label("編輯", systemImage: "pencil") }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("餐廳留言")
        .onAppear { model.loadStores(mealCollection: selectedMeal) }
        .alert("操作失敗", isPresented: Binding(
            get: { model.lastErrorMessage != nil },
            set: { if !$0 { model.lastErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) { }
        } message: {
            Text(model.lastErrorMessage ?? "")
        }
        .sheet(item: $editingComment) { comment in
            AdminTextEditSheet(header: "編輯留言", initialTitle: "", initialBody: comment.body, showsTitleField: false) { _, newBody in
                model.updateComment(comment, newBody: newBody) { _ in
                    model.loadComments(mealCollection: comment.collectionName, storeId: comment.storeId)
                }
            }
        }
        .alert("確認刪除這則留言？", isPresented: Binding(
            get: { pendingDeleteComment != nil },
            set: { if !$0 { pendingDeleteComment = nil } }
        )) {
            Button("刪除", role: .destructive) {
                if let comment = pendingDeleteComment {
                    model.deleteComment(comment) { _ in
                        model.loadComments(mealCollection: comment.collectionName, storeId: comment.storeId)
                    }
                }
                pendingDeleteComment = nil
            }
            Button("取消", role: .cancel) { pendingDeleteComment = nil }
        } message: {
            Text("將同時清理擁有者索引，已消失帳號的留言也可一併移除。")
        }
    }
}

struct AdminTextEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let header: String
    @State var initialTitle: String
    @State var initialBody: String
    var showsTitleField: Bool = true
    let onSave: (String, String) -> Void

    @State private var titleText: String = ""
    @State private var bodyText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                if showsTitleField {
                    TextField("標題", text: $titleText)
                }
                Section("內容") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle(header)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        onSave(titleText.trimmingCharacters(in: .whitespacesAndNewlines),
                               bodyText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                titleText = initialTitle
                bodyText = initialBody
            }
        }
    }
}
