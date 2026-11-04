//
//  dietView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/1.
//
import SwiftUI
import MapKit
import SafariServices
import FirebaseAuth
import FirebaseFirestore

private func restaurantCommentRelativeTime(_ timestamp: Double) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale.current
    formatter.unitsStyle = .short
    return formatter.localizedString(for: Date(timeIntervalSince1970: timestamp), relativeTo: Date())
}

// 新留言以寫入時的徽章快照為準（不再暴露 authorUid 查全域統計）；舊留言退回統計推算
fileprivate func storedOrCountedBadge(for comment: StoreComment, globalStats: [String: Int]) -> CommentBadgeManager.BadgeLevel {
    if let stored = comment.authorBadgeLevel,
       let level = CommentBadgeManager.BadgeLevel(rawValue: stored) {
        return level
    }
    let count = globalStats[comment.statsOwnerId] ?? 0
    return CommentBadgeManager.badgeLevel(for: count)
}

@available(iOS 17.0, *)
struct dietView: View {
    @State var store: FDetail
    let currCollectName: String?
    @EnvironmentObject var adFree: AdFreeService
    @State private var safariDestination: SceneSafariDestination?
    @State private var scenePresenter = WeakScenePresentationController()

    @State private var isStar = false
    @State private var position: MapCameraPosition
    @State private var selectionResult: MKMapItem?
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0

    // 留言
    @StateObject private var commentManager = CommentManager()
    @ObservedObject private var commentLimit = CommentLimitManager.shared
    @AppStorage("commentNickname") private var nickname: String = ""
    @AppStorage("commentDeviceId") private var deviceId: String = ""
    @State private var commentBody = ""
    @State private var isSubmitting = false
    @FocusState private var commentBodyFocused: Bool
    @State private var commentErrorMessage: String?
    
    // 留言限制 Alert
    @State private var showCommentLimitAlert = false
    @State private var showAdNotReadyAlert = false
    @State private var showSignInRequiredAlert = false
    
    // 評論獎勵 Toast
    @State private var showRewardToast = false
    @State private var rewardToastMessage = ""
    @ObservedObject private var badgeManager = CommentBadgeManager.shared
    
    // 編輯留言
    @State private var editingComment: StoreComment? = nil

    private var myEditableComments: [StoreComment] {
        commentManager.comments.filter { commentManager.canEdit($0) }
    }
    @State private var editingBody: String = ""
    @State private var commentToDelete: StoreComment? = nil
    @State private var showDeleteConfirm = false

    init(store: FDetail, currCollectName: String?) {
        self._store = State(initialValue: store)
        self.currCollectName = currCollectName
        self._position = State(initialValue: .camera(
            MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng), distance: 780)
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    mapView
                } header: {
                    Text(String(localized: "restaurant_location"))
                }

