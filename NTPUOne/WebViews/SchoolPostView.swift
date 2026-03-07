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
            List {
                ForEach(postManager.publications, id: \._id) { publication in
                    if publication.title != "" {
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
                
                // Native 廣告 Section
                if !adFree.isAdFree {
                    Section {
                        NativeAdSectionView(style: .compact)
                            .frame(height: 140)
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .onAppear {
                postManager.fetchPublications()
            }
            .navigationTitle("學校公告")
            .toolbar {
                ToolbarItem {
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
        }
    }
}

#Preview {
    SchoolPostView()
}
