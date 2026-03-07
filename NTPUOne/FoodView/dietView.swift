//
//  dietView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/1.
//
import SwiftUI
import MapKit
import SafariServices
import FirebaseFirestore
import FirebaseFirestoreSwift

@available(iOS 17.0, *)
struct dietView: View {
    @State var store: FDetail
    let currCollectName: String?
    @EnvironmentObject var adFree: AdFreeService

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
    
    // 留言限制 Alert
    @State private var showCommentLimitAlert = false
    @State private var showAdNotReadyAlert = false

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
                    Button {
                        if !isStar {
                            addStar()
                        }
                    } label: {
                        HStack {
                            Text("\(Int(store.starNum))")
                                .font(.title.bold())
                            Image(systemName: isStar ? "star.fill" : "star")
                            Divider()
                            Text(String(localized: "recommend_hint"))
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading) {
                        Text(store.store)
                            .font(.title2.bold())
                        HStack {
                            Image(systemName: "house")
                            Text(": \(store.address)")
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
                } footer: {
                    Text(String(localized: "tap_to_open_map"))
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
            .scrollContentBackground(.hidden)
            .background(Color.gray.opacity(0.1))
            .navigationTitle(store.store)
            .onAppear {
                if deviceId.isEmpty { deviceId = UUID().uuidString }
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
                if commentLimit.canWatchAdForBonus {
                    Button(String(localized: "watch_ad")) {
                        watchAdForBonus()
                    }
                    Button(String(localized: "cancel"), role: .cancel) { }
                } else {
                    Button(String(localized: "ok"), role: .cancel) { }
                }
            } message: {
                if commentLimit.canWatchAdForBonus {
                    Text(String(format: String(localized: "comment_limit_message"), commentLimit.remainingAdViews))
                } else {
                    Text(String(localized: "comment_limit_all_used"))
                }
            }
            .alert(String(localized: "ad_not_ready"), isPresented: $showAdNotReadyAlert) {
                Button(String(localized: "ok"), role: .cancel) { }
            }
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
            commentInputView
        } header: {
            commentsHeader
        } footer: {
            commentsFooter
        }
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
        if nickname.isEmpty {
            Label(String(localized: "set_nickname_to_comment"), systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
                .listRowSeparator(.hidden)
        }
    }
    
    private func commentRow(_ comment: StoreComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption2)
                    .foregroundStyle(comment.deviceId == deviceId ? .orange : .secondary)
                Text(comment.name)
                    .font(.caption.bold())
                    .foregroundStyle(comment.deviceId == deviceId ? .orange : .secondary)
                if !comment.deviceId.isEmpty {
                    Text("#\(comment.deviceId.prefix(4))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if comment.deviceId == deviceId {
                    Text(String(localized: "you"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(comment.dateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(comment.body)
                .font(.body)
        }
        .padding(.vertical, 3)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if comment.deviceId == deviceId {
                Button(role: .destructive) {
                    if let coll = currCollectName, let cid = comment.id {
                        commentManager.deleteComment(collection: coll, storeId: store.id!, id: cid)
                    }
                } label: {
                    Label(String(localized: "delete"), systemImage: "trash")
                }
            }
        }
    }
    
    private var commentInputView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(String(localized: "textfield_comment"), text: $commentBody, axis: .vertical)
                .lineLimit(1...4)
                .focused($commentBodyFocused)
                .onSubmit { }
            Button {
                submitComment()
            } label: {
                let isDisabled = commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isSubmitting
                Image(systemName: isSubmitting ? "clock" : "paperplane.fill")
                    .foregroundStyle(isDisabled ? Color.secondary : Color.orange)
            }
            .buttonStyle(.plain)
            .disabled(
                commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || isSubmitting
            )
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
        if !nickname.isEmpty {
            Text(nickname)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    func openURL(_ urlString: String) {
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url),
           let topViewController = UIApplication.shared.windows.first?.rootViewController {
            let safariVC = SFSafariViewController(url: url)
            topViewController.present(safariVC, animated: true, completion: nil)
        }
    }

    func addStar() {
        isStar = true
        let db = Firestore.firestore()
        let docRef = db.collection(currCollectName!).document(store.id!)

        docRef.getDocument { document, error in
            guard let document, document.exists,
                  var storeData = try? document.data(as: FDetail.self)
            else { return }

            storeData.starNum += 1

            do {
                try docRef.setData(from: storeData) { error in
                    if let error = error {
                        print("❌ 更新失敗: \(error)")
                        return
                    }

                    // ✅ 再次抓回更新後的資料
                    docRef.getDocument { newDoc, error in
                        guard let newDoc,
                              newDoc.exists,
                              let updatedStore = try? newDoc.data(as: FDetail.self)
                        else { return }

                        DispatchQueue.main.async {
                            store.starNum = updatedStore.starNum
                        }
                    }
                }
            } catch {
                print("❌ setData 錯誤: \(error)")
            }
        }
    }
    func submitComment() {
        guard let coll = currCollectName, let sid = store.id else { return }
        let trimBody = commentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimBody.isEmpty, !trimName.isEmpty else { return }
        
        // 檢查留言限制
        guard commentLimit.canComment else {
            showCommentLimitAlert = true
            return
        }
        
        isSubmitting = true
        commentManager.addComment(collection: coll, storeId: sid, name: trimName, body: trimBody, deviceId: deviceId) { [self] success in
            isSubmitting = false
            if success {
                commentLimit.recordComment()
                commentBody = ""
                commentBodyFocused = false
            }
        }
    }
    
    func watchAdForBonus() {
        let presented = RewardedAdManager.shared.present(
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
    let store: FDetail?
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
    
    // 留言限制 Alert
    @State private var showCommentLimitAlert = false
    @State private var showAdNotReadyAlert = false

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
                Section{
                    Button {
                        if isStar == false{
                            addStar()
                        }
                    } label: {
                        HStack{
                            HStack {
                                Text("\(Int(store!.starNum))")
                                    .font(.title.bold())
                                if isStar == true{
                                    Image(systemName: "star.fill")
                                }else{
                                    Image(systemName: "star")
                                }
                                Divider()
                                Text(String(localized: "recommend_hint"))
                            }
                        }
                    }
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
                } footer: {
                    Text(String(localized: "tap_to_open_map"))
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
            }.scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.1))
            .navigationTitle(store!.store)
            .onAppear {
                if deviceId.isEmpty { deviceId = UUID().uuidString }
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
                if commentLimit.canWatchAdForBonus {
                    Button(String(localized: "watch_ad")) {
                        watchAdForBonus()
                    }
                    Button(String(localized: "cancel"), role: .cancel) { }
                } else {
                    Button(String(localized: "ok"), role: .cancel) { }
                }
            } message: {
                if commentLimit.canWatchAdForBonus {
                    Text(String(format: String(localized: "comment_limit_message"), commentLimit.remainingAdViews))
                } else {
                    Text(String(localized: "comment_limit_all_used"))
                }
            }
            .alert(String(localized: "ad_not_ready"), isPresented: $showAdNotReadyAlert) {
                Button(String(localized: "ok"), role: .cancel) { }
            }
        }
    }
}

extension noMapDietView{
    func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                // 打开 SafariViewController
                if let topViewController = UIApplication.shared.windows.first?.rootViewController {
                    let safariVC = SFSafariViewController(url: url)
                    topViewController.present(safariVC, animated: true, completion: nil)
                }
            } else {
                print("Cannot open URL: \(urlString)")
            }
        }
    }
    
    func addStar(){
        isStar = true
        let db = Firestore.firestore()
            let documentReference =
        db.collection(currCollectName!).document(store!.id!)
            documentReference.getDocument { document, error in
                guard let document,
                      document.exists,
                      var store = try? document.data(as: FDetail.self)
                else {
                    return
                }
                store.starNum += 1
                do {
                    try documentReference.setData(from: store)
                } catch {
                    print(error)
                }
                
            }
    }

    func submitComment() {
        guard let coll = currCollectName, let sid = store?.id else { return }
        let trimBody = commentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimBody.isEmpty, !trimName.isEmpty else { return }
        
        // 檢查留言限制
        guard commentLimit.canComment else {
            showCommentLimitAlert = true
            return
        }
        
        isSubmitting = true
        commentManager.addComment(collection: coll, storeId: sid, name: trimName, body: trimBody, deviceId: deviceId) { [self] success in
            isSubmitting = false
            if success {
                commentLimit.recordComment()
                commentBody = ""
                commentBodyFocused = false
            }
        }
    }
    
    func watchAdForBonus() {
        let presented = RewardedAdManager.shared.present(
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
            noMapCommentInputView
        } header: {
            noMapCommentsHeader
        } footer: {
            noMapCommentsFooter
        }
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
        if nickname.isEmpty {
            Label(String(localized: "set_nickname_to_comment"), systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
                .listRowSeparator(.hidden)
        }
    }
    
    func noMapCommentRow(_ comment: StoreComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption2)
                    .foregroundStyle(comment.deviceId == deviceId ? .orange : .secondary)
                Text(comment.name)
                    .font(.caption.bold())
                    .foregroundStyle(comment.deviceId == deviceId ? .orange : .secondary)
                if !comment.deviceId.isEmpty {
                    Text("#\(comment.deviceId.prefix(4))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if comment.deviceId == deviceId {
                    Text(String(localized: "you"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(comment.dateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(comment.body)
                .font(.body)
        }
        .padding(.vertical, 3)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if comment.deviceId == deviceId {
                Button(role: .destructive) {
                    if let coll = currCollectName,
                       let sid = store?.id,
                       let cid = comment.id {
                        commentManager.deleteComment(collection: coll, storeId: sid, id: cid)
                    }
                } label: {
                    Label(String(localized: "delete"), systemImage: "trash")
                }
            }
        }
    }
    
    var noMapCommentInputView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(String(localized: "textfield_comment"), text: $commentBody, axis: .vertical)
                .lineLimit(1...4)
                .focused($commentBodyFocused)
                .onSubmit { }
            Button {
                submitComment()
            } label: {
                let isDisabled = commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isSubmitting
                Image(systemName: isSubmitting ? "clock" : "paperplane.fill")
                    .foregroundStyle(isDisabled ? Color.secondary : Color.orange)
            }
            .buttonStyle(.plain)
            .disabled(
                commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || isSubmitting
            )
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
        if !nickname.isEmpty {
            Text(nickname)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
}

