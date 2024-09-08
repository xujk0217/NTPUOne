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
    @StateObject private var postManager = PostManager()
    var publication: Publication
    let baseURL = "https://cms-carrier.ntpu.edu.tw"
    var body: some View {
        ScrollView{
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
//                    Text(content)
//                        .font(.body)
                    HTMLView(htmlString: content)
                          .frame(height: 400)
                }
                
                // 文件附件
                if let files = publication.files {
                    ForEach(files, id: \.url) { file in
                        FileLinkView(urlString: baseURL+file.url, fileName: file.name)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("公告內文")
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