                if !store.check {
                    Section {
                        Text(String(localized: "data_not_verified"))
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    HStack(spacing: 10) {
                        Button {
                            toggleStar()
                        } label: {
                            Image(systemName: isStar ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(isStar ? Color.yellow : Color.gray)
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(store.starNum))")
                            .font(.title3.weight(.bold))

                        Text(String(localized: "popularity_index_label"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    VStack(alignment: .leading) {
                        Text(store.store)
                            .font(.title2.bold())
                        HStack {
                            Image(systemName: "house")
                            Text(": \(store.address)")
                                .foregroundStyle(store.url.isEmpty ? Color.primary : Color.blue)
                        }
                        HStack {
                            Image(systemName: "clock")
                            Text(": \(store.time)")
                        }
                        HStack {
                            Image(systemName: "phone")
                            Text(": \(store.phone)")
                        }
                    }
                    .onTapGesture {
                        openURL(store.url)
                    }
                }

                // 留言 Section
                commentsSection

                // Native 廣告 Section
                if !adFree.isAdFree {
                    Section {
                        NativeAdSectionView(style: .compact)
                            .frame(height: 140)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { commentBodyFocused = false })
            .scrollContentBackground(.hidden)
            .background(Color.gray.opacity(0.1))
            .safeAreaInset(edge: .bottom) {
                commentPinnedBar
            }
            .navigationTitle(store.store)

            .toolbar {
                if !myEditableComments.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(myEditableComments) { comment in
                                Button("\(comment.dateText) · \(comment.body.prefix(12))") {
                                    editingBody = comment.body
                                    editingComment = comment
                                }
                            }
                        } label: {
                            Image(systemName: "pencil")
                        }
                    }
                }
            }            .onAppear {
                deviceId = CommunityProfileManager.ensureDeviceId()
                if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    nickname = CommunityProfileManager.ensureDefaultNickname(deviceId: deviceId)
                }
                // 每次開啟餐廳頁面時同步自己的全域統計，讓他人能看到正確徽章等級
                if let coll = currCollectName, let sid = store.id {
                    commentManager.loadComments(collection: coll, storeId: sid)
                }
                // 預載獎勵式廣告
                RewardedAdManager.shared.preload()
            }
            .onDisappear {
                isStar = false
            }
            .alert(String(localized: "comment_limit_reached"), isPresented: $showCommentLimitAlert) {
                if commentLimit.canWatchAdForBonus && GlobalFeatureSettings.shared.adsEnabled {
                    Button(String(localized: "watch_ad")) {
                        watchAdForBonus()
                    }
                    Button(String(localized: "cancel"), role: .cancel) { }
                } else {
                    Button(String(localized: "ok"), role: .cancel) { }
                }
            } message: {
                if !GlobalFeatureSettings.shared.adsEnabled {
                    Text("目前已達評論上限，獎勵廣告暫停提供。")
                } else if commentLimit.canWatchAdForBonus {
                    Text(String(format: String(localized: "comment_limit_message"), commentLimit.remainingAdViews))
                } else {
                    Text(String(localized: "comment_limit_all_used"))
                }
            }
            .alert(String(localized: "ad_not_ready"), isPresented: $showAdNotReadyAlert) {
                Button(String(localized: "ok"), role: .cancel) { }
            }
            .alert(String(localized: "community_action_failed_title"), isPresented: $showSignInRequiredAlert) {
                Button(String(localized: "ok"), role: .cancel) { }
            } message: {
                Text(String(localized: "community_google_sign_in_required_error"))
            }
            .alert(String(localized: "confirm_delete"), isPresented: $showDeleteConfirm) {
                Button(String(localized: "cancel"), role: .cancel) { }
                Button(String(localized: "delete"), role: .destructive) {
                    if let comment = commentToDelete {
                        deleteOwnedComment(comment)
                    }
                }
            } message: {
                Text(String(localized: "delete_comment_confirm_message"))
            }
            .background(ScenePresentationAnchor { scenePresenter.controller = $0 })
            .sheet(item: $safariDestination) { destination in SafariView(url: destination.url) }
            .sheet(item: $editingComment) { comment in
                editCommentSheet(comment)
            }
        }
    }
    
    // MARK: - 編輯留言 Sheet
    private func editCommentSheet(_ comment: StoreComment) -> some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(store.store)
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
    
    // MARK: - 儲存編輯後的留言
    private func saveEditedComment(_ comment: StoreComment) {
        let trimmed = editingBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let coll = currCollectName,
              let sid = store.id,
              let cid = comment.id else { return }
        
        commentManager.editComment(collection: coll, storeId: sid, id: cid, newBody: trimmed) { _ in
            editingComment = nil
        }
    }

    private func deleteOwnedComment(_ comment: StoreComment) {
        guard let coll = currCollectName,
              let sid = store.id,
              let cid = comment.id else { return }

        commentManager.deleteComment(collection: coll, storeId: sid, id: cid, deviceId: comment.deviceId) { success in
            if success {
                badgeManager.decrementComment()
            }
            commentToDelete = nil
        }
    }

