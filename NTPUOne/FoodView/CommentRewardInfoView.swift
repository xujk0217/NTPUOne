//
//  CommentRewardInfoView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2026/3/8.
//

import SwiftUI
import FirebaseFirestore

/// 用戶留言記錄
struct MyCommentRecord: Identifiable {
    let id: String
    let storeId: String
    let storeName: String
    let collection: String
    var body: String
    let date: Date
    
    var dateText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy/MM/dd HH:mm"
        return fmt.string(from: date)
    }
    
    var mealType: String {
        switch collection {
        case "breakfast": return String(localized: "breakfast")
        case "lunch": return String(localized: "lunch")
        case "dinner": return String(localized: "dinner")
        case "MS": return String(localized: "late_night_snack")
        default: return collection
        }
    }
}

/// 評論獎勵系統介紹頁面
struct CommentRewardInfoView: View {
    @ObservedObject private var badgeManager = CommentBadgeManager.shared
    @ObservedObject private var commentLimit = CommentLimitManager.shared
    @EnvironmentObject var adFree: AdFreeService
    @AppStorage("commentDeviceId") private var deviceId: String = ""
    
    @State private var myComments: [MyCommentRecord] = []
    @State private var isLoadingComments = false
    @State private var isCommentsExpanded = true
    
    // 編輯/刪除相關
    @State private var editingComment: MyCommentRecord? = nil
    @State private var editingBody: String = ""
    @State private var showDeleteConfirm = false
    @State private var commentToDelete: MyCommentRecord? = nil
    @StateObject private var commentManager = CommentManager()
    
    var body: some View {
        List {
            // 1. 我的徽章卡片
            Section {
                BadgeCardView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text(String(localized: "my_badge"))
            }
            
            // 2. 今日狀態
            Section {
                todayStatusContent
            } header: {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.blue)
                    Text(String(localized: "today_status"))
                }
            }
            
