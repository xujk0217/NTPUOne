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
                                TextField(String(localized: "nickname"), text: $pendingNickname)
                                    .focused($nicknameFieldFocused)
                                    .submitLabel(.done)
                                    .onSubmit { saveNickname() }
                            } else {
                                Text(nickname.isEmpty ? String(localized: "nickname") : nickname)
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
                    
                    // 評論獎勵系統（放在暱稱下方）
                    NavigationLink {
                        CommentRewardInfoView()
                    } label: {
                        HStack(spacing: 12) {
                            BadgeTagView(badge: CommentBadgeManager.shared.getCurrentBadge(), compact: false)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "comment_reward_system"))
                                    .foregroundStyle(.primary)
                                Text(String(format: String(localized: "total_comments_format"), CommentBadgeManager.shared.totalComments))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // 廣告設定
                    if !isAdmin {
                        if adFree.isAdFree {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text(String(localized: "no_banner_today"))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(String(localized: "reset")) {
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
                                        Text(String(localized: "watch_30s_no_banner"))
                                            .foregroundStyle(.primary)
                                        Text(rewardedManager.isLoading ? String(localized: "loading") : String(localized: "watch_30s_remaining \(rewardedManager.remainingViews)"))
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
                    Label(String(localized: "account_and_preferences"), systemImage: "gearshape.fill")
                } footer: {
                    Text(String(localized: "nickname"))
                }
                .alert(String(localized: "alert_update_old_comments"), isPresented: $showUpdateOldAlert) {
                    Button(String(localized: "update_new_comments_only")) {
                        nickname = pendingNickname
                        isEditingNickname = false
                    }
                    Button(String(localized: "update_old_comments_too")) {
                        let newName = pendingNickname
                        nickname = newName
                        isEditingNickname = false
                        isUpdatingComments = true
                        commentUpdater.updateAllComments(deviceId: deviceId, newName: newName) { _ in
                            isUpdatingComments = false
                        }
                    }
                    Button(String(localized: "cancel"), role: .cancel) {
                        isEditingNickname = true
                        nicknameFieldFocused = true
                    }
                } message: {
                    Text(String(localized: "alert_update_old_comments"))
                }
                
                // Admin 區塊
                if isAdmin {
                    Section {
                        NavigationLink {
                            AdminConsoleView()
                        } label: {
                            Label(String(localized: "admin_console"), systemImage: "shield.fill")
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
                            Text(String(localized: "navigation_add_announcement"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    NavigationLink {
                        FeaturesView()
                            .navigationTitle(String(localized: "feature_suggestion"))
                    } label: {
                        Label(String(localized: "feature_suggestion"), systemImage: "lightbulb.fill")
                            .foregroundStyle(.primary)
                    }
                    
                    NavigationLink {
                        ReportBugView()
                            .navigationTitle(String(localized: "report_bug"))
                    } label: {
                        Label(String(localized: "report_bug"), systemImage: "ladybug.fill")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Label(String(localized: "interaction"), systemImage: "bubble.left.and.bubble.right.fill")
                } footer: {
                    Text(String(localized: "feature_suggestion"))
                }
                
                // MARK: - 關於
                Section {
                    NavigationLink {
                        ContactMeView()
                    } label: {
                        Label(String(localized: "contact_developer"), systemImage: "envelope.fill")
                            .foregroundStyle(.primary)
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(String(localized: "privacy_policy"), systemImage: "hand.raised.fill")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Label(String(localized: "about"), systemImage: "info.circle.fill")
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
            .navigationTitle(String(localized: "about"))
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
