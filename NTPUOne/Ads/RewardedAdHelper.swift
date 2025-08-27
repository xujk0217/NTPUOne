//
//  RewardedAdHelper.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/27.
//


import UIKit
import GoogleMobileAds

final class RewardedAdHelper: NSObject, GADFullScreenContentDelegate {
    private var rewarded: GADRewardedAd?
    private var adUnitID: String = ""

    func load(adUnitID: String, completion: @escaping (Bool)->Void) {
        self.adUnitID = adUnitID
        let req = GADRequest()
        GADRewardedAd.load(withAdUnitID: adUnitID, request: req) { [weak self] ad, err in
            self?.rewarded = ad
            ad?.fullScreenContentDelegate = self
            completion(ad != nil)
            if let err = err { print("Rewarded load error:", err) }
        }
    }

    func present(from rootVC: UIViewController, onReward: @escaping ()->Void, onDismiss: (() -> Void)? = nil) {
        guard let ad = rewarded else { return }
        ad.present(fromRootViewController: rootVC) {
            // ✅ 只有在 Earned reward 回呼才給權益
            _ = ad.adReward  // 若需讀取 reward 類型/數量，可用這個
            onReward()
        }
        // 關閉後清空，方便下次重新 load
        ad.fullScreenContentDelegate = self
        self.onDismiss = onDismiss
    }

    private var onDismiss: (() -> Void)?

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        rewarded = nil
        onDismiss?()
    }
}