            // 3. 我的留言（可收合）
            Section {
                // Header 作為可點擊的列
                Button {
                    withAnimation {
                        isCommentsExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundStyle(.purple)
                        Text(String(localized: "my_comments"))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(myComments.count)")
                            .foregroundStyle(.secondary)
                        Image(systemName: isCommentsExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color(.systemGroupedBackground))
                
                if isCommentsExpanded {
                    if isLoadingComments {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if myComments.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(String(localized: "no_comments_yet_self"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(myComments) { comment in
                            myCommentRow(comment)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        commentToDelete = comment
                                        showDeleteConfirm = true
                                    } label: {
                                        Label(String(localized: "delete"), systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        editingBody = comment.body
                                        editingComment = comment
                                    } label: {
                                        Label(String(localized: "edit"), systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
            
            // 4. 徽章等級說明
            Section {
                badgeLevelsContent
            } header: {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.orange)
                    Text(String(localized: "badge_levels"))
                }
            }
            
            // 5. 評論獎勵說明
            Section {
                rewardInfoContent
            } header: {
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(.green)
                    Text(String(localized: "comment_rewards"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "comment_reward_system"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadMyComments()
        }
        .sheet(item: $editingComment) { comment in
            editCommentSheet(comment)
        }
        .alert(String(localized: "confirm_delete"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "cancel"), role: .cancel) {}
            Button(String(localized: "delete"), role: .destructive) {
                if let c = commentToDelete {
                    deleteComment(c)
                }
            }
        } message: {
            Text(String(localized: "delete_comment_confirm_message"))
        }
    }
    
    // MARK: - 我的留言列
    private func myCommentRow(_ comment: MyCommentRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.storeName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                
                Spacer()
                
                Text(comment.mealType)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            
            Text(comment.body)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            Text(comment.dateText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 編輯留言 Sheet
    private func editCommentSheet(_ comment: MyCommentRecord) -> some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(comment.storeName)
                    .font(.headline)
                
                TextEditor(text: $editingBody)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle(String(localized: "edit_comment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) {
                        editingComment = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "save")) {
                        saveEditedComment(comment)
                    }
                    .disabled(editingBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // MARK: - 編輯留言
    private func saveEditedComment(_ comment: MyCommentRecord) {
        let trimmed = editingBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        commentManager.editComment(
            collection: comment.collection,
            storeId: comment.storeId,
            id: comment.id,
            newBody: trimmed
        ) { success in
            if success {
                // 更新本地列表
                if let idx = myComments.firstIndex(where: { $0.id == comment.id }) {
                    myComments[idx].body = trimmed
                }
            }
            editingComment = nil
        }
    }
    
    // MARK: - 刪除留言
    private func deleteComment(_ comment: MyCommentRecord) {
        commentManager.deleteComment(
            collection: comment.collection,
            storeId: comment.storeId,
            id: comment.id
        ) { success in
            if success {
                myComments.removeAll { $0.id == comment.id }
                // 更新徽章數量
                badgeManager.decrementComment()
            }
        }
    }
    
    // MARK: - 徽章等級內容（用於 List）
    @ViewBuilder
    private var badgeLevelsContent: some View {
        ForEach(badgeLevels, id: \.level) { item in
            HStack(spacing: 12) {
                BadgeTagView(badge: item.level, compact: false)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.level.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(item.level.color)
                    Text(item.requirement)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if badgeManager.totalComments >= item.level.minComments || 
                   (item.level == .developer && badgeManager.getCurrentBadge() == .developer) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }
    
    // MARK: - 獎勵說明內容（用於 List）
    @ViewBuilder
    private var rewardInfoContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "reward_per_comment"))
                    .font(.subheadline.bold())
                Text(String(localized: "reward_per_comment_desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "daily_reward_limit"))
                    .font(.subheadline.bold())
                Text(String(localized: "daily_reward_limit_desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "badge_upgrade"))
                    .font(.subheadline.bold())
                Text(String(localized: "badge_upgrade_desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - 今日狀態內容（用於 List）
    private var todayStatusContent: some View {
        HStack(spacing: 16) {
            statusCard(
                value: "\(commentLimit.remainingComments)",
                label: String(localized: "remaining_comments"),
                color: .blue
            )
            
            statusCard(
                value: String(format: "%.1f", commentLimit.getRemainingRewardHours()),
                label: String(localized: "remaining_reward_hours"),
                color: .orange
            )
            
            statusCard(
                value: String(format: "%.1f", adFree.remainingHours()),
                label: String(localized: "ad_free_hours"),
                color: .green
            )
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Helper Views
    private func statusCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Data
    private var badgeLevels: [(level: CommentBadgeManager.BadgeLevel, requirement: String)] {
        var levels: [(CommentBadgeManager.BadgeLevel, String)] = [
            (.newbie, String(localized: "badge_req_newbie")),
            (.explorer, String(localized: "badge_req_explorer")),
            (.senior, String(localized: "badge_req_senior")),
            (.expert, String(localized: "badge_req_expert")),
            (.master, String(localized: "badge_req_master"))
        ]
        
        // 如果是開發者，加入開發者徽章
        if badgeManager.getCurrentBadge() == .developer {
            levels.append((.developer, String(localized: "badge_req_developer")))
        }
        
        return levels
    }
    
    // MARK: - Load Comments
    private func loadMyComments() {
        guard !deviceId.isEmpty else { return }
        isLoadingComments = true
        
        let db = Firestore.firestore()
        let collections = ["breakfast", "lunch", "dinner", "MS"]
        var allComments: [MyCommentRecord] = []
        let group = DispatchGroup()
        
        for collection in collections {
            group.enter()
            
            // 先獲取所有餐廳
            db.collection(collection).getDocuments { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    group.leave()
                    return
                }
                
                let innerGroup = DispatchGroup()
                
                for doc in docs {
                    innerGroup.enter()
                    let storeId = doc.documentID
                    let storeName = doc.data()["store"] as? String ?? storeId
                    
                    // 查詢該餐廳的用戶留言
                    db.collection(collection)
                        .document(storeId)
                        .collection("comments")
                        .whereField("deviceId", isEqualTo: deviceId)
                        .getDocuments { commentSnapshot, error in
                            defer { innerGroup.leave() }
                            guard let commentDocs = commentSnapshot?.documents, error == nil else { return }
                            
                            for commentDoc in commentDocs {
                                let data = commentDoc.data()
                                let record = MyCommentRecord(
                                    id: commentDoc.documentID,
                                    storeId: storeId,
                                    storeName: storeName,
                                    collection: collection,
                                    body: data["body"] as? String ?? "",
                                    date: Date(timeIntervalSince1970: data["date"] as? Double ?? 0)
                                )
                                allComments.append(record)
                            }
                        }
                }
                
                innerGroup.notify(queue: .main) {
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            // 按時間排序（最新的在前面）
            myComments = allComments.sorted { $0.date > $1.date }
            isLoadingComments = false
            
            // 同步伺服器上的留言數量到本地（修正可能的數量差異）
            CommentBadgeManager.shared.syncCommentCount(allComments.count)
        }
    }
}

#Preview {
    NavigationStack {
        CommentRewardInfoView()
            .environmentObject(AdFreeService.shared)
    }
}
