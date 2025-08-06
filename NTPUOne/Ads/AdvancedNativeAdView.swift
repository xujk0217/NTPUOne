//
//  AdvancedNativeAdView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/4.
//

import SwiftUI
import GoogleMobileAds

struct NativeAdBoxView: UIViewRepresentable {
    // 使用測試用的廣告單元 ID
    let adUnitID = "ca-app-pub-3940256099942544/3986624511"

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GADNativeAdView {
        print("🟢 makeUIView called")
        let adView = GADNativeAdView()
        context.coordinator.adView = adView
        
        context.coordinator.loadAd()
        
        return adView
    }

    func updateUIView(_ uiView: GADNativeAdView, context: Context) {}

    class Coordinator: NSObject, GADNativeAdLoaderDelegate, GADNativeAdDelegate {
        var parent: NativeAdBoxView
        var adLoader: GADAdLoader!
        weak var adView: GADNativeAdView?
        weak var nativeAd: GADNativeAd?
        
        init(parent: NativeAdBoxView) {
            self.parent = parent
            super.init()
        }
        
        func loadAd() {
            let rootVC = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
            
            guard let rootViewController = rootVC else {
                print("❌ 錯誤: 無法找到 rootViewController")
                return
            }

            adLoader = GADAdLoader(adUnitID: parent.adUnitID,
                                   rootViewController: rootViewController,
                                   adTypes: [.native],
                                   options: nil)
            
            adLoader.delegate = self
            print("📤 發送廣告請求")
            adLoader.load(GADRequest())
        }

        func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
            print("✅ 廣告載入成功 headline: \(nativeAd.headline ?? "")")
            self.nativeAd = nativeAd
            nativeAd.delegate = self
            
            guard let adView = self.adView else { return }
            
            adView.subviews.forEach { $0.removeFromSuperview() }
            
            adView.nativeAd = nativeAd
            
            setupNativeAdView(adView: adView, nativeAd: nativeAd)
        }

        func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
            print("❌ 廣告載入失敗: \(error.localizedDescription)")
        }

        func setupNativeAdView(adView: GADNativeAdView, nativeAd: GADNativeAd) {
            let adChoicesView = GADAdChoicesView()
            adView.adChoicesView = adChoicesView
            
            let headlineView = UILabel()
            headlineView.text = nativeAd.headline
            adView.headlineView = headlineView
            
            let bodyView = UILabel()
            bodyView.text = nativeAd.body
            adView.bodyView = bodyView
            
            let ctaButton = UIButton()
            ctaButton.setTitle(nativeAd.callToAction, for: .normal)
            adView.callToActionView = ctaButton
            
            // ... (其他元件)
            
            let allViews = [headlineView, bodyView, ctaButton, adChoicesView] // ...
            allViews.forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
                adView.addSubview($0)
            }
            
            NSLayoutConstraint.activate([
                adChoicesView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 4),
                adChoicesView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -4),
                
                headlineView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
                headlineView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
                
                bodyView.topAnchor.constraint(equalTo: headlineView.bottomAnchor, constant: 4),
                bodyView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
                
                ctaButton.topAnchor.constraint(equalTo: bodyView.bottomAnchor, constant: 8),
                ctaButton.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
                ctaButton.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -8)
            ])
        }
    }
}
