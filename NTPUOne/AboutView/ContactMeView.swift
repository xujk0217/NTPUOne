//
//  ContactMeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI
import SafariServices
import FirebaseAuth
import Security
import CryptoKit

struct ContactMeView: View {
    @Environment(\.openURL) private var openURL

    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    @EnvironmentObject var adFree: AdFreeService
    
    // admin
    @AppStorage("isAdmin") private var isAdmin: Bool = false
    @State private var tapCount = 0
    @State private var showPasswordPrompt = false
    @State private var passwordInput = ""
    @State private var showAdminNotice = false
    @State private var adminNotice = ""
    @State private var settingPassword = false
    @State private var confirmationInput = ""
    @State private var pendingAdminUID = ""
    
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
                    prepareAdminUnlock()
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
                    icon: "envelope",
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.blue)
        .alert(String(localized: settingPassword ? "admin_password_create_title" : "enter_admin_password"), isPresented: $showPasswordPrompt) {
            SecureField(String(localized: "password"), text: $passwordInput)
            if settingPassword {
                SecureField(String(localized: "admin_password_confirm"), text: $confirmationInput)
            }
            Button(String(localized: "confirm")) { completeAdminUnlock() }
            Button(String(localized: "cancel"), role: .cancel) { clearPasswordFields() }
        } message: {
            if settingPassword { Text(String(localized: "admin_password_local_explanation")) }
        }
        .alert(String(localized: "admin_password_notice_title"), isPresented: $showAdminNotice) {
            Button("OK", role: .cancel) { }
        } message: { Text(adminNotice) }
        .onDisappear { clearPasswordFields() }
        if !adFree.isAdFree{
            // Native 廣告
            Section {
                NativeAdSectionView(style: .compact)
                    .frame(height: 140)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
    private func clearPasswordFields() {
        passwordInput = ""
        confirmationInput = ""
        pendingAdminUID = ""
    }

    private func notice(_ key: String.LocalizationValue) {
        adminNotice = String(localized: key)
        showAdminNotice = true
    }

    private func prepareAdminUnlock() {
        guard let user = Auth.auth().currentUser, user.isEmailVerified,
              CommunityProfileManager.isPrivilegedAdminEmail else {
            notice("admin_password_sign_in_required")
            return
        }
        do {
            settingPassword = try !AdminLocalSecurity.hasPassword(uid: user.uid)
            pendingAdminUID = user.uid
            showPasswordPrompt = true
        } catch { notice("admin_password_keychain_error") }
    }

    private func completeAdminUnlock() {
        defer { clearPasswordFields() }
        guard let user = Auth.auth().currentUser, user.uid == pendingAdminUID, user.isEmailVerified,
              CommunityProfileManager.isPrivilegedAdminEmail else {
            notice("admin_password_sign_in_required")
            return
        }
        do {
            if settingPassword {
                guard (12...128).contains(passwordInput.count), passwordInput.contains(where: { !$0.isWhitespace }) else { notice("admin_password_length_error"); return }
                guard passwordInput == confirmationInput else { notice("admin_password_mismatch"); return }
                try AdminLocalSecurity.createPassword(passwordInput, uid: user.uid)
            } else if try !AdminLocalSecurity.verifyPassword(passwordInput, uid: user.uid) {
                notice("wrong_password")
                return
            }
            UserDefaults.standard.set(user.uid, forKey: "adminAuthorizedUID")
            isAdmin = true
            CommentBadgeManager.shared.refreshBadgeForAdminStatusChange()
            adFree.refresh()
        } catch { notice("admin_password_keychain_error") }
    }

}

/// A device-local UI lock; server-side Firebase rules remain the authority for admin data.
enum AdminLocalSecurity {
    private static let service = "com.xujk.NTPUOne.AdminLocalPassword"
    private static let sessionVersionKey = "adminLocalSecurityVersion"
    private static let uidKey = "adminAuthorizedUID"

    enum Failure: Error { case keychain(OSStatus) }

    private static func query(uid: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: uid,
         kSecAttrSynchronizable as String: false]
    }

    static func hasPassword(uid: String) throws -> Bool {
        var request = query(uid: uid)
        request[kSecReturnAttributes as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else { throw Failure.keychain(status) }
        return true
    }

    static func createPassword(_ password: String, uid: String) throws {
        var item = query(uid: uid)
        item[kSecValueData as String] = Data(password.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        // Never overwrite an existing credential, even if a previous read failed.
        guard status == errSecSuccess else { throw Failure.keychain(status) }
    }

    static func verifyPassword(_ password: String, uid: String) throws -> Bool {
        var request = query(uid: uid)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        guard status == errSecSuccess, let stored = result as? Data else { throw Failure.keychain(status) }
        // Fixed-length digest comparison avoids early-exit comparison of password bytes.
        let expected = Array(SHA256.hash(data: stored))
        let candidate = Array(SHA256.hash(data: Data(password.utf8)))
        return zip(expected, candidate).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    static func migrateLegacySession() {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: sessionVersionKey) < 1 else { return }
        defaults.set(false, forKey: "isAdmin")
        defaults.removeObject(forKey: uidKey)
        defaults.set(1, forKey: sessionVersionKey)
    }

    @MainActor static func reconcileSession(user: User?) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "isAdmin") else { return }
        guard let user, user.uid == defaults.string(forKey: uidKey), user.isEmailVerified,
              CommunityProfileManager.isPrivilegedAdminEmail else {
            defaults.set(false, forKey: "isAdmin")
            defaults.removeObject(forKey: uidKey)
            CommentBadgeManager.shared.refreshBadgeForAdminStatusChange()
            AdFreeService.shared.refresh()
            return
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
