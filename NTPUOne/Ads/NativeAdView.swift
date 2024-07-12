//
//  NativeAdView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/6.
//

import SwiftUI
import GoogleMobileAds
import Firebase

struct NativeAdView: UIViewRepresentable {
    let adUnitID: String = "ca-app-pub-4105005748617921/9068538634"
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        context.coordinator.containerView = view
        
        // 初始化广告加载器
        let adLoader = GADAdLoader(adUnitID: adUnitID, rootViewController: context.coordinator.rootViewController,
                                   adTypes: [.native], options: nil)
        adLoader.delegate = context.coordinator
        
        print("Loading native ad...")
        adLoader.load(GADRequest())
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 在此方法中不需要更新视图
    }
    
    class Coordinator: NSObject, GADAdLoaderDelegate, GADNativeAdLoaderDelegate {
        var parent: NativeAdView
        var containerView: UIView?
        var rootViewController: UIViewController
        
        init(_ parent: NativeAdView) {
            self.parent = parent
            self.rootViewController = UIViewController()
        }
        
        func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
            print("Successfully received native ad")
            guard let containerView = containerView else {
                print("Error: containerView is nil")
                return
            }
            
            // 创建原生广告视图
            let nativeAdView = GADNativeAdView(frame: .zero)
            nativeAdView.nativeAd = nativeAd
            
            // 设置广告视图的组件
            let headlineView = UILabel()
            headlineView.text = nativeAd.headline
            headlineView.numberOfLines = 0
            nativeAdView.headlineView = headlineView
            
            // 添加广告视图到容器视图
            containerView.addSubview(nativeAdView)
            
            // 设置广告视图的布局约束
            nativeAdView.translatesAutoresizingMaskIntoConstraints = false
            headlineView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                nativeAdView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                nativeAdView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                nativeAdView.topAnchor.constraint(equalTo: containerView.topAnchor),
                nativeAdView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                headlineView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 10),
                headlineView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -10),
                headlineView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 10),
                headlineView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -10)
            ])
            
            print("Native ad view configured successfully")
        }
        
        func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
            print("Failed to receive native ad: \(error.localizedDescription)")
            if let error = error as NSError? {
                print("Error code: \(error.code), description: \(error.localizedDescription)")
            }
        }
    }
}
