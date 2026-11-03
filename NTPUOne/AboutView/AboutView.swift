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
    @State private var adPresenter = WeakScenePresentationController()
    //about rewardAds
    @StateObject private var rewardAd = RewardedAd()
    @ObservedObject private var rewardedAdManager = RewardedAdManager.shared
    @EnvironmentObject var adFree: AdFreeService
    @State private var isReward = false
    @State private var showAdConfirm = false
    @State private var showAdNotReadyAlert = false
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    //admin
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    // 個人設定
    @AppStorage("commentNickname") private var nickname: String = ""
    @AppStorage("commentDeviceId") private var deviceId: String = ""
    @StateObject private var communityProfileManager = CommunityProfileManager()
    @State private var showOnboarding = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { AcademicConnectionView() } label: {
                        Label("學校帳號與同步", systemImage: "graduationcap")
                    }
                }
                // Admin 區塊（密碼解鎖＋專屬信箱雙重確認）
                if isAdmin, CommunityProfileManager.isPrivilegedAdminEmail {
                    Section {
                        NavigationLink {
                            AdminConsoleView()
                        } label: {
                            Label(String(localized: "admin_console"), systemImage: "shield")
                        }
                    } header: {
                        Label(String(localized: "admin_console"), systemImage: "shield")
                    }
                }

                Section {
                    Button {
                        isReward = true
                    } label: {
                        HStack {
                            Image(systemName: "megaphone")
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
                } header: {
                    Label(String(localized: "student_app_tools"), systemImage: "wrench.and.screwdriver")
                }

                Section {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label(String(localized: "show_onboarding_again"), systemImage: "sparkles.tv")
                            .foregroundStyle(.primary)
                    }

                    adPreferencesRow
                } header: {
                    Label(String(localized: "ad_preferences_section"), systemImage: "slider.horizontal.3")
                }

                Section {
                    NavigationLink {
                        FeaturesView()
                            .navigationTitle(String(localized: "feature_suggestion"))
                    } label: {
                        Label(String(localized: "feature_suggestion"), systemImage: "lightbulb")
                            .foregroundStyle(.primary)
                    }
                    
                    NavigationLink {
                        ReportBugView()
                            .navigationTitle(String(localized: "report_bug"))
                    } label: {
                        Label(String(localized: "report_bug"), systemImage: "ladybug")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Label(String(localized: "feedback_section"), systemImage: "bubble.left.and.bubble.right")
                }
                
                // MARK: - 關於
                Section {
                    NavigationLink {
                        ContactMeView()
                    } label: {
                        Label(String(localized: "contact_developer"), systemImage: "envelope")
                            .foregroundStyle(.primary)
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(String(localized: "privacy_policy"), systemImage: "hand.raised")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Label(String(localized: "about"), systemImage: "info.circle")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        AccountCenterView(
                            communityProfileManager: communityProfileManager
                        )
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel(String(localized: "account_center_accessibility"))
                }
            }
            .navigationDestination(isPresented: $isReward) {
                AddOrderView(rewardAd: rewardAd)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                FirstRunOnboardingView(autoFinishAfterAuth: false) {
                    showOnboarding = false
                }
                .interactiveDismissDisabled()
            }
            .alert(String(localized: "disable_today_banner_title"), isPresented: $showAdConfirm) {
                Button(String(localized: "cancel"), role: .cancel) { }
                Button(String(localized: "start_watching")) {
                    showRewardedAdFreeReward()
                }
            } message: {
                Text(String(localized: "watch_ad_hint"))
            }
            .alert(String(localized: "video_not_ready"), isPresented: $showAdNotReadyAlert) {
                Button(String(localized: "ok"), role: .cancel) { }
            } message: {
                Text(rewardedAdManager.remainingViews > 0 ? String(localized: "loading_ad_retry") : String(localized: "daily_view_limit_reached"))
            }
        }
        .onAppear {
            if deviceId.isEmpty { deviceId = UUID().uuidString }
            if nickname.isEmpty {
                nickname = String(format: String(localized: "community_default_user_format"), String(deviceId.prefix(4)).uppercased())
            }
            if !adFree.isAdFree {
                rewardedAdManager.preload()
            }
        }
        .background(ScenePresentationAnchor { adPresenter.controller = $0 }.frame(width: 0, height: 0))
        .communityDepartmentChooser(communityProfileManager)
    }

    @ViewBuilder
    private var adPreferencesRow: some View {
        if adFree.isAdFree {
            HStack {
                Label(String(localized: "no_banner_today"), systemImage: "checkmark.seal")
                    .foregroundStyle(.green)
                Spacer()
                Button(String(localized: "show_ads_again")) {
                    adFree.clear()
                    rewardedAdManager.preload()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else {
            Button {
                if rewardedAdManager.isLoading { return }
                showAdConfirm = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "film.stack")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "watch_ad"))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    if rewardedAdManager.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .disabled(rewardedAdManager.isLoading)
        }
    }

    private func showRewardedAdFreeReward() {
        guard rewardedAdManager.isReady, !rewardedAdManager.isLoading else {
            showAdNotReadyAlert = true
            rewardedAdManager.preload()
            return
        }

        let presented = rewardedAdManager.present(from: adPresenter.controller, onReward: {
            adFree.grantForTodayEnd()
        })

        if !presented {
            showAdNotReadyAlert = true
            rewardedAdManager.preload()
        }
    }
}

private struct AccountCenterView: View {
    @State private var loginPresenter = WeakScenePresentationController()
    @ObservedObject var communityProfileManager: CommunityProfileManager
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    var body: some View {
        List {
            Section {
                accountHeaderRow

                if isSignedIn {
                    Button(role: .destructive) {
                        communityProfileManager.signOut()
                    } label: {
                        Label(String(localized: "account_logout"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    Text(String(localized: "account_guest_sign_in_explanation"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        communityProfileManager.signInWithGoogleSchoolEmail(presenting: loginPresenter.controller)
                    } label: {
                        rowLabel(
                            title: String(localized: "account_google_login"),
                            systemImage: "person.badge.key",
                            tint: .blue
                        )
                    }
                }

            if isAdmin {
                Section(String(localized: "account_admin_section")) {
                    Text(String(localized: "you_are_admin"))
                        .foregroundStyle(.green)
                    Button(String(localized: "logout_admin")) {
                        isAdmin = false
                        CommentBadgeManager.shared.refreshBadgeForAdminStatusChange()
                    }
                    .foregroundStyle(.red)
                }
            }

                if let message = communityProfileManager.authStatusMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(String(localized: "account_center"), systemImage: "person.crop.circle")
            }

            Section {
                NavigationLink {
                    CommunityMyContentView()
                } label: {
                    rowLabel(
                        title: String(localized: "community_my_content_title"),
                        systemImage: "tray.full",
                        tint: .blue
                    )
                }

                if isSignedIn {
                    NavigationLink {
                        CommunityLikedTopicsView()
                    } label: {
                        rowLabel(
                            title: String(localized: "community_liked_topics_title"),
                            systemImage: "heart.fill",
                            tint: .red
                        )
                    }
                }

                NavigationLink {
                    CommentRewardInfoView()
                } label: {
                    HStack(spacing: 12) {
                        BadgeTagView(badge: CommentBadgeManager.shared.getCurrentBadge(), compact: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: String(localized: "total_comments_format"), CommentBadgeManager.shared.totalComments))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(String(localized: "comment_reward_system"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            } header: {
                Label(String(localized: "community_title"), systemImage: "person.2")
            }

            Section {
                NavigationLink {
                    PrivacyDataControlsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "privacy_data_controls"))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            } header: {
                Label(String(localized: "account_and_preferences"), systemImage: "gearshape")
            }
        }
        .navigationTitle(String(localized: "account_center"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isSignedIn: Bool {
        !communityProfileManager.profile.ownerUid.isEmpty
    }

    private var accountEmail: String? {
        let ownerEmail = communityProfileManager.profile.ownerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ownerEmail.isEmpty { return ownerEmail }

        let schoolEmail = communityProfileManager.profile.schoolEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !schoolEmail.isEmpty { return schoolEmail }

        return nil
    }

    private var displayPreferenceSummary: String {
        var parts: [String] = []
        if communityProfileManager.profile.showDepartment {
            parts.append(String(localized: "community_public_part_department"))
        }
        if communityProfileManager.profile.showYear {
            parts.append(String(localized: "community_public_part_year"))
        }
        if communityProfileManager.profile.showBadge {
            parts.append(String(localized: "community_public_part_badge"))
        }

        guard !parts.isEmpty else {
            return String(localized: "community_public_info_none")
        }

        return String(format: String(localized: "account_display_preferences_summary_format"), parts.joined(separator: String(localized: "community_list_separator")))
    }

    @ViewBuilder
    private var accountHeaderRow: some View {
        NavigationLink {
            CommunityProfileView(profileManager: communityProfileManager)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSignedIn ? "checkmark.seal" : "person.crop.circle")
                    .font(.title3)
                    .foregroundStyle(isSignedIn ? .green : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(CommunityProfileManager.currentAccountDisplayName())
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !isSignedIn {
                        Text(String(localized: "account_guest_status"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if isSignedIn, !communityProfileManager.profile.displayLine.isEmpty {
                        Text(communityProfileManager.profile.displayLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if isSignedIn, let accountEmail {
                        Text(accountEmail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if isSignedIn {
                        Text(displayPreferenceSummary)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .accessibilityLabel(String(localized: "account_display_preferences"))
        .background(ScenePresentationAnchor { loginPresenter.controller = $0 }.frame(width: 0, height: 0))
        .communityDepartmentChooser(communityProfileManager)
        .onAppear { communityProfileManager.syncOwnCommentCountFromServer() }
        .onChange(of: communityProfileManager.profile.ownerUid) { _ in
            communityProfileManager.syncOwnCommentCountFromServer()
        }
    }

    private func rowLabel(title: String, subtitle: String? = nil, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct PrivacyDataControlsView: View {
    @AppStorage("hasCompletedFirstRunOnboarding") private var hasCompletedFirstRunOnboarding = false
    @State private var showReshowConfirmation = false

    var body: some View {
        Form {
            Section {
                Label(String(localized: "data_controls_row_icloud"), systemImage: "icloud")
                    .foregroundStyle(.primary)
                Label(String(localized: "data_controls_row_community"), systemImage: "person.crop.circle")
                    .foregroundStyle(.primary)
                Label(String(localized: "data_controls_row_comments"), systemImage: "bubble.left")
                    .foregroundStyle(.primary)
            } header: {
                Text(String(localized: "privacy_data_controls_intro"))
            }

            Section {
                Button {
                    showReshowConfirmation = true
                } label: {
                    Label(String(localized: "data_controls_reshow_onboarding"), systemImage: "sparkles")
                }
            } header: {
                Text(String(localized: "local_data"))
            }
        }
        .navigationTitle(String(localized: "privacy_data_controls"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "reset_local_privacy_data_confirm_title"), isPresented: $showReshowConfirmation) {
            Button(String(localized: "cancel"), role: .cancel) { }
            Button(String(localized: "ok"), role: .destructive) {
                hasCompletedFirstRunOnboarding = false
            }
        } message: {
            Text(String(localized: "data_controls_reshow_confirm_message"))
        }
    }
}

#Preview {
    AboutView()
}
