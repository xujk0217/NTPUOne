//
//  ContactMeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI
import SafariServices

struct ContactMeView: View {
    var body: some View {
        VStack {
            List {
                Section{
                    HStack{
                        Image(systemName: "figure.rolling")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                        Divider()
                        Text("xujk")
                            .font(.title3)
                            .padding()
                    }
                } header: {
                    Text("名字")
                }
                Section {
                    Button {
                        UIApplication.shared.open(URL(string: "https://www.instagram.com/ntpuone_jk?igsh=ZG52MHc4MXdmZGFy&utm_source=qr")!)
                    } label: {
                        Text("ntpu_jk")
                    }

                } header: {
                    Text("Instagram")
                }
                Section {
                    Text("kevin16021777@gmail.com")
                } header: {
                    Text("email")
                }
                // 廣告標記
                Section {
                    BannerAdView()
                            .frame(height: 50) // 橫幅廣告的高度通常是 50
                } header: {
                    Text("廣告")
                }
            }
        }.navigationTitle("Contact")
    }
}

#Preview {
    ContactMeView()
}

extension ContactMeView{
    func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                // 打开 SafariViewController
                if let topViewController = UIApplication.shared.windows.first?.rootViewController {
                    let safariVC = SFSafariViewController(url: url)
                    topViewController.present(safariVC, animated: true, completion: nil)
                }
            } else {
                print("Cannot open URL: \(urlString)")
            }
        }
    }
}
