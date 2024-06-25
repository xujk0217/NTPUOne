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
        if let safeString = urlString {
            if let url = URL(string: safeString) {
                let request = URLRequest(url: url)
                uiView.load(request)
            }
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
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
//                     判断特定 URL 使用 Safari 浏览器打开
                    if url.absoluteString == "https://past-exam.ntpu.cc" {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        decisionHandler(.cancel)
                    } else {
                        // 使用内嵌浏览器 (SFSafariViewController) 打开其他链接
                        if let topViewController = UIApplication.shared.windows.first?.rootViewController {
                            let safariVC = SFSafariViewController(url: url)
                            topViewController.present(safariVC, animated: true, completion: nil)
                        }
                        decisionHandler(.cancel)
                    }
                    return
//                    // Check if the navigation action's URL matches a specific condition
//                    if navigationAction.request.url?.absoluteString == "https://past-exam.ntpu.cc/" {
//                        // Open in external browser
//                        if UIApplication.shared.canOpenURL(navigationAction.request.url!) {
//                            UIApplication.shared.open(navigationAction.request.url!, options: [:], completionHandler: nil)
//                            decisionHandler(.cancel)
//                            return
//                        }
//                    }
                }
            }
            decisionHandler(.allow)
        }
    }
}
