//
//  RewardedAdHelper.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/27.
//

import UIKit
import GoogleMobileAds
import SwiftUI
import Combine

/// 統一的獎勵式廣告管理器
/// - 自帶預載、過期重載（1 小時）、失敗指數退避重試（最多 3 次）
/// - 頻率控制：每天最多觀看 5 次
@MainActor
final class RewardedAdManager: NSObject, ObservableObject, GADFullScreenContentDelegate {
    static let shared = RewardedAdManager()

    // MARK: - 設定
    private let adUnitID = "ca-app-pub-4105005748617921/1893622165"
    // 測試 ID：
    // private let adUnitID = "ca-app-pub-3940256099942544/1712485313"

    private let maxDailyViews = 5
    private let adExpiryInterval: TimeInterval = 3600  // 廣告載入後 1 小時視為過期
    private let maxRetry = 3

    // MARK: - 狀態
    @Published private(set) var isReady: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var remainingViews: Int = 5

    private var rewardedAd: GADRewardedAd?
    private var loadedAt: Date?
    private var retryCount = 0
    private var onReward: (() -> Void)?
    private var onDismiss: (() -> Void)?

    // 頻率控制
    @AppStorage("rewardedViewCount") private var viewCount: Int = 0
    @AppStorage("rewardedViewDate") private var viewDateTs: Double = 0

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        resetDailyCountIfNeeded()
        remainingViews = max(0, maxDailyViews - viewCount)
    }

    // MARK: - 公開方法

    /// 預載廣告（若尚未載入或已過期）
    func preload() {
        guard GlobalFeatureSettings.shared.adsEnabled, !isLoading else { return }
        // 若已有廣告且未過期，不重載
        if rewardedAd != nil, let loadedAt, Date().timeIntervalSince(loadedAt) < adExpiryInterval {
            return
        }
        loadAd()
    }

    /// 顯示廣告
    /// - Parameters:
    ///   - onReward: 用戶成功觀看獲得獎勵時的回調
    ///   - onDismiss: 廣告關閉後的回調（不論是否獲獎）
    /// - Returns: 是否成功呈現
    @discardableResult
    func present(from presenter: UIViewController?, onReward: @escaping () -> Void, onDismiss: (() -> Void)? = nil) -> Bool {
        guard GlobalFeatureSettings.shared.adsEnabled else { return false }
        resetDailyCountIfNeeded()
        guard viewCount < maxDailyViews else {
            print("⚠️ Rewarded: 已達每日上限 \(maxDailyViews) 次")
            return false
        }

        // 若已過期先清掉
        if let loadedAt, Date().timeIntervalSince(loadedAt) >= adExpiryInterval {
            rewardedAd = nil
            self.loadedAt = nil
            isReady = false
        }

        guard let ad = rewardedAd else {
            print("⚠️ Rewarded: 廣告尚未就緒")
            preload()
            return false
        }

        guard let presenter, presenter.viewIfLoaded?.window != nil else {
            print("⚠️ Rewarded: 找不到 rootViewController")
            return false
        }

        self.onReward = onReward
        self.onDismiss = onDismiss

        ad.present(fromRootViewController: ScenePresentationAnchor.top(from: presenter)) { [weak self] in
            self?.onReward?()
            self?.recordView()
        }
        return true
    }

    // MARK: - GADFullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        DispatchQueue.main.async { [weak self] in
            self?.rewardedAd = nil
            self?.loadedAt = nil
            self?.isReady = false
            self?.onDismiss?()
            self?.onReward = nil
            self?.onDismiss = nil
            // 預載下一支
            self?.preload()
        }
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            print("❌ Rewarded present error: \(error.localizedDescription)")
            self?.rewardedAd = nil
            self?.loadedAt = nil
            self?.isReady = false
            self?.preload()
        }
    }

    // MARK: - 私有方法

    private func loadAd() {
        isLoading = true
        let req = GADRequest()
        GADRewardedAd.load(withAdUnitID: adUnitID, request: req) { [weak self] ad, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let ad {
                    ad.fullScreenContentDelegate = self
                    self.rewardedAd = ad
                    self.loadedAt = Date()
                    self.isReady = true
                    self.retryCount = 0
                    print("✅ Rewarded ad loaded")

                    // 1 小時後檢查是否需要重載
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.adExpiryInterval) { [weak self] in
                        self?.handleAdExpiry()
                    }
                } else {
                    print("❌ Rewarded load error: \(error?.localizedDescription ?? "unknown")")
                    self.isReady = false
                    self.retryWithBackoff()
                }
            }
        }
    }

    private func retryWithBackoff() {
        guard retryCount < maxRetry else {
            print("⚠️ Rewarded: 已達最大重試次數 \(maxRetry)")
            return
        }
        retryCount += 1
        let delay = pow(2.0, Double(retryCount)) * 2.0  // 4s, 8s, 16s
        print("🔄 Rewarded: 第 \(retryCount) 次重試，\(delay)s 後")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.loadAd()
        }
    }

    private func handleAdExpiry() {
        guard rewardedAd != nil else { return }
        if let loadedAt, Date().timeIntervalSince(loadedAt) >= adExpiryInterval {
            print("🔄 Rewarded: 廣告已過期，重新載入")
            rewardedAd = nil
            self.loadedAt = nil
            isReady = false
            loadAd()
        }
    }

    private func recordView() {
        viewCount += 1
        remainingViews = max(0, maxDailyViews - viewCount)
    }

    private func resetDailyCountIfNeeded() {
        let tz = TimeZone(identifier: "Asia/Taipei") ?? .current
        let cal = Calendar.current
        let today = cal.dateComponents(in: tz, from: Date())
        let stored = cal.dateComponents(in: tz, from: Date(timeIntervalSince1970: viewDateTs))
        if today.year != stored.year || today.month != stored.month || today.day != stored.day {
            viewCount = 0
            viewDateTs = Date().timeIntervalSince1970
            remainingViews = maxDailyViews
        }
    }


}
