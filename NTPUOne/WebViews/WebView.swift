//
//  WebView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation
import WebKit
import SwiftUI
import SafariServices

struct WebView: UIViewRepresentable {
    
    let urlString: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let safeString = urlString, let url = URL(string: safeString) {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            if navigationAction.navigationType == .linkActivated {
                let urlString = url.absoluteString
                
                // 如果是特定的 URL 使用外部浏览器打开
                if urlString == "https://past-exam.ntpu.cc" {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }
                
                // 对其他 URL 使用内嵌浏览器 (SFSafariViewController) 打开
                if let topViewController = ScenePresentationAnchor.presenter(for: webView) {
                    let safariVC = SFSafariViewController(url: url)
                    topViewController.present(safariVC, animated: true, completion: nil)
                }
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
    }
}

/// A Safari presentation belongs to the SwiftUI view that requested it, not a global window.
struct SceneSafariDestination: Identifiable {
    let id = UUID()
    let url: URL
}

/// Holds a scene-local presentation source without retaining its view hierarchy.
final class WeakScenePresentationController {
    weak var controller: UIViewController?
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - 帶 Banner 廣告的 WebView（用於常用連結）
struct WebViewWithBanner: View {
    let urlString: String
    let title: String
    @EnvironmentObject var adFree: AdFreeService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WebView(urlString: urlString)
                
                // 底部 Banner 廣告
                if !adFree.isAdFree {
                    BannerAdView()
                        .frame(height: 50)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "safari")
                    }
                }
            }
        }
    }
}
