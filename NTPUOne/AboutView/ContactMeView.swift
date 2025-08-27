//
//  ContactMeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI
import SafariServices

struct ContactMeView: View {
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    @EnvironmentObject var adFree: AdFreeService
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
//                // 廣告標記
//                Section {
//                    NativeAdBoxView(
//                        style: .compact(media: 120),
//                        height: $adHeight
//                    )
//                    .frame(height: adHeight)
//                    .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
//                    .listRowSeparator(.hidden)
//                    .listRowBackground(Color.white)
//                    .padding(.horizontal, 8)
//                } header: {
//                    Text("廣告")
//                }
            }
        }.navigationTitle("Contact")
        if !adFree.isAdFree{
            // 廣告標記
            Section {
                BannerAdView()
                    .frame(height: 50)
            }
        }
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
