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
    //準備RewardedAd使用
    @StateObject private var rewardAd = RewardedAd()
    @EnvironmentObject var adFree: AdFreeService
    @State private var isReward = false
    
    @State private var isLoading = false
    private let helper = RewardedAdHelper()
    
    private let rewardedUnitID = "ca-app-pub-4105005748617921/1893622165"
    
    @State private var remainingTime = 0
    private let rewardWaitTime = 5 // 等待时间
    
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
                // 個人設定
                Section {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.orange)
                        if isEditingNickname {
                            TextField("暱稱", text: $pendingNickname)
                                .focused($nicknameFieldFocused)
                                .submitLabel(.done)
                                .onSubmit { saveNickname() }
                        } else {
                            Text(nickname.isEmpty ? "尚未設定" : nickname)
                                .foregroundStyle(nickname.isEmpty ? .secondary : .primary)
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
                                Image(systemName: isEditingNickname ? "checkmark.circle.fill" : "pencil")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    if !deviceId.isEmpty {
                        Text("裝置識別碼：#\(deviceId.prefix(4).uppercased())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("個人設定")
                } footer: {
                    Text("暱稱用於留言及活動廣播，更改後可選擇是否同步更新舊留言")
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

                if isAdmin {
                    Section{
                        NavigationLink{
                            AdminConsoleView()
                        } label: {
                            Text("Admin page")
                        }
                    } header: {
                        Text("Admin")
                    }
                }else{
                    Section(header: Text("消除廣告")) {
                        if adFree.isAdFree {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                Text("今天已無橫幅廣告")
                                Spacer()
                                Button(role: .destructive) {
                                    adFree.clear()
                                    preloadRewardedIfNeeded()
                                } label: {
                                    Text("重置（我想看廣告）")
                                }
                            }
                        } else {
                            Button {
                                showRewarded()
                            } label: {
                                HStack {
                                    Image(systemName: "film.stack")
                                    Text(isLoading ? "載入中…" : "看 30 秒影片，今日關閉橫幅廣告")
                                }
                            }
                            .disabled(isLoading)
                        }
                    }
                }
                Section {
                    VStack {
                        Button {
                            //                            let adShown = rewardAd.showAd {
                            isReward = true
                            //                            }
                            //                            if !adShown {
                            //                                print("Ad was not ready to be shown.")
                            //                            }
                        } label: {
                            VStack {
                                Text("新增活動廣播")
                            }
                        }
                        //                        .disabled(!rewardAd.canShowAd || !rewardAd.isEligibleForReward)
                        //                            .onAppear {
                        //                                self.rewardAd.load()
                        //                                rewardAd.startTimer()
                        //                            }
                        //                            .onDisappear {
                        //                                rewardAd.cancelTimer()
                        //                            }
                    }
                }  header: {
                    Text("活動廣播")
                } footer: {
                    VStack(alignment: .leading) {
                        //                        if !rewardAd.canShowAd {
                        //                            Text("廣告載入中...")
                        //                                .foregroundColor(.red)
                        //                        } else if !rewardAd.isEligibleForReward {
                        //                            Text("廣告載入中...（約5秒)")
                        //                                .foregroundColor(.red)
                        //                        }
                    }
                }
                Section {
                    NavigationLink {
                        FeaturesView()
                            .navigationTitle("功能建議")
                    } label: {
                        Text("Features suggestion")
                    }
                    NavigationLink {
                        ReportBugView()
                            .navigationTitle("回報錯誤")
                    } label: {
                        Text("Report Bugs")
                    }
                } header: {
                    Text("suggesstion & Report")
                } footer: {
                    Text("歡迎回報～")
                }
                Section {
                    NavigationLink {
                        ContactMeView()
                    } label: {
                        Text("Contact me")
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Text("Privacy Policy")
                    }
                } header: {
                    Text("Me")
                }
            }
            .navigationTitle("About")
            .onAppear { preloadRewardedIfNeeded() }
            .navigationDestination(isPresented: $isReward) {
                AddOrderView(rewardAd: rewardAd)
            }
            .onChange(of: isReward) { newValue in
                if !newValue {
                    startTimer()
                }
            }
            if !adFree.isAdFree{
                // 廣告標記
                Section {
                    BannerAdView()
                        .frame(height: 50)
                }
            }
        }
        .onAppear {
            if deviceId.isEmpty { deviceId = UUID().uuidString }
            if nickname.isEmpty {
                nickname = "使用者\(String(deviceId.prefix(4)).uppercased())"
            }
            startTimer()
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

    private func startTimer() {
        remainingTime = rewardWaitTime
        rewardAd.canShowAd = false
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            remainingTime -= 1
            if remainingTime <= 0 {
                rewardAd.canShowAd = true
                timer.invalidate()
            }
        }
    }
    private func preloadRewardedIfNeeded() {
        guard !adFree.isAdFree else { return }
        isLoading = true
        helper.load(adUnitID: rewardedUnitID) { _ in
            DispatchQueue.main.async { self.isLoading = false }
        }
    }

    private func showRewarded() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { return }

        helper.present(from: root, onReward: {
            adFree.grantForTodayEnd()
        }, onDismiss: {
        })
    }
}

#Preview {
    AboutView()
}
