//
//  AboutView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI
import SwiftData
import SafariServices
import FirebaseCore
import FirebaseFirestore
import GoogleMobileAds
import AppTrackingTransparency
import MapKit
import Firebase

struct AboutView: View {
    //about rewardAds
    @StateObject private var rewardAd = RewardedAd()
    @ObservedObject private var rewardedManager = RewardedAdManager.shared
    @EnvironmentObject var adFree: AdFreeService
    @State private var isReward = false
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    //admin
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    // 個人設定
    @AppStorage("commentNickname") private var nickname: String = ""
    @AppStorage("commentDeviceId") private var deviceId: String = ""
    @State private var pendingNickname = ""
    @State private var isEditingNickname = false
    @State private var showUpdateOldAlert = false
    @State private var isUpdatingComments = false
    @FocusState private var nicknameFieldFocused: Bool
    @StateObject private var commentUpdater = CommentManager()
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 帳號與偏好
                Section {
                    // 暱稱設定
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            if isEditingNickname {
                                TextField("暱稱", text: $pendingNickname)
                                    .focused($nicknameFieldFocused)
                                    .submitLabel(.done)
                                    .onSubmit { saveNickname() }
                            } else {
                                Text(nickname.isEmpty ? "尚未設定" : nickname)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(nickname.isEmpty ? .secondary : .primary)
                            }
                            if !deviceId.isEmpty {
                                Text("ID: #\(deviceId.prefix(4).uppercased())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if isUpdatingComments {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Button {
                                if isEditingNickname { saveNickname() }
                                else {
                                    pendingNickname = nickname
                                    isEditingNickname = true
                                    nicknameFieldFocused = true
                                }
                            } label: {
                                Image(systemName: isEditingNickname ? "checkmark.circle.fill" : "pencil.circle")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 廣告設定
                    if !isAdmin {
                        if adFree.isAdFree {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("今日無橫幅廣告")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("重置") {
                                    adFree.clear()
                                    rewardedManager.preload()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        } else {
                            Button {
                                showRewarded()
                            } label: {
                                HStack {
                                    Image(systemName: "play.rectangle.fill")
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("關閉今日橫幅廣告")
                                            .foregroundStyle(.primary)
                                        Text(rewardedManager.isLoading ? "載入中…" : "觀看 30 秒影片（剩 \(rewardedManager.remainingViews) 次）")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .disabled(rewardedManager.isLoading || !rewardedManager.isReady)
                        }
                    }
                } header: {
                    Label("帳號與偏好", systemImage: "gearshape.fill")
                } footer: {
                    Text("暱稱用於留言及活動廣播")
                }
                .alert("更新舊留言？", isPresented: $showUpdateOldAlert) {
                    Button("只更新新留言") {
                        nickname = pendingNickname
                        isEditingNickname = false
                    }
                    Button("同時更新舊留言") {
                        let newName = pendingNickname
                        nickname = newName
                        isEditingNickname = false
                        isUpdatingComments = true
                        commentUpdater.updateAllComments(deviceId: deviceId, newName: newName) { _ in
                            isUpdatingComments = false
                        }
                    }
                    Button("取消", role: .cancel) {
                        isEditingNickname = true
                        nicknameFieldFocused = true
                    }
                } message: {
                    Text("是否同時更新您過去在各餐廣的留言暱稱？")
                }
                
                // Admin 區塊
                if isAdmin {
                    Section {
                        NavigationLink {
                            AdminConsoleView()
                        } label: {
                            Label("管理後台", systemImage: "shield.fill")
                        }
                    }
                }

                // MARK: - 互動
                Section {
                    Button {
                        isReward = true
                    } label: {
                        HStack {
                            Image(systemName: "megaphone.fill")
                                .foregroundStyle(.purple)
                            Text("新增活動廣播")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    NavigationLink {
                        FeaturesView()
                            .navigationTitle("功能建議")
                    } label: {
                        Label("功能建議", systemImage: "lightbulb.fill")
                            .foregroundStyle(.primary)
                    }
                    
                    NavigationLink {
                        ReportBugView()
                            .navigationTitle("回報錯誤")
                    } label: {
                        Label("回報問題", systemImage: "ladybug.fill")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Label("互動", systemImage: "bubble.left.and.bubble.right.fill")
                } footer: {
                    Text("歡迎提供建議或回報問題")
                }
                
                // MARK: - 關於
                Section {
                    NavigationLink {
                        ContactMeView()
                    } label: {
                        Label("聯繫開發者", systemImage: "envelope.fill")
                            .foregroundStyle(.primary)
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("隱私權政策", systemImage: "hand.raised.fill")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Label("關於", systemImage: "info.circle.fill")
                }
                
                // 原生廣告（放在最底部，不干擾功能流程）
                if !adFree.isAdFree {
                    Section {
                        NativeAdSectionView(style: .compact)
                            .frame(height: 140)
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .navigationTitle("關於")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { rewardedManager.preload() }
            .navigationDestination(isPresented: $isReward) {
                AddOrderView(rewardAd: rewardAd)
            }
            .onChange(of: isReward) { newValue in
                if !newValue {
                    rewardedManager.preload()
                }
            }
        }
        .onAppear {
            if deviceId.isEmpty { deviceId = UUID().uuidString }
            if nickname.isEmpty {
                nickname = "使用者\(String(deviceId.prefix(4)).uppercased())"
            }
        }
    }
    private func saveNickname() {
        let newName = pendingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != nickname else {
            isEditingNickname = false
            return
        }
        if nickname.isEmpty {
            nickname = newName
            isEditingNickname = false
        } else {
            showUpdateOldAlert = true
        }
    }

    private func showRewarded() {
        rewardedManager.present {
            adFree.grantForTodayEnd()
        } onDismiss: {
        }
    }
}

#Preview {
    AboutView()
}
