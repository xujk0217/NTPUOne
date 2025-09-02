//
//  ContactMeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI
import SafariServices

struct ContactMeView: View {
    @Environment(\.openURL) private var openURL

    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    @EnvironmentObject var adFree: AdFreeService
    var body: some View {
        List {
            // Profile Card
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 64, height: 64)
                        Image(systemName: "figure.rolling")
                            .font(.system(size: 28, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("xujk")
                            .font(.title3.weight(.semibold))
                        Text("NTPU One")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            } header: { Text("名字") }
            
            // Social
            Section("社群") {
                ContactLinkRow(
                    icon: "camera.aperture",
                    tint: .pink,
                    title: "Instagram",
                    subtitle: "@ntpuone_jk",
                    action: {
                        openURL(URL(string: "https://www.instagram.com/ntpuone_jk?igsh=ZG52MHc4MXdmZGFy&utm_source=qr")!)
                    }
                )
                .contextMenu {
                    Button("複製帳號", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = "ntpuone_jk"
                    }
                }
            }
            
            // Email
            Section("Email") {
                ContactLinkRow(
                    icon: "envelope.fill",
                    tint: .indigo,
                    title: "Email",
                    subtitle: "kevin16021777@gmail.com",
                    action: {
                        openURL(URL(string: "mailto:kevin16021777@gmail.com")!)
                    }
                )
                .contextMenu {
                    Button("複製 Email", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = "kevin16021777@gmail.com"
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.blue)
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


private struct ContactLinkRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // 圖示徽章
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                
                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
