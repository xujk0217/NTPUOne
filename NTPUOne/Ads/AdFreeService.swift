//
//  AdFreeService.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/27.
//


import SwiftUI
import Combine

@MainActor
final class AdFreeService: ObservableObject {
    @Published private(set) var isAdFree: Bool = false
    @AppStorage("adFreeUntil") private var adFreeUntilTs: Double = 0
    
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    static let shared = AdFreeService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        refresh()
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    func refresh(now: Date = Date()) {
        if isAdmin{
            adFreeUntilTs = Calendar.current.date(byAdding: .year, value: 100, to: Date())!.timeIntervalSince1970
            isAdFree = true
        } else {
            isAdFree = now.timeIntervalSince1970 < adFreeUntilTs
        }
    }

    /// 今天 23:59:59 到期
    func grantForTodayEnd(timeZone: TimeZone = TimeZone(identifier: "Asia/Taipei") ?? .current) {
        var comps = Calendar.current.dateComponents(in: timeZone, from: Date())
        comps.hour = 23; comps.minute = 59; comps.second = 59
        let expiry = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(24*3600)
        adFreeUntilTs = expiry.timeIntervalSince1970
        refresh()
    }
    
    /// 累加指定小時數的去廣告時間
    /// - Parameter hours: 要增加的小時數
    func grantHours(_ hours: Double) {
        let now = Date().timeIntervalSince1970
        let currentExpiry = max(now, adFreeUntilTs)  // 若已過期則從現在開始
        let additionalSeconds = hours * 3600
        adFreeUntilTs = currentExpiry + additionalSeconds
        refresh()
        print("✅ 獲得 \(hours) 小時無廣告，到期時間：\(Date(timeIntervalSince1970: adFreeUntilTs))")
    }
    
    /// 取得剩餘去廣告時間（小時）
    func remainingHours() -> Double {
        let now = Date().timeIntervalSince1970
        let remaining = adFreeUntilTs - now
        return max(0, remaining / 3600)
    }

    func clear() {
        adFreeUntilTs = 0
        refresh()
    }
}
