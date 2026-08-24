//
//  CommentLimitManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2026/3/7.
//

import Foundation
import SwiftUI

/// 留言每日限制管理器
/// - 每天基本限制：3 則留言
/// - 觀看獎勵式廣告：每次可額外增加 3 則留言
/// - 最多可看 5 次廣告，增加 15 則額外留言
/// - 每則評論獎勵 2 小時無廣告，每日上限 6 小時
final class CommentLimitManager: ObservableObject {
    static let shared = CommentLimitManager()
    
    // MARK: - 設定
    private let baseDailyLimit = 3           // 每日基本留言數
    private let bonusPerAd = 3               // 每次廣告獎勵的額外留言數
    private let maxAdViews = 5               // 每日最多觀看廣告次數
    private let adFreeHoursPerComment = 2.0  // 每則評論獎勵的無廣告小時數
    private let maxDailyAdFreeHours = 6.0    // 每日最多獎勵無廣告時數
    
    // MARK: - 狀態
    @Published private(set) var remainingComments: Int = 3
    @Published private(set) var remainingAdViews: Int = 5
    @Published private(set) var todayRewardedHours: Double = 0
    @Published private(set) var lastRewardMessage: String = ""
    
    // 持久化儲存
    @AppStorage("commentDailyCount") private var dailyCommentCount: Int = 0
    @AppStorage("commentAdViewCount") private var adViewCount: Int = 0
    @AppStorage("commentLimitDateTs") private var limitDateTs: Double = 0
    @AppStorage("commentDailyRewardHours") private var dailyRewardHours: Double = 0
    
    init() {
        resetDailyCountIfNeeded()
        updateRemainingCounts()
    }
    
    // MARK: - 公開方法
    
    /// 檢查是否還可以新增留言
    var canComment: Bool {
        resetDailyCountIfNeeded()
        if CommentBadgeManager.shared.isAdminUser { return true }
        return dailyCommentCount < currentDailyLimit
    }
    
    /// 當前每日限制（基本 + 廣告獎勵）
    var currentDailyLimit: Int {
        return baseDailyLimit + (adViewCount * bonusPerAd)
    }
    
    /// 是否還能觀看廣告來獲得更多留言額度
    var canWatchAdForBonus: Bool {
        resetDailyCountIfNeeded()
        return adViewCount < maxAdViews
    }
    
    /// 記錄一則新留言，並發放獎勵
    /// - Returns: 獲得的無廣告小時數（0 表示已達上限）
    @discardableResult
    func recordComment() -> Double {
        resetDailyCountIfNeeded()
        dailyCommentCount += 1
        
        // 更新徽章
        CommentBadgeManager.shared.recordNewComment()
        
        // 發放去廣告獎勵
        var rewardedHours: Double = 0
        if dailyRewardHours < maxDailyAdFreeHours {
            let remainingQuota = maxDailyAdFreeHours - dailyRewardHours
            rewardedHours = min(adFreeHoursPerComment, remainingQuota)
            dailyRewardHours += rewardedHours
            
            // 實際發放去廣告時間
            Task { @MainActor in
                AdFreeService.shared.grantHours(rewardedHours)
            }
            
            lastRewardMessage = String(format: String(localized: "comment_reward_message"), Int(rewardedHours))
            print("🎁 評論獎勵：\(rewardedHours) 小時無廣告，今日已獲得 \(dailyRewardHours) 小時")
        } else {
            lastRewardMessage = String(localized: "comment_reward_limit_reached")
            print("⚠️ 今日評論獎勵已達上限 \(maxDailyAdFreeHours) 小時")
        }
        
        updateRemainingCounts()
        return rewardedHours
    }
    
    /// 觀看廣告後獲得額外留言額度
    func grantAdBonus() {
        resetDailyCountIfNeeded()
        guard adViewCount < maxAdViews else { return }
        adViewCount += 1
        updateRemainingCounts()
        print("✅ 獲得廣告獎勵：額外 \(bonusPerAd) 則留言，剩餘 \(remainingComments) 則")
    }
    
    /// 取得剩餘可留言數量
    func getRemainingComments() -> Int {
        resetDailyCountIfNeeded()
        return max(0, currentDailyLimit - dailyCommentCount)
    }
    
    /// 取得剩餘可觀看廣告次數
    func getRemainingAdViews() -> Int {
        resetDailyCountIfNeeded()
        return max(0, maxAdViews - adViewCount)
    }
    
    // MARK: - 私有方法
    
    private func updateRemainingCounts() {
        remainingComments = max(0, currentDailyLimit - dailyCommentCount)
        remainingAdViews = max(0, maxAdViews - adViewCount)
        todayRewardedHours = dailyRewardHours
    }
    
    private func resetDailyCountIfNeeded() {
        let tz = TimeZone(identifier: "Asia/Taipei") ?? .current
        let cal = Calendar.current
        let today = cal.dateComponents(in: tz, from: Date())
        let stored = cal.dateComponents(in: tz, from: Date(timeIntervalSince1970: limitDateTs))
        
        if today.year != stored.year || today.month != stored.month || today.day != stored.day {
            dailyCommentCount = 0
            adViewCount = 0
            dailyRewardHours = 0
            limitDateTs = Date().timeIntervalSince1970
            updateRemainingCounts()
            print("🔄 留言限制已重置（新的一天）")
        }
    }
    
    /// 取得今日剩餘可獲得的獎勵時數
    func getRemainingRewardHours() -> Double {
        resetDailyCountIfNeeded()
        return max(0, maxDailyAdFreeHours - dailyRewardHours)
    }
}
