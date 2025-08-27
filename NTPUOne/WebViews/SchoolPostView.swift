//
//  SchoolPostView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/9/7.
//

import SwiftUI
import SafariServices

struct SchoolPostView: View {
    
    @StateObject private var postManager = PostManager()
    @EnvironmentObject var adFree: AdFreeService
    @State private var showSafariView = false
    private let safariURL = URL(string: "https://new.ntpu.edu.tw/news")!

    
    var body: some View {
        NavigationStack{
            Section{
                List(postManager.publications, id: \._id) { publication in
                    if publication.title != ""{
                        NavigationLink {
                            PostDetailView(publication: publication)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(publication.title ?? "No Title")
                                    .font(.headline)
                                Text(publication.createdAt?.prefix(10) ?? "No Time")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .onAppear {
                postManager.fetchPublications()
            }
            .navigationTitle("學校公告")
            .toolbar{
                ToolbarItem{
                    Button {
                        showSafariView.toggle()
                    } label: {
                        Image(systemName: "link")
                    }

                }
            }
            .sheet(isPresented: $showSafariView) {
                SafariView(url: safariURL)
            }
            if !adFree.isAdFree{
                // 廣告標記
                Section {
                    BannerAdView()
                        .frame(height: 50)
                }
            }
        }
    }
}

#Preview {
    SchoolPostView()
}
