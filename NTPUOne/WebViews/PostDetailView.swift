//
//  PostDetailView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/9/8.
//

import SwiftUI
import WebKit

struct HTMLView: UIViewRepresentable {
    let htmlString: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("Loading HTML: \(htmlString)")
        uiView.loadHTMLString("<html><body>"+htmlString+"</body></html>", baseURL: nil)
    }
}

struct PostDetailView: View {
    @StateObject private var studentImpactStore = StudentImpactStore.shared
    @EnvironmentObject var adFree: AdFreeService
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    @State private var showMemoDraft = false
    var publication: Publication
    let baseURL = "https://cms-carrier.ntpu.edu.tw"
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 圖片
                    if let imageUrl = publication.coverImage?.url, let url = URL(string: imageUrl) {
                        AsyncImage(url: URL(string: baseURL + imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                    
                    if let title = publication.title {
                        Text(title)
                            .font(.title)
                            .bold()
                    }
                    if let content = publication.content {
                        HTMLView(htmlString: content)
                            .frame(height: 400)
                    }
                    
                    // 文件附件
                    if let files = publication.files {
                        ForEach(files, id: \.url) { file in
                            FileLinkView(urlString: baseURL+file.url, fileName: file.name)
                        }
                    }
                    
                    // Native 廣告（在 ScrollView 內）
                    if !adFree.isAdFree {
                        NativeAdSectionView(style: .compact)
                            .frame(height: 140)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(String(localized: "post_content_title"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    toggleFavorite()
                } label: {
                    Label(isFavorite ? String(localized: "favorite_remove") : String(localized: "favorite_add"), systemImage: isFavorite ? "star" : "star")
                }

                Button {
                    showMemoDraft = true
                } label: {
                    Label(String(localized: "add_to_memo"), systemImage: "checklist")
                }
            }
        }
        .sheet(isPresented: $showMemoDraft) {
            MemoFormView(
                memoManager: memoManager,
                courseData: courseData,
                memo: nil,
                presetTitle: officialPostMemoTitle,
                presetContent: officialPostMemoContent,
                presetTagType: .activity
            )
        }
    }

    private var officialPostMemoTitle: String {
        publication.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? publication.title! : String(localized: "official_post_default_title")
    }

    private var favorite: EventFavorite {
        EventFavorite(
            id: publication.favoriteID,
            title: publication.favoriteTitle,
            source: "公告",
            dateText: publication.favoriteDateText.isEmpty ? nil : publication.favoriteDateText,
            link: "https://new.ntpu.edu.tw/news",
            savedAt: Date()
        )
    }

    private var isFavorite: Bool {
        studentImpactStore.isEventFavorite(id: publication.favoriteID)
    }

    private func toggleFavorite() {
        studentImpactStore.toggleEventFavorite(favorite)
    }

    private var officialPostMemoContent: String {
        var lines: [String] = [
            String(localized: "memo_source_ntpu_official_post"),
            "\(String(localized: "memo_post_time_label"))：\(publication.createdAt.map { String($0.prefix(10)) } ?? String(localized: "memo_unprovided"))",
            "\(String(localized: "memo_source_link_label"))：https://new.ntpu.edu.tw/news"
        ]

        if let content = publication.content?.strippingHTML, !content.isEmpty {
            lines.append("")
            lines.append(content)
        }

        if let files = publication.files, !files.isEmpty {
            lines.append("")
            lines.append(String(localized: "memo_attachments_label"))
            lines.append(contentsOf: files.map { "\($0.name)：\(baseURL)\($0.url)" })
        }

        return lines.joined(separator: "\n")
    }
}

private extension String {
    var strippingHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct FileLinkView: View {
    let urlString: String
        let fileName: String
    
    @State private var showWebView = false
    
    var body: some View {
        Button(action: {
            showWebView.toggle()
        }) {
            HStack {
                Image(systemName: "doc.text")
                Text(fileName)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showWebView) {
            NavigationView {
                WebView(urlString: urlString)
                    .navigationTitle(fileName)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showWebView.toggle()
                            }
                        }
                    }
            }
        }
    }
}
