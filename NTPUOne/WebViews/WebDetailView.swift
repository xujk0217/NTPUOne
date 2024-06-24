//
//  WebDetailView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import WebKit

struct WebDetailView: View {
    let url: String?
    var body: some View {
        WebView(urlString: url)
            .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    WebDetailView(url: "https://www.google.com")
}

