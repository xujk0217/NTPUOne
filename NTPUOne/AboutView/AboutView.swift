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
    
    var body: some View {
        NavigationStack {
            List {
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
//                // 廣告標記
//                Section {
//                    NativeAdBoxView(
//                        style: .compact(media: 120),
//                        height: $adHeight
//                    )
//                    .frame(height: adHeight)
//                    .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
//                    .listRowSeparator(.hidden)
//                    .listRowBackground(Color.white)
//                    .padding(.horizontal, 8)
//                } header: {
//                    Text("廣告")
//                }
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
            startTimer()
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
