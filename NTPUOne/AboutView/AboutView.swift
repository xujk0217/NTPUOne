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
import UserNotifications

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
    @AppStorage("hasCompletedFirstRunOnboarding") private var hasCompletedFirstRunOnboarding = false

    // 個人設定
    @AppStorage("commentNickname") private var nickname: String = ""
    @AppStorage("commentDeviceId") private var deviceId: String = ""
    @StateObject private var communityProfileManager = CommunityProfileManager()
    @State private var showOnboarding = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 帳號與偏好
                Section {
                    NavigationLink {
                        CommunityProfileView(profileManager: communityProfileManager)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.text.rectangle.fill")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "community_profile_title"))
                                    .foregroundStyle(.primary)
                                Text(String(localized: "community_profile_subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        CommunityMyContentView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tray.full.fill")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "community_my_content_title"))
                                    .foregroundStyle(.primary)
                                Text(String(localized: "community_my_content_subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // 評論獎勵系統（放在交流身份下方）
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

                    NavigationLink {
                        PrivacyDataControlsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "privacy_data_controls"))
                                    .foregroundStyle(.primary)
                                Text(String(localized: "privacy_data_controls_subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        hasCompletedFirstRunOnboarding = false
                        showOnboarding = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "show_onboarding_again"))
                                    .foregroundStyle(.primary)
                                Text(String(localized: "show_onboarding_again_subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .accessibilityLabel(String(localized: "show_onboarding_again_accessibility"))

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
                                        Text(rewardedManager.isLoading ? String(localized: "loading") : String(format: String(localized: "watch_30s_remaining %lld"), rewardedManager.remainingViews))
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
                    Text(String(localized: "my_center_account_footer"))
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
                        NewStudentChecklistView()
                    } label: {
                        Label(String(localized: "new_student_checklist_title"), systemImage: "checklist.checked")
                            .foregroundStyle(.primary)
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
                    Label(String(localized: "my"), systemImage: "person.crop.circle.fill")
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
            .navigationTitle(String(localized: "my"))
            .navigationBarTitleDisplayMode(.large)
            .onAppear { rewardedManager.preload() }
            .fullScreenCover(isPresented: $showOnboarding) {
                FirstRunOnboardingView {
                    hasCompletedFirstRunOnboarding = true
                    showOnboarding = false
                }
                .interactiveDismissDisabled()
            }
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
                nickname = String(format: String(localized: "community_default_user_format"), String(deviceId.prefix(4)).uppercased())
            }
        }
    }
    private func showRewarded() {
        rewardedManager.present {
            adFree.grantForTodayEnd()
        } onDismiss: {
        }
    }
}

struct PrivacyDataControlsView: View {
    @AppStorage("communityDeviceSecret") private var deviceSecret: String = ""
    @AppStorage("hasCompletedFirstRunOnboarding") private var hasCompletedFirstRunOnboarding = false

    @State private var showLocalResetConfirmation = false
    @State private var showRemoteDeleteConfirmation = false
    @State private var isDeletingRemoteData = false
    @State private var statusMessage: String?

    private let communityFunctions = CommunityContentFunctionsService()

    var body: some View {
        Form {
            Section {
                Label(String(localized: "privacy_data_controls_intro"), systemImage: "lock.shield.fill")
                    .foregroundStyle(.primary)
                Text(String(localized: "privacy_data_controls_intro_detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    showLocalResetConfirmation = true
                } label: {
                    Label(String(localized: "reset_local_privacy_data"), systemImage: "trash.fill")
                }
                .accessibilityLabel(String(localized: "reset_local_privacy_data_accessibility"))
            } header: {
                Text(String(localized: "local_data"))
            } footer: {
                Text(String(localized: "reset_local_privacy_data_footer"))
            }

            Section {
                Button(role: .destructive) {
                    showRemoteDeleteConfirmation = true
                } label: {
                    if isDeletingRemoteData {
                        HStack {
                            ProgressView()
                            Text(String(localized: "remote_delete_in_progress"))
                        }
                    } else {
                        Label(String(localized: "request_remote_device_cleanup"), systemImage: "icloud.slash.fill")
                    }
                }
                .disabled(isDeletingRemoteData || deviceSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel(String(localized: "request_remote_device_cleanup_accessibility"))
            } header: {
                Text(String(localized: "remote_private_data"))
            } footer: {
                Text(deviceSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "remote_cleanup_no_device_secret") : String(localized: "remote_cleanup_footer"))
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "privacy_data_controls"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "reset_local_privacy_data_confirm_title"), isPresented: $showLocalResetConfirmation) {
            Button(String(localized: "cancel"), role: .cancel) { }
            Button(String(localized: "reset_local_privacy_data_confirm_button"), role: .destructive) {
                resetLocalData()
            }
        } message: {
            Text(String(localized: "reset_local_privacy_data_confirm_message"))
        }
        .alert(String(localized: "remote_cleanup_confirm_title"), isPresented: $showRemoteDeleteConfirmation) {
            Button(String(localized: "cancel"), role: .cancel) { }
            Button(String(localized: "remote_cleanup_confirm_button"), role: .destructive) {
                requestRemoteCleanup()
            }
        } message: {
            Text(String(localized: "remote_cleanup_confirm_message"))
        }
    }

    private func resetLocalData() {
        let defaults = UserDefaults.standard
        Self.localResetKeys.forEach { defaults.removeObject(forKey: $0) }
        hasCompletedFirstRunOnboarding = false
        removePendingCommunityNotifications()
        statusMessage = String(localized: "local_privacy_data_reset_done")
    }

    private func requestRemoteCleanup() {
        let currentDeviceSecret = deviceSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentDeviceSecret.isEmpty else {
            statusMessage = String(localized: "remote_cleanup_no_device_secret")
            return
        }

        isDeletingRemoteData = true
        statusMessage = nil
        communityFunctions.deleteCommunityDeviceData(deviceSecret: currentDeviceSecret) { error in
            DispatchQueue.main.async {
                isDeletingRemoteData = false
                if let error {
                    statusMessage = String(format: String(localized: "remote_cleanup_failed_format"), error.localizedDescription)
                } else {
                    statusMessage = String(localized: "remote_cleanup_requested_done")
                }
            }
        }
    }

    private func removePendingCommunityNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("community.topic.") || $0.hasPrefix("community.reply.") }
            guard !identifiers.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private static let localResetKeys = [
        "hasCompletedFirstRunOnboarding",
        "commentNickname",
        "commentDeviceId",
        "communityDeviceSecret",
        "communitySchoolEmail",
        "communityDepartment",
        "communityEntryYear",
        "communityShowDepartment",
        "communityShowYear",
        "communityShowBadge",
        "communityOwnerUid",
        "communityOwnerEmail",
        "communityCategorySubscriptions",
        "communityTopicSubscriptions",
        "communityNotificationLastRefreshAt",
        "communityNotificationCategoryBaselines",
        "communityNotificationTopicBaselines",
        "communityNotificationSeenTopicIDs",
        "communityNotificationSeenReplyIDsByTopic"
    ]
}

#Preview {
    AboutView()
}
