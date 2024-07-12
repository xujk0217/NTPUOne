//
//  NativeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/6.
//

import SwiftUI
import GoogleMobileAds

struct NativeAdView: UIViewRepresentable {
    let adUnitID: String
    private let adLoader = GADAdLoader(adUnitID: adUnitID, rootViewController: nil,
                                       adTypes: [.native], options: nil)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        adLoader.delegate = context.coordinator
        adLoader.load(GADRequest())
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    class Coordinator: NSObject, GADAdLoaderDelegate, GADNativeAdLoaderDelegate {
        var parent: NativeAdView

        init(_ parent: NativeAdView) {
            self.parent = parent
        }

        func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
            let nativeAdView = GADNativeAdView(frame: .zero)
            nativeAdView.nativeAd = nativeAd
            
            // 配置广告视图（标题，正文，图片等）
            let headlineView = UILabel()
            headlineView.text = nativeAd.headline
            nativeAdView.headlineView = headlineView
            
            // 将广告视图添加到主视图
            parent.nativeAdView.addSubview(nativeAdView)
            
            // 设置广告视图的布局约束
            nativeAdView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                nativeAdView.leadingAnchor.constraint(equalTo: parent.nativeAdView.leadingAnchor),
                nativeAdView.trailingAnchor.constraint(equalTo: parent.nativeAdView.trailingAnchor),
                nativeAdView.topAnchor.constraint(equalTo: parent.nativeAdView.topAnchor),
                nativeAdView.bottomAnchor.constraint(equalTo: parent.nativeAdView.bottomAnchor)
            ])
        }

        func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
            print("Failed to receive native ad: \(error.localizedDescription)")
        }
    }
}
