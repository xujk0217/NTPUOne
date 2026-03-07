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
    
    // admin
    @AppStorage("isAdmin") private var isAdmin: Bool = false
    private let correctPassword = "910351"
    @State private var tapCount = 0
    @State private var showPasswordPrompt = false
    @State private var passwordInput = ""
    @State private var showWrongPasswordAlert = false
    
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
            } header: { Text(String(localized: "name_header")) }
            .onTapGesture {
                tapCount += 1
                if tapCount >= 15 {
                    tapCount = 0
                    showPasswordPrompt = true
                }
            }
            
            // Social
            Section(String(localized: "social_section")) {
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
                    Button(String(localized: "copy_account"), systemImage: "doc.on.doc") {
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
                    Button(String(localized: "copy_email"), systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = "kevin16021777@gmail.com"
                    }
                }
            }
            if isAdmin {
                Section("Admin"){
                    VStack(spacing: 15) {
                        Text(String(localized: "you_are_admin"))
                            .foregroundColor(.green)

                        Button(String(localized: "logout_admin")) {
                            isAdmin = false
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.blue)
        .alert(String(localized: "enter_admin_password"), isPresented: $showPasswordPrompt) {
            SecureField(String(localized: "password"), text: $passwordInput)

            Button(String(localized: "confirm")) {
                if passwordInput == correctPassword {
                    isAdmin = true   // ✅ 登入成功
                    adFree.refresh()
                } else {
                    showWrongPasswordAlert = true
                }
                passwordInput = ""
            }

            Button(String(localized: "cancel"), role: .cancel) {
                passwordInput = ""
            }
        }
        .alert(String(localized: "wrong_password"), isPresented: $showWrongPasswordAlert) {
            Button("OK", role: .cancel) {}
        }
        if !adFree.isAdFree{
            // Native 廣告
            Section {
                NativeAdSectionView(style: .compact)
                    .frame(height: 140)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
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
