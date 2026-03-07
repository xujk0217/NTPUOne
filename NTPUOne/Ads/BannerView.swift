//
//  BannerView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import GoogleMobileAds

// MARK: - 統一 Banner 廣告視圖（帶骨架佔位符）

/// 使用此視圖顯示 Banner 廣告，自動在載入中顯示骨架佔位符
struct BannerAdSectionView: View {
    @StateObject private var loader = BannerAdLoader()
    
    var body: some View {
        ZStack {
            // 骨架佔位符（廣告載入前顯示）
            if !loader.isAdLoaded {
                BannerSkeletonPlaceholder()
            }
            
            // 實際 Banner 廣告
            BannerAdUIViewWrapper(loader: loader)
                .opacity(loader.isAdLoaded ? 1 : 0)
        }
        .frame(height: BannerAdView.adHeight)
    }
}

/// Banner 載入狀態管理
final class BannerAdLoader: NSObject, ObservableObject, GADBannerViewDelegate {
    @Published var isAdLoaded = false
    private var retryCount = 0
    private let maxRetry = 3
    
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        DispatchQueue.main.async {
            self.isAdLoaded = true
            self.retryCount = 0
        }
    }
    
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("⚠️ Banner ad failed: \(error.localizedDescription)")
        guard retryCount < maxRetry else { return }
        retryCount += 1
        let delay = Double(retryCount) * 5.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak bannerView] in
            bannerView?.load(GADRequest())
        }
    }
}

/// Banner 廣告的 UIViewRepresentable
struct BannerAdUIViewWrapper: UIViewRepresentable {
    @ObservedObject var loader: BannerAdLoader
    
    // 正式 ID
    let adUnitID = "ca-app-pub-4105005748617921/1051002729"
    // 測試 ID：
    // let adUnitID = "ca-app-pub-3940256099942544/2934735716"
    
    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = Self.rootVC
        bannerView.delegate = loader
        bannerView.load(GADRequest())
        return bannerView
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {}
    
    private static var rootVC: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }?.rootViewController
    }
}

/// Banner 骨架佔位符
struct BannerSkeletonPlaceholder: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray4))
                    .frame(width: index == 0 ? 60 : (index == 3 ? 40 : 80), height: 20)
            }
            Spacer()
            Text("ad")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(.systemGray3))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
        .padding(.horizontal, 12)
        .frame(height: BannerAdView.adHeight)
        .background(Color(.systemGray6))
    }
}

// MARK: - 舊版 BannerAdView（保持向後相容）
/// 使用固定 GADAdSizeBanner，自帶載入失敗重試機制
struct BannerAdView: UIViewRepresentable {
    // 正式 ID
    let adUnitID = "ca-app-pub-4105005748617921/1051002729"
    // 測試 ID：
    // let adUnitID = "ca-app-pub-3940256099942544/2934735716"

    /// 統一 Banner 高度（所有頁面使用此值）
    static let adHeight: CGFloat = 50

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = Self.rootVC
        bannerView.delegate = context.coordinator
        bannerView.load(GADRequest())
        context.coordinator.bannerView = bannerView
        return bannerView
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // 不在 update 中重複載入，避免過度請求
    }

    // MARK: - Coordinator（載入失敗自動重試，最多 3 次）
    final class Coordinator: NSObject, GADBannerViewDelegate {
        weak var bannerView: GADBannerView?
        private var retryCount = 0
        private let maxRetry = 3

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("⚠️ Banner ad failed: \(error.localizedDescription)")
            guard retryCount < maxRetry else { return }
            retryCount += 1
            let delay = Double(retryCount) * 5.0 // 5s, 10s, 15s
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak bannerView] in
                bannerView?.load(GADRequest())
            }
        }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            retryCount = 0
        }
    }

    // MARK: - Helper
    private static var rootVC: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }?.rootViewController
    }
}
