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
        isAdFree = now.timeIntervalSince1970 < adFreeUntilTs
    }

    /// 今天 23:59:59 到期
    func grantForTodayEnd(timeZone: TimeZone = TimeZone(identifier: "Asia/Taipei") ?? .current) {
        var comps = Calendar.current.dateComponents(in: timeZone, from: Date())
        comps.hour = 23; comps.minute = 59; comps.second = 59
        let expiry = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(24*3600)
        adFreeUntilTs = expiry.timeIntervalSince1970
        refresh()
    }

    func clear() {
        adFreeUntilTs = 0
        refresh()
    }
}
