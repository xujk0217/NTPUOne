//
//  BannerView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import GoogleMobileAds

protocol BannerViewControllerWidthDelegate: AnyObject {
    func bannerViewController(_ bannerViewController: BannerViewController, didUpdate width: CGFloat)
}

class BannerViewController: UIViewController {
    weak var delegate: BannerViewControllerWidthDelegate?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        delegate?.bannerViewController(self, didUpdate: view.frame.inset(by: view.safeAreaInsets).size.width)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.delegate?.bannerViewController(self, didUpdate: self.view.frame.inset(by: self.view.safeAreaInsets).size.width)
        }
    }
}

struct BannerView: UIViewControllerRepresentable {
    @State private var viewWidth: CGFloat = .zero
    private let bannerView = GADBannerView()
    private let adUnitID = "ca-app-pub-4105005748617921/1051002729"
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let bannerViewController = BannerViewController()
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = bannerViewController
        bannerView.delegate = context.coordinator
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerViewController.view.addSubview(bannerView)
        
        NSLayoutConstraint.activate([
            bannerView.bottomAnchor.constraint(equalTo: bannerViewController.view.safeAreaLayoutGuide.bottomAnchor),
            bannerView.centerXAnchor.constraint(equalTo: bannerViewController.view.centerXAnchor)
        ])
        
        bannerViewController.delegate = context.coordinator
        
        return bannerViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        guard viewWidth != .zero else { return }
        
        // Ensure the adSize is updated based on the new width
        let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
        bannerView.adSize = adSize
        bannerView.load(GADRequest())
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    internal class Coordinator: NSObject, BannerViewControllerWidthDelegate, GADBannerViewDelegate {
        func bannerViewController(_ bannerViewController: BannerViewController, didUpdate width: CGFloat) {
            parent.viewWidth = width
        }
        
        let parent: BannerView
        
        init(parent: BannerView) {
            self.parent = parent
        }
    }
}


import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    // 橫幅廣告的測試 ID
    let adUnitID = "ca-app-pub-3940256099942544/2934735716"
    // 正式
//    let adUnitID = "ca-app-pub-4105005748617921/1051002729"
    
    // 橫幅廣告的大小
    let adSize = GADAdSizeBanner
    
    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: adSize)
        
        // 取得 rootViewController
        let rootVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = rootVC
        bannerView.load(GADRequest())
        
        return bannerView
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
