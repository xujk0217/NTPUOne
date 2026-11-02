//
//  PrivacyPolicyView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @EnvironmentObject var adFree: AdFreeService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "privacy_policy_intro"))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(String(localized: "privacy_policy_effective_date"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                PrivacyPolicySection(
                    titleKey: "privacy_policy_data_title",
                    itemKeys: [
                        "privacy_policy_data_dashboard",
                        "privacy_policy_data_community_identity",
                        "privacy_policy_data_school_verification",
                        "privacy_policy_data_notifications",
                        "privacy_policy_data_local_storage"
                    ]
                )

                PrivacyPolicySection(
                    titleKey: "privacy_policy_services_title",
                    itemKeys: [
                        "privacy_policy_services_firebase",
                        "privacy_policy_services_ads",
                        "privacy_policy_services_analytics",
                        "privacy_policy_services_crashlytics"
                    ]
                )

                Section("校務與 Moodle 連結") {
                    Text("學校帳密只送往校方登入站，並依你選擇的連結範圍存於本機 Keychain。Moodle 驗證後只保存 token，不保存 Moodle 密碼；不將學校憑證上傳 Firebase、CloudKit 或提供給廣告服務。")
                    Text("校務成績、排名及畢業進度報表只作本機受保護快取並排除備份；Moodle 成績只在查看頁面時暫存。匯入的課程與作業待辦沿用原有私人 iCloud 同步，私人筆記不會傳回校方。")
                    Text("可在「我的 → 學校帳號與同步」解除本機連結，刪除該連結憑證與快取中的個人報表，保留已匯入的課表及待辦。App 內 Moodle 網頁使用獨立、非持久工作階段；關閉 App、切換帳號或解除連結後不再沿用該瀏覽工作階段。")
                }

                PrivacyPolicySection(
                    titleKey: "privacy_policy_controls_title",
                    itemKeys: [
                        "privacy_policy_controls_local_reset",
                        "privacy_policy_controls_remote_cleanup",
                        "privacy_policy_controls_public_content",
                        "privacy_policy_controls_uninstall"
                    ]
                )

                Section {
                    NavigationLink {
                        PrivacyDataControlsView()
                    } label: {
                        Label(String(localized: "privacy_data_controls"), systemImage: "lock.shield")
                    }

                    Link("AdMob / Google Privacy", destination: URL(string: "https://policies.google.com/privacy")!)
                    Link("Google Analytics for Firebase", destination: URL(string: "https://firebase.google.com/policies/analytics")!)
                    Link("Firebase Privacy and Security", destination: URL(string: "https://firebase.google.com/support/privacy/")!)

                    NavigationLink {
                        ContactMeView()
                    } label: {
                        Label(String(localized: "contact_developer"), systemImage: "envelope")
                    }
                } header: {
                    Text(String(localized: "privacy_policy_links_title"))
                }

                if !adFree.isAdFree {
                    Section {
                        BannerAdView()
                            .frame(height: 50)
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .navigationTitle(String(localized: "privacy_policy"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PrivacyPolicySection: View {
    let titleKey: LocalizedStringResource
    let itemKeys: [LocalizedStringResource]

    var body: some View {
        Section {
            ForEach(Array(itemKeys.enumerated()), id: \.offset) { _, itemKey in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(String(localized: itemKey))
                        .foregroundStyle(.primary)
                }
                .font(.body)
            }
        } header: {
            Text(String(localized: titleKey))
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
