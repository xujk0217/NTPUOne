//
//  RewardView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/5.
//

import Foundation
import GoogleMobileAds
import SwiftUI

final class RewardedAd: NSObject, GADFullScreenContentDelegate, ObservableObject {
    
    private let rewardId = "ca-app-pub-4105005748617921/1893622165"
    var rewardedAd: GADRewardedAd?
    var rewardFunction: (() -> Void)?
    
    @Published var canShowAd = true
    @Published var waitTime: Int = 0
    private var timer: Timer?
    @Published var isEligibleForReward = false
    
    override init() {
        super.init()
        load()
    }
    
    /// 加载广告
    func load() {
        let request = GADRequest()
        
        GADRewardedAd.load(withAdUnitID: rewardId, request: request) { [weak self] rewardedAd, error in
            if let error = error {
                print("Failed to load rewarded ad: \(error.localizedDescription)")
                return
            }
            self?.rewardedAd = rewardedAd
            self?.rewardedAd?.fullScreenContentDelegate = self
            print("Rewarded ad loaded successfully.")
        }
    }
    
    /// 显示广告
    func showAd(rewardFunction: @escaping () -> Void) -> Bool {
        guard canShowAd else {
            print("Cannot show ad right now. Please wait.")
            return false
        }
        
        guard isEligibleForReward else { // 检查用户是否符合条件
            print("User is not eligible for reward.")
            return false
        }
        
        guard let rewardedAd = rewardedAd else {
            print("Rewarded ad is not ready.")
            return false
        }
        
        guard let root = UIApplication.shared.keyWindowPresentedController else {
            print("Unable to get the root view controller.")
            return false
        }
        
        self.rewardFunction = rewardFunction
        
        DispatchQueue.main.async {
            rewardedAd.present(fromRootViewController: root) {
                print("User did earn reward.")
                rewardFunction()
            }
        }
        
        return true
    }
    
    func startTimer() {
        canShowAd = false
        waitTime = 30
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.waitTime -= 1
            if self.waitTime <= 0 {
                self.canShowAd = true
                timer.invalidate()
                print("Ad can now be shown again.")
            }
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad did dismiss full screen content.")
        load()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad failed to present full screen content with error: \(error.localizedDescription)")
        load()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didPresentFullScreenContentWithError error: Error) {
        print("Ad did present full screen content.")
    }
}

// UIApplication 扩展

extension UIApplication {
    
    var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first(where: { $0 is UIWindowScene })
            .flatMap({ $0 as? UIWindowScene })?.windows
            .first(where: \.isKeyWindow)
    }
    
    var keyWindowPresentedController: UIViewController? {
        var viewController = self.keyWindow?.rootViewController
        
        if let presentedController = viewController as? UITabBarController {
            viewController = presentedController.selectedViewController
        }
        
        while let presentedController = viewController?.presentedViewController {
            if let presentedController = presentedController as? UITabBarController {
                viewController = presentedController.selectedViewController
            } else {
                viewController = presentedController
            }
        }
        return viewController
    }
}
