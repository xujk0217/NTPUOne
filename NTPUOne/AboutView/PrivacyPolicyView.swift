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
                    Text("學校帳密只送往校方登入站，並依你選擇的連結範圍存於本機 Keychain。Moodle 驗證後會保存 token；若使用相同的學校帳密，密碼作為校務登入資料保存在本機；不將學校憑證上傳 Firebase、CloudKit 或提供給廣告服務。")
                    Text("校務成績、排名及畢業進度報表使用本機受保護快取並排除備份；Moodle 成績在查看頁面或你啟用的 AI 資料請求時暫存。匯入的課程與作業待辦沿用原有私人 iCloud 同步；啟用 AI 資料後，所選內容可能傳送至 NTPU AI。")
                    Text("可在「我的 → 學校帳號與同步」解除本機連結，刪除該連結憑證與快取中的個人報表，保留已匯入的課表及待辦。App 內 Moodle 網頁使用獨立、非持久工作階段；關閉 App、切換帳號或解除連結後不再沿用該瀏覽工作階段。")
                }

                Section("NTPU AI 與 App 資料") {
                    Text("啟用進入 App 提醒後，若 NTPU AI 已登入，每次開啟 App 或從背景回來會整理一次公開天氣及餐廳資訊交由 AI 產生簡短提醒；同次進入不重複提醒。每輪對話會提供台北時區的目前日期、星期與時間。已允許 App 資料時才加入近期課程與待辦；App 資料、成績授權與提醒開關按 App 帳號保存在本機並沿用後續聊天，可在 AI 資料設定關閉。此功能不需要 iOS 通知權限，亦不在背景定時推播。")
                    Text("AI 資料設定提供個別開關：手機及 iCloud 課表、備忘錄預設開啟；Moodle、學生資訊系統及成績預設關閉。可以隨時在 AI 工具列的資料設定調整；成績還需要開啟所屬來源。開啟後相關資料會依問題傳送至校方 NTPU AI。")
                    Text("使用網路搜尋時，只有你輸入並確認的搜尋文字會送給第三方 Exa；結果與問題會送給校方 NTPU AI。你可以要求刪除這次由 App 建立的校方對話，但不會清除帳號長期記憶。")
                    Text("AI 可以提出課表或備忘錄變更建議。App 會先顯示可編輯的預覽；只有你確認儲存或完成刪除確認才會變更本機及已啟用的 iCloud 資料。")
                    Text("聊天問題直接傳送至校方 NTPU AI。啟用 App 資料後，AI 會先判斷來源，手機再提供限量的課表、備忘錄、修課、Moodle、公告、天氣或其他已開放來源；也可能提供符合問題的公開餐廳評論、公告圖片與本機通知設定；個人成績、排名及畢業資料須另行啟用。")
                    Text("問題、分類結果與提供的資料可能依校方政策保存在其服務。關閉資料授權會中止請求，並讓後續開啟新對話；不會刪除校方已保存的紀錄。學校帳密、Cookie、Moodle token 與裝置識別碼不作為 AI 資料集。")
                    Text("點選使用已儲存的學校帳號登入 NTPU AI 時，App 僅在核對過的校方 HTTPS 登入表單填入本機 Keychain 帳密，傳送至 saml2.ntpu.edu.tw。帳密不加入 AI 對話或 App 資料快照；遇到驗證碼、額外驗證或頁面變更時改由你操作。")
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