    var mapView: some View {
        Map(position: $position, selection: $selectionResult) {
            Marker(store.store, systemImage: "house", coordinate: CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng))
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 300)
    }
    
    // MARK: - Comments Section
    private var commentsSection: some View {
        Section {
            commentsContent
        } header: {
            commentsHeader
        } footer: {
            commentsFooter
        }
    }

    private var commentPinnedBar: some View {
        commentInputView
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                    }
            )
            .padding(.horizontal)
            .padding(.bottom, 10)
    }

    @ViewBuilder
    private var commentsContent: some View {
        if commentManager.isLoading {
            ProgressView().frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        } else if commentManager.comments.isEmpty {
            Text(String(localized: "no_comments_yet"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
        }
        ForEach(commentManager.comments) { comment in
            commentRow(comment)
        }
        if Auth.auth().currentUser == nil {
            Label(String(localized: "restaurant_google_sign_in_to_comment"), systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
                .listRowSeparator(.hidden)
        }
    }
    
    private func commentRow(_ comment: StoreComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(restaurantCommentDisplayName(comment))
                    .font(.caption.weight(.semibold))
                if commentManager.canEdit(comment) {
                    BadgeTagView(badge: badgeManager.getCurrentBadge(), compact: true)
                } else {
                    BadgeTagView(badge: storedOrCountedBadge(for: comment, globalStats: commentManager.userGlobalStats), compact: true)
                }
                if commentManager.canEdit(comment) {
                    Text(String(localized: "you"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(restaurantCommentRelativeTime(comment.updatedAt ?? comment.date))
                    Text("·").foregroundStyle(.secondary)
                    Text(comment.dateText).foregroundStyle(.secondary)
                }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if comment.isEdited {
                    Text(String(localized: "community_edited_label"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(comment.body)
                .font(.body)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if commentManager.canEdit(comment) {
                Button(role: .destructive) {
                    commentToDelete = comment
                    showDeleteConfirm = true
                } label: {
                    Label(String(localized: "delete"), systemImage: "trash")
                }

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
    
    private var commentInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if Auth.auth().currentUser == nil {
                Text(String(localized: "community_google_sign_in_required_error"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            CommentIdentityBar(showsDepartmentAndYear: false, interactive: false)
            HStack(alignment: .bottom, spacing: 8) {
                TextField(String(localized: "textfield_comment"), text: $commentBody)
                    .submitLabel(.done)
                    .focused($commentBodyFocused)
                    .onSubmit { commentBodyFocused = false }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(Color(.systemBackground), in: Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 0.8))

                Button {
                    submitComment()
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .font(.body)
                    .frame(width: 44, height: 40)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: Capsule())
                    .shadow(color: Color.accentColor.opacity(0.25), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(
                    commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || Auth.auth().currentUser == nil
                    || isSubmitting
                )
            }
        }
        .padding(.vertical, 4)
        .alert(String(localized: "comment_post_failed_title"), isPresented: Binding(
            get: { commentErrorMessage != nil },
            set: { if !$0 { commentErrorMessage = nil } }
        )) {
            Button(String(localized: "ok"), role: .cancel) { }
        } message: {
            Text(commentErrorMessage ?? "")
        }
    }

    
    private var commentsHeader: some View {
        HStack {
            Text(String(format: String(localized: "comments_count"), commentManager.comments.count))
            Spacer()
            Text(String(format: String(localized: "remaining_comments_today"), commentLimit.remainingComments))
                .font(.caption2)
                .foregroundColor(commentLimit.remainingComments > 0 ? Color.secondary : Color.red)
        }
    }
    
    @ViewBuilder
    private var commentsFooter: some View {
        if Auth.auth().currentUser != nil {
            Text(CommunityProfileManager.currentNicknameDisplayName())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func restaurantCommentDisplayName(_ comment: StoreComment) -> String {
        commentManager.canEdit(comment) ? CommunityProfileManager.currentNicknameDisplayName() : comment.name
    }

    func openURL(_ urlString: String) {
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            safariDestination = SceneSafariDestination(url: url)
        }
    }

    func toggleStar() {
        let target = !isStar
        let previousStarNum = store.starNum
        isStar = target
        guard target || previousStarNum > 0 else { return }

        let delta: Double = target ? 1 : -1
        store.starNum = max(0, previousStarNum + delta)
        FManager.incrementStar(collectionName: currCollectName!, id: store.id!, delta: delta) { error in
            guard let error else { return }
            print("incrementStar failed: \(error)")
            DispatchQueue.main.async {
                store.starNum = previousStarNum
                isStar = !target
            }
        }
    }
    func submitComment() {
        guard let coll = currCollectName, let sid = store.id else { return }
        let trimBody = commentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Auth.auth().currentUser != nil else {
            showSignInRequiredAlert = true
            return
        }
        let trimName = CommunityProfileManager.currentNicknameDisplayName().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimBody.isEmpty, !trimName.isEmpty else { return }
        
        // 檢查留言限制
        guard commentLimit.canComment else {
            showCommentLimitAlert = true
            return
        }
        
        isSubmitting = true
        commentManager.addComment(collection: coll, storeId: sid, name: trimName, body: trimBody, deviceId: deviceId) { [self] error in
            isSubmitting = false
            if let error {
                commentErrorMessage = error.localizedDescription
                return
            }
                let rewardedHours = commentLimit.recordComment()
                commentBody = ""
                commentBodyFocused = false
                
                // 顯示獎勵 Toast
                if rewardedHours > 0 {
                    rewardToastMessage = String(format: String(localized: "comment_reward_toast"), Int(rewardedHours))
                } else {
                    rewardToastMessage = String(localized: "comment_thank_you")
                }
                withAnimation(.spring(response: 0.4)) {
                    showRewardToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showRewardToast = false
                    }
                }
        }
    }
    
    func watchAdForBonus() {
        let presented = RewardedAdManager.shared.present(
            from: scenePresenter.controller,
            onReward: {
                commentLimit.grantAdBonus()
            },
            onDismiss: nil
        )
        if !presented {
            showAdNotReadyAlert = true
        }
    }
}


#Preview {
    if #available(iOS 17.0, *) {
        dietView(store: FDetail(store: "abc", time: "abc", url: "abc", address: "abc", phone: "0987654321", starNum: 1, lat: 24.947582922315316, lng: 1.1, check: false), currCollectName: K.FStoreF.collectionNamed)
    } else {
        // Fallback on earlier versions
        noMapDietView(store: FDetail(store: "abc", time: "abc", url: "abc", address: "abc", phone: "0987654321", starNum: 1, lat: 24.947582922315316, lng: 1.1, check: false), currCollectName: K.FStoreF.collectionNamed)
    }
}


struct noMapDietView: View {
    @EnvironmentObject var adFree: AdFreeService
    @State private var safariDestination: SceneSafariDestination?
    @State private var scenePresenter = WeakScenePresentationController()
    @State private var store: FDetail?
    let currCollectName: String?
    
    @State private var isStar = false

    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0

    // 留言
    @StateObject private var commentManager = CommentManager()
    @ObservedObject private var commentLimit = CommentLimitManager.shared
    @AppStorage("commentNickname") private var nickname: String = ""
    @AppStorage("commentDeviceId") private var deviceId: String = ""
    @State private var commentBody = ""
    @State private var isSubmitting = false
    @FocusState private var commentBodyFocused: Bool
    @State private var commentErrorMessage: String?
    
    // 留言限制 Alert
    @State private var showCommentLimitAlert = false
    @State private var showAdNotReadyAlert = false
    @State private var showSignInRequiredAlert = false
    
    // 評論獎勵 Toast
    @State private var showRewardToast = false
    @State private var rewardToastMessage = ""
    @ObservedObject private var badgeManager = CommentBadgeManager.shared
    
    // 編輯留言
    @State private var editingComment: StoreComment? = nil

    private var myEditableComments: [StoreComment] {
        commentManager.comments.filter { commentManager.canEdit($0) }
    }
    @State private var editingBody: String = ""
    @State private var commentToDelete: StoreComment? = nil
    @State private var showDeleteConfirm = false

    init(store: FDetail?, currCollectName: String?) {
        _store = State(initialValue: store)
        self.currCollectName = currCollectName
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "upgrade_ios_for_map"))
                } header: {
                    Text(String(localized: "restaurant_location"))
                }
                if !store!.check {
                    Section{
                        Text(String(localized: "data_not_verified"))
                            .font(.title3)
                            .foregroundStyle(Color.red)
                    }
                }
                Section {
                    HStack(spacing: 10) {
                        Button {
                            toggleStar()
                        } label: {
                            Image(systemName: isStar ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(isStar ? Color.yellow : Color.gray)
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(store!.starNum))")
                            .font(.title3.weight(.bold))

                        Text(String(localized: "popularity_index_label"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                Section {
                    HStack {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(store!.store)
                                        .font(.title2.bold())
                                    Spacer()
                                }
                                HStack(alignment: .top) {
                                    Image(systemName: "house")
                                    Text(": \(store!.address)")
                                        .foregroundStyle(store!.url.isEmpty ? Color.primary : Color.blue)
                                    Spacer()
                                }
                                HStack(alignment: .top) {
                                    Image(systemName: "clock")
                                    Text(": \(store!.time)")
                                    Spacer()
                                }
                                HStack(alignment: .top) {
                                    Image(systemName: "phone")
                                    Text(": \(store!.phone)")
                                    Spacer()
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        openURL(store!.url)
                    }
                }

                // 留言 Section
                noMapCommentsSection

                // Native 廣告 Section
                if !adFree.isAdFree {
                    Section {
                        NativeAdSectionView(style: .compact)
                            .frame(height: 140)
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded { commentBodyFocused = false })
                .scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.1))
                .safeAreaInset(edge: .bottom) {
                    noMapCommentPinnedBar
                }
            .navigationTitle(store!.store)

            .toolbar {
                if !myEditableComments.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(myEditableComments) { comment in
                                Button("\(comment.dateText) · \(comment.body.prefix(12))") {
                                    editingBody = comment.body
                                    editingComment = comment
                                }
                            }
                        } label: {
                            Image(systemName: "pencil")
                        }
                    }
                }
            }            .onAppear {
                deviceId = CommunityProfileManager.ensureDeviceId()
                if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    nickname = CommunityProfileManager.ensureDefaultNickname(deviceId: deviceId)
                }
                // 每次開啟餐廳頁面時同步自己的全域統計，讓他人能看到正確徽章等級
                if let coll = currCollectName, let sid = store?.id {
                    commentManager.loadComments(collection: coll, storeId: sid)
                }
                // 預載獎勵式廣告
                RewardedAdManager.shared.preload()
            }
            .onDisappear {
                isStar = false
            }
            .alert(String(localized: "comment_limit_reached"), isPresented: $showCommentLimitAlert) {
                if commentLimit.canWatchAdForBonus && GlobalFeatureSettings.shared.adsEnabled {
                    Button(String(localized: "watch_ad")) {
                        watchAdForBonus()
                    }
                    Button(String(localized: "cancel"), role: .cancel) { }
                } else {
                    Button(String(localized: "ok"), role: .cancel) { }
                }
            } message: {
                if !GlobalFeatureSettings.shared.adsEnabled {
                    Text("目前已達評論上限，獎勵廣告暫停提供。")
                } else if commentLimit.canWatchAdForBonus {
                    Text(String(format: String(localized: "comment_limit_message"), commentLimit.remainingAdViews))
                } else {
                    Text(String(localized: "comment_limit_all_used"))
                }
            }
            .alert(String(localized: "ad_not_ready"), isPresented: $showAdNotReadyAlert) {
                Button(String(localized: "ok"), role: .cancel) { }
            }
            .alert(String(localized: "community_action_failed_title"), isPresented: $showSignInRequiredAlert) {
                Button(String(localized: "ok"), role: .cancel) { }
            } message: {
                Text(String(localized: "community_google_sign_in_required_error"))
            }
            .alert(String(localized: "confirm_delete"), isPresented: $showDeleteConfirm) {
                Button(String(localized: "cancel"), role: .cancel) { }
                Button(String(localized: "delete"), role: .destructive) {
                    if let comment = commentToDelete {
                        noMapDeleteOwnedComment(comment)
                    }
                }
            } message: {
                Text(String(localized: "delete_comment_confirm_message"))
            }
            .background(ScenePresentationAnchor { scenePresenter.controller = $0 })
            .sheet(item: $safariDestination) { destination in SafariView(url: destination.url) }
            .sheet(item: $editingComment) { comment in
                noMapEditCommentSheet(comment)
            }
            .overlay(alignment: .top) {
                if showRewardToast {
                    noMapRewardToastView
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
        }
    }
    
    private var noMapRewardToastView: some View {
        HStack(spacing: 8) {
            Text("🎁")
            Text(rewardToastMessage)
                .font(.subheadline.bold())
            Text(badgeManager.getCurrentBadge().icon)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(20)
        .shadow(radius: 4)
        .padding(.top, 8)
    }
}

extension noMapDietView{
    func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                safariDestination = SceneSafariDestination(url: url)
            } else {
                print("Cannot open URL: \(urlString)")
            }
        }
    }
    
    func toggleStar() {
        let target = !isStar
        let previousStarNum = store!.starNum
        isStar = target
        guard target || previousStarNum > 0 else { return }

        let delta: Double = target ? 1 : -1
        store!.starNum = max(0, previousStarNum + delta)
        FManager.incrementStar(collectionName: currCollectName!, id: store!.id!, delta: delta) { error in
            guard let error else { return }
            print("incrementStar failed: \(error)")
            DispatchQueue.main.async {
                store!.starNum = previousStarNum
                isStar = !target
            }
        }
    }

    func submitComment() {
        guard let coll = currCollectName, let sid = store?.id else { return }
        let trimBody = commentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Auth.auth().currentUser != nil else {
            showSignInRequiredAlert = true
            return
        }
        let trimName = CommunityProfileManager.currentNicknameDisplayName().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimBody.isEmpty, !trimName.isEmpty else { return }
        
        // 檢查留言限制
        guard commentLimit.canComment else {
            showCommentLimitAlert = true
            return
        }
        
        isSubmitting = true
        commentManager.addComment(collection: coll, storeId: sid, name: trimName, body: trimBody, deviceId: deviceId) { [self] error in
            isSubmitting = false
            if let error {
                commentErrorMessage = error.localizedDescription
                return
            }
                let rewardedHours = commentLimit.recordComment()
                commentBody = ""
                commentBodyFocused = false
                
                // 顯示獎勵 Toast
                if rewardedHours > 0 {
                    rewardToastMessage = String(format: String(localized: "comment_reward_toast"), Int(rewardedHours))
                } else {
                    rewardToastMessage = String(localized: "comment_thank_you")
                }
                withAnimation(.spring(response: 0.4)) {
                    showRewardToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showRewardToast = false
                    }
                }
        }
    }
    
    func watchAdForBonus() {
        let presented = RewardedAdManager.shared.present(
            from: scenePresenter.controller,
            onReward: {
                commentLimit.grantAdBonus()
            },
            onDismiss: nil
        )
        if !presented {
            showAdNotReadyAlert = true
        }
    }
    
    // MARK: - Comments Section
    var noMapCommentsSection: some View {
        Section {
            noMapCommentsContent
        } header: {
            noMapCommentsHeader
        } footer: {
            noMapCommentsFooter
        }
    }

    var noMapCommentPinnedBar: some View {
        noMapCommentInputView
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                    }
            )
            .padding(.horizontal)
            .padding(.bottom, 10)
    }

    @ViewBuilder
    var noMapCommentsContent: some View {
        if commentManager.isLoading {
            ProgressView().frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        } else if commentManager.comments.isEmpty {
            Text(String(localized: "no_comments_yet"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
        }
        ForEach(commentManager.comments) { comment in
            noMapCommentRow(comment)
        }
        if Auth.auth().currentUser == nil {
            Label(String(localized: "restaurant_google_sign_in_to_comment"), systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
                .listRowSeparator(.hidden)
        }
    }
    
    func noMapCommentRow(_ comment: StoreComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(noMapRestaurantCommentDisplayName(comment))
                    .font(.caption.weight(.semibold))
                if commentManager.canEdit(comment) {
                    BadgeTagView(badge: badgeManager.getCurrentBadge(), compact: true)
                } else {
                    BadgeTagView(badge: storedOrCountedBadge(for: comment, globalStats: commentManager.userGlobalStats), compact: true)
                }
                if commentManager.canEdit(comment) {
                    Text(String(localized: "you"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(restaurantCommentRelativeTime(comment.updatedAt ?? comment.date))
                    Text("·").foregroundStyle(.secondary)
                    Text(comment.dateText).foregroundStyle(.secondary)
                }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if comment.isEdited {
                    Text(String(localized: "community_edited_label"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(comment.body)
                .font(.body)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if commentManager.canEdit(comment) {
                Button(role: .destructive) {
                    commentToDelete = comment
                    showDeleteConfirm = true
                } label: {
                    Label(String(localized: "delete"), systemImage: "trash")
                }

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
    
    var noMapCommentInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if Auth.auth().currentUser == nil {
                Text(String(localized: "community_google_sign_in_required_error"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField(String(localized: "textfield_comment"), text: $commentBody)
                .submitLabel(.done)
                .focused($commentBodyFocused)
                .onSubmit { commentBodyFocused = false }
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Color(.systemBackground), in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 0.8))
            noMapRestaurantCommentIdentityCard
            Button {
                submitComment()
            } label: {
                Label(String(localized: "community_send_reply"), systemImage: isSubmitting ? "clock" : "paperplane")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: Capsule())
                    .shadow(color: Color.accentColor.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(
                commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || Auth.auth().currentUser == nil
                || isSubmitting
            )
        }
        .padding(.vertical, 4)
        .alert(String(localized: "comment_post_failed_title"), isPresented: Binding(
            get: { commentErrorMessage != nil },
            set: { if !$0 { commentErrorMessage = nil } }
        )) {
            Button(String(localized: "ok"), role: .cancel) { }
        } message: {
            Text(commentErrorMessage ?? "")
        }
    }

    var noMapRestaurantCommentIdentityCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.text.rectangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 28, height: 28)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(CommunityProfileManager.currentNicknameDisplayName())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(String(localized: "community_badge_reply_detail"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            BadgeTagView(badge: badgeManager.getCurrentBadge(), compact: true)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.orange.opacity(0.16), lineWidth: 1)
                }
        }
    }
    
    var noMapCommentsHeader: some View {
        HStack {
            Text(String(format: String(localized: "comments_count"), commentManager.comments.count))
            Spacer()
            Text(String(format: String(localized: "remaining_comments_today"), commentLimit.remainingComments))
                .font(.caption2)
                .foregroundColor(commentLimit.remainingComments > 0 ? Color.secondary : Color.red)
        }
    }
    
    @ViewBuilder
    var noMapCommentsFooter: some View {
        if Auth.auth().currentUser != nil {
            Text(CommunityProfileManager.currentNicknameDisplayName())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    func noMapRestaurantCommentDisplayName(_ comment: StoreComment) -> String {
        commentManager.canEdit(comment) ? CommunityProfileManager.currentNicknameDisplayName() : comment.name
    }
    
    // MARK: - 編輯留言 Sheet
    private func noMapEditCommentSheet(_ comment: StoreComment) -> some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(store?.store ?? "")
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
                        noMapSaveEditedComment(comment)
                    }
                    .disabled(editingBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // MARK: - 儲存編輯後的留言
    private func noMapSaveEditedComment(_ comment: StoreComment) {
        let trimmed = editingBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let coll = currCollectName,
              let sid = store?.id,
              let cid = comment.id else { return }
        
        commentManager.editComment(collection: coll, storeId: sid, id: cid, newBody: trimmed) { _ in
            editingComment = nil
        }
    }

    private func noMapDeleteOwnedComment(_ comment: StoreComment) {
        guard let coll = currCollectName,
              let sid = store?.id,
              let cid = comment.id else { return }

        commentManager.deleteComment(collection: coll, storeId: sid, id: cid, deviceId: comment.deviceId) { success in
            if success {
                badgeManager.decrementComment()
            }
            commentToDelete = nil
        }
    }
    
}
