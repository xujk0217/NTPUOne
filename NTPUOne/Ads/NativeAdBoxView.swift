//
//  NativeAdBoxView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/9.
//


struct NativeAdBoxView: UIViewRepresentable {
//     let adUnitID = "ca-app-pub-3940256099942544/3986624511" // 測試用
    let adUnitID = "ca-app-pub-4105005748617921/9068538634"
    
    @State private var nativeAd: GADNativeAd?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GADNativeAdView {
        let adView = GADNativeAdView()
        context.coordinator.adView = adView
        context.coordinator.loadAd()
        
        // ❌ 移除這行，它會讓 adView 的高度被固定為 0
        // adView.heightAnchor.constraint(equalToConstant: 0).isActive = true
        return adView
    }

    func updateUIView(_ uiView: GADNativeAdView, context: Context) {}

    class Coordinator: NSObject, GADNativeAdLoaderDelegate, GADNativeAdDelegate {
        var parent: NativeAdBoxView
        var adLoader: GADAdLoader!
        weak var adView: GADNativeAdView?

        init(parent: NativeAdBoxView) {
            self.parent = parent
            super.init()
        }

        func loadAd() {
            guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first?.rootViewController else {
                print("❌ 錯誤: 無法找到 rootViewController")
                return
            }
            
            adLoader = GADAdLoader(adUnitID: parent.adUnitID,
                                   rootViewController: rootVC,
                                   adTypes: [.native],
                                   options: nil)
            
            adLoader.delegate = self
            print("📤 發送廣告請求")
            adLoader.load(GADRequest())
        }

        func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
            print("✅ 廣告載入成功 headline: \(nativeAd.headline ?? "")")
            self.parent.nativeAd = nativeAd
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
            // 建立一個垂直的堆疊視圖
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 8
            stackView.translatesAutoresizingMaskIntoConstraints = false
            adView.addSubview(stackView)
            
            // 廣告標誌 AdChoicesView (必須)
            let adChoicesView = GADAdChoicesView()
            adChoicesView.translatesAutoresizingMaskIntoConstraints = false
            adView.adChoicesView = adChoicesView
            adView.addSubview(adChoicesView)
            
            // 標題 (必須)
            let headlineView = UILabel()
            headlineView.text = nativeAd.headline
            headlineView.font = .boldSystemFont(ofSize: 18)
            adView.headlineView = headlineView
            stackView.addArrangedSubview(headlineView)

            // 主要媒體 (圖片或影片)
            let mediaView = GADMediaView()
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            adView.mediaView = mediaView
            stackView.addArrangedSubview(mediaView)
            
            // 內文
            let bodyView = UILabel()
            bodyView.text = nativeAd.body
            bodyView.numberOfLines = 2
            bodyView.font = .systemFont(ofSize: 14)
            adView.bodyView = bodyView
            stackView.addArrangedSubview(bodyView)

            // CTA 按鈕 (必須)
            let ctaButton = UIButton(type: .system)
            ctaButton.setTitle(nativeAd.callToAction, for: .normal)
            ctaButton.backgroundColor = .systemBlue
            ctaButton.setTitleColor(.white, for: .normal)
            ctaButton.layer.cornerRadius = 5
            adView.callToActionView = ctaButton
            stackView.addArrangedSubview(ctaButton)
            
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 16),
                stackView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
                stackView.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -16),
                
                adChoicesView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 4),
                adChoicesView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -4),
                
                ctaButton.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            adView.nativeAd = nativeAd
        }
    }
}