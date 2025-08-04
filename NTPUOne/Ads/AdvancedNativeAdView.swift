//
//  AdvancedNativeAdView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/4.
//

import SwiftUI
import GoogleMobileAds

struct NativeAdBoxView: UIViewRepresentable {
    let adUnitID = "ca-app-pub-3940256099942544/3986624511" // 測試用
//    let adUnitID = "ca-app-pub-4105005748617921/9068538634"
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        print("🟢 makeUIView called")
        let container = UIView()
        context.coordinator.containerView = container

        let rootVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController

        let adLoader = GADAdLoader(adUnitID: adUnitID,
                                   rootViewController: rootVC,
                                   adTypes: [.native],
                                   options: nil)
        adLoader.delegate = context.coordinator
        print("📤 發送廣告請求")
        adLoader.load(GADRequest())

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    class Coordinator: NSObject, GADNativeAdLoaderDelegate {
        var containerView: UIView?

        func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
            guard let container = containerView else { return }
            print("✅ 廣告載入成功 headline: \(nativeAd.headline ?? "")")
            container.subviews.forEach { $0.removeFromSuperview() }

            let adView = GADNativeAdView()
            adView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(adView)
            NSLayoutConstraint.activate([
                adView.topAnchor.constraint(equalTo: container.topAnchor),
                adView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                adView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                adView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])

            // headline
            let headline = UILabel()
            headline.text = nativeAd.headline
            adView.headlineView = headline
            adView.addSubview(headline)

            headline.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                headline.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
                headline.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
                headline.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),
                headline.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -8)
            ])

            adView.nativeAd = nativeAd
        }

        func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
            print("❌ 廣告失敗: \(error.localizedDescription)")
        }
    }
}
