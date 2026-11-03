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
    @EnvironmentObject private var adFree: AdFreeService
    var body: some View {
        VStack(spacing: 0) {
            WebView(urlString: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !adFree.isAdFree {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color.clear)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

#Preview {
    WebDetailView(url: "https://www.google.com").environmentObject(AdFreeService.shared)
}

