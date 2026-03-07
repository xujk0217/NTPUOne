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
final class CommentLimitManager: ObservableObject {
    static let shared = CommentLimitManager()
    
    // MARK: - 設定
    private let baseDailyLimit = 3           // 每日基本留言數
    private let bonusPerAd = 3               // 每次廣告獎勵的額外留言數
    private let maxAdViews = 5               // 每日最多觀看廣告次數
    
    // MARK: - 狀態
    @Published private(set) var remainingComments: Int = 3
    @Published private(set) var remainingAdViews: Int = 5
    
    // 持久化儲存
    @AppStorage("commentDailyCount") private var dailyCommentCount: Int = 0
    @AppStorage("commentAdViewCount") private var adViewCount: Int = 0
    @AppStorage("commentLimitDateTs") private var limitDateTs: Double = 0
    
    init() {
        resetDailyCountIfNeeded()
        updateRemainingCounts()
    }
    
    // MARK: - 公開方法
    
    /// 檢查是否還可以新增留言
    var canComment: Bool {
        resetDailyCountIfNeeded()
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
    
    /// 記錄一則新留言
    func recordComment() {
        resetDailyCountIfNeeded()
        dailyCommentCount += 1
        updateRemainingCounts()
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
    }
    
    private func resetDailyCountIfNeeded() {
        let tz = TimeZone(identifier: "Asia/Taipei") ?? .current
        let cal = Calendar.current
        let today = cal.dateComponents(in: tz, from: Date())
        let stored = cal.dateComponents(in: tz, from: Date(timeIntervalSince1970: limitDateTs))
        
        if today.year != stored.year || today.month != stored.month || today.day != stored.day {
            dailyCommentCount = 0
            adViewCount = 0
            limitDateTs = Date().timeIntervalSince1970
            updateRemainingCounts()
            print("🔄 留言限制已重置（新的一天）")
        }
    }
}
