//
//  CommentBadgeManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2026/3/8.
//

import Foundation
import SwiftUI

/// 評論徽章/稱號管理器
/// - 根據累積評論數授予不同等級的稱號和徽章
final class CommentBadgeManager: ObservableObject {
    static let shared = CommentBadgeManager()
    
    // MARK: - 徽章等級定義
    enum BadgeLevel: Int, CaseIterable {
        case newbie = 0      // 0-4 則
        case explorer = 1    // 5-14 則
        case senior = 2      // 15-39 則
        case expert = 3      // 40-79 則
        case master = 4      // 80+ 則
        case developer = 99  // 開發者專屬
        
        var title: String {
            switch self {
            case .newbie: return String(localized: "badge_newbie")
            case .explorer: return String(localized: "badge_explorer")
            case .senior: return String(localized: "badge_senior")
            case .expert: return String(localized: "badge_expert")
            case .master: return String(localized: "badge_master")
            case .developer: return String(localized: "badge_developer")
            }
        }
        
        var icon: String {
            switch self {
            case .newbie: return "🍽️"
            case .explorer: return "🌟"
            case .senior: return "⭐"
            case .expert: return "🏅"
            case .master: return "👑"
            case .developer: return "🛠️"
            }
        }
        
        var color: Color {
            switch self {
            case .newbie: return .gray
            case .explorer: return .green
            case .senior: return .blue
            case .expert: return .orange
            case .master: return .purple
            case .developer: return .red
            }
        }
        
        /// 漸層顏色
        var gradientColors: [Color] {
            switch self {
            case .newbie: return [.gray.opacity(0.6), .gray]
            case .explorer: return [.green.opacity(0.7), .mint]
            case .senior: return [.blue.opacity(0.7), .cyan]
            case .expert: return [.orange, .yellow]
            case .master: return [.purple, .pink]
            case .developer: return [.red, .orange]
            }
        }
        
        /// 該等級所需的最低評論數
        var minComments: Int {
            switch self {
            case .newbie: return 0
            case .explorer: return 5
            case .senior: return 15
            case .expert: return 40
            case .master: return 80
            case .developer: return 0
            }
        }
    }
    
    // MARK: - 狀態
    @Published private(set) var totalComments: Int = 0
    @Published private(set) var currentBadge: BadgeLevel = .newbie
    
    @AppStorage("totalCommentCount") private var storedTotalComments: Int = 0
    @AppStorage("isAdmin") private var isAdmin: Bool = false
    
    init() {
        totalComments = storedTotalComments
        updateBadge()
    }
    
    // MARK: - 公開方法
    
    /// 記錄一則新評論，更新累積數和徽章
    func recordNewComment() {
        storedTotalComments += 1
        totalComments = storedTotalComments
        updateBadge()
        print("📝 累積評論數：\(totalComments)，當前稱號：\(currentBadge.title)")
    }
    
    /// 刪除留言後遞減累積數
    func decrementComment() {
        guard storedTotalComments > 0 else { return }
        storedTotalComments -= 1
        totalComments = storedTotalComments
        updateBadge()
        print("🗑️ 累積評論數：\(totalComments)，當前稱號：\(currentBadge.title)")
    }
    
    /// 同步伺服器上的實際留言數量（用於修正本地記錄）
    func syncCommentCount(_ serverCount: Int) {
        // 只有當伺服器數量大於本地記錄時才更新（避免降級）
        if serverCount > storedTotalComments {
            storedTotalComments = serverCount
            totalComments = serverCount
            updateBadge()
            print("🔄 已同步留言數量：\(serverCount)，稱號：\(currentBadge.title)")
        }
    }
    
    /// 根據累積評論數取得對應的徽章等級
    func getBadgeLevel(for commentCount: Int) -> BadgeLevel {
        // 開發者特殊判斷
        if isAdmin {
            return .developer
        }
        
        switch commentCount {
        case 0..<5: return .newbie
        case 5..<15: return .explorer
        case 15..<40: return .senior
        case 40..<80: return .expert
        default: return .master
        }
    }
    
    /// 取得當前用戶的徽章（考慮開發者身份）
    func getCurrentBadge() -> BadgeLevel {
        if isAdmin {
            return .developer
        }
        return currentBadge
    }
    
    /// 取得下一個等級所需的評論數
    func commentsToNextLevel() -> Int? {
        if isAdmin { return nil }  // 開發者已是最高
        
        let nextLevels: [BadgeLevel] = [.explorer, .senior, .expert, .master]
        for level in nextLevels {
            if totalComments < level.minComments {
                return level.minComments - totalComments
            }
        }
        return nil  // 已達最高等級
    }
    
    /// 取得升級進度 (0.0 ~ 1.0)
    func progressToNextLevel() -> Double {
        if isAdmin { return 1.0 }
        
        let current = getCurrentBadge()
        let levels: [BadgeLevel] = [.newbie, .explorer, .senior, .expert, .master]
        guard let currentIndex = levels.firstIndex(of: current),
              currentIndex < levels.count - 1 else {
            return 1.0  // 已達最高
        }
        
        let nextLevel = levels[currentIndex + 1]
        let needed = nextLevel.minComments - current.minComments
        let progress = totalComments - current.minComments
        return min(1.0, Double(progress) / Double(needed))
    }
    
    // MARK: - 私有方法
    
    private func updateBadge() {
        currentBadge = getBadgeLevel(for: totalComments)
    }
}

// MARK: - 徽章視圖元件

/// 精緻徽章標籤（用於留言列表的名稱旁）
struct BadgeTagView: View {
    let badge: CommentBadgeManager.BadgeLevel
    var compact: Bool = true
    
    var body: some View {
        HStack(spacing: 3) {
            Text(badge.icon)
                .font(compact ? .caption2 : .caption)
            if !compact {
                Text(badge.title)
                    .font(.caption2.bold())
            }
        }
        .padding(.horizontal, compact ? 5 : 8)
        .padding(.vertical, 2)
        .background(
            LinearGradient(
                colors: badge.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(Capsule())
        .shadow(color: badge.color.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}

/// 小型徽章顯示（用於留言列表）- 保留向下相容
struct BadgeIconView: View {
    let badge: CommentBadgeManager.BadgeLevel
    var showTitle: Bool = false
    
    var body: some View {
        BadgeTagView(badge: badge, compact: !showTitle)
    }
}

/// 完整徽章卡片（用於個人資料頁）
struct BadgeCardView: View {
    @ObservedObject var badgeManager = CommentBadgeManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // 大徽章
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: badgeManager.getCurrentBadge().gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: badgeManager.getCurrentBadge().color.opacity(0.5), radius: 8, x: 0, y: 4)
                
                Text(badgeManager.getCurrentBadge().icon)
                    .font(.system(size: 32))
            }
            
            // 稱號
            Text(badgeManager.getCurrentBadge().title)
                .font(.headline.bold())
                .foregroundStyle(badgeManager.getCurrentBadge().color)
            
            // 評論數
            Text(String(format: String(localized: "total_comments_format"), badgeManager.totalComments))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // 進度條
            if let toNext = badgeManager.commentsToNextLevel() {
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: badgeManager.getCurrentBadge().gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * badgeManager.progressToNextLevel(), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    Text(String(format: String(localized: "comments_to_next_level"), toNext))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    Text(String(localized: "max_level_reached"))
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
