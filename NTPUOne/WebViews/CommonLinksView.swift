//
//  CommonLinksView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/3/7.
//

import SwiftUI
import SafariServices

struct CommonLinksView: View {
    @StateObject private var webManager = WebManager()
    @EnvironmentObject var adFree: AdFreeService
    
    var body: some View {
        VStack {
            List {
                ForEach(webManager.websArray) { webs in
                    Section(header: Text(webs.title), footer: footerText(for: webs.id)) {
                        if webs.id == 3 {
                            disclosureGroup(for: webs)
                        } else if webs.id == 4 {
                            if let calendar = webManager.Calendar {
                                webLinks(for: calendar)
                                if let message = webManager.calendarErrorMessage {
                                    Text(message).font(.caption).foregroundStyle(.secondary)
                                    Button("重新載入行事曆") { webManager.refreshCalendar() }
                                }
                            } else {
                                Section {
                                    VStack {
                                        ProgressView("Loading...")
                                            .progressViewStyle(CircularProgressViewStyle())
                                    }
                                } footer: {
                                    Text(String(localized: "connecting_check_network"))
                                }
                            }
                        } else {
                            webLinks(for: webs.webs)
                        }
                    }
                    
                    // 在系網 Section 後插入 Native 廣告
                    if webs.id == 3 && !adFree.isAdFree {
                        Section {
                            NativeAdSectionView(style: .compact)
                                .frame(height: 140)
                        }
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                
                // 列表底部 Native 廣告 Section
                if !adFree.isAdFree {
                    Section {
                        NativeAdSectionView(style: .compact)
                            .frame(height: 140)
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
        }
        .navigationTitle(String(localized: "common_links"))
        .onAppear {
            webManager.createData()
        }
    }
    
    private func disclosureGroup(for webs: WebsArray) -> some View {
        DisclosureGroup(String(localized: "department_websites")) {
            ForEach(webs.webs) { web in
                webLinkButton(for: web)
            }
        }
        .frame(height: 50)
        .font(.callout.bold())
    }
    
    private func webLinks(for webs: [WebData]) -> some View {
        ForEach(webs) { web in
            webLinkButton(for: web)
        }
        .frame(height: 50)
    }
    
    private func webLinkButton(for web: WebData) -> some View {
        Button {
            openURL(web.url)
        } label: {
            webLinkLabel(for: web)
        }
    }
    
    private func openURL(_ urlString: String) {
        if urlString == "https://past-exam.ntpu.cc" {
            // 用外部瀏覽器開啟
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } else {
            // 用 SFSafariViewController 開啟（內嵌瀏覽器）
            if let url = URL(string: urlString) {
                if let topViewController = UIApplication.shared.windows.first?.rootViewController {
                    let safariVC = SFSafariViewController(url: url)
                    topViewController.present(safariVC, animated: true, completion: nil)
                }
            }
        }
    }
    
    private func webLinkLabel(for web: WebData) -> some View {
        HStack(spacing: 12) {
            // 圖示徽章
            Image(systemName: web.image)
                .font(.system(size: 20))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // 標題 + 網域（可選）
            VStack(alignment: .leading, spacing: 2) {
                Text(web.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let h = host(from: web.url) {
                    Text(h)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
    
    private func host(from urlString: String) -> String? {
        URL(string: urlString)?.host
    }
    
    private func footerText(for id: Int) -> some View {
        Group {
            if id == 2 {
                Text(String(localized: "course_selection_desktop_hint"))
            } else if id == 3 {
                Text(String(localized: "graduate_abbreviation_hint"))
            }
        }
    }
}

#Preview {
    CommonLinksView()
}
