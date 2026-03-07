//
//  RewardView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/5.
//

import Foundation
import GoogleMobileAds
import SwiftUI

/// 保留舊的 RewardedAd class 介面（供 AddOrderView 使用）
/// 內部委託給 RewardedAdManager
final class RewardedAd: NSObject, ObservableObject {
    @Published var canShowAd = true
    @Published var isEligibleForReward = false

    override init() {
        super.init()
    }

    func load() {
        Task { @MainActor in
            RewardedAdManager.shared.preload()
        }
    }

    func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isEligibleForReward = true
        }
    }

    func cancelTimer() {
        isEligibleForReward = false
    }
}

// MARK: - UIApplication 擴展（保留供其他地方使用）
extension UIApplication {
    var keyWindowPresentedController: UIViewController? {
        var viewController = connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first

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
