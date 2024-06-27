//
//  WebDetailView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import WebKit
import GoogleMobileAds

struct WebDetailView: View {
    let url: String?
    var body: some View {
        VStack(spacing: 0) {
            WebView(urlString: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            BannerView()
                .frame(height: 50) // 设置广告条的高度
                .background(Color.clear)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

#Preview {
    WebDetailView(url: "https://www.google.com")
}

