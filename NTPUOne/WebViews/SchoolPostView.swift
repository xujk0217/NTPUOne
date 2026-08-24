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
    @StateObject private var studentImpactStore = StudentImpactStore.shared
    @EnvironmentObject var adFree: AdFreeService
    @ObservedObject var memoManager: MemoManager
    @ObservedObject var courseData: CourseData
    
    @State private var showSafariView = false
    private let safariURL = URL(string: "https://new.ntpu.edu.tw/news")!

    private func favoriteForPublication(_ publication: Publication) -> EventFavorite {
        EventFavorite(
            id: publication.favoriteID,
            title: publication.favoriteTitle,
            source: "公告",
            dateText: publication.favoriteDateText.isEmpty ? nil : publication.favoriteDateText,
            link: "https://new.ntpu.edu.tw/news",
            savedAt: Date()
        )
    }

    private func togglePublicationFavorite(_ publication: Publication) {
        studentImpactStore.toggleEventFavorite(favoriteForPublication(publication))
    }

    
    var body: some View {
        NavigationStack{
            List {
                ForEach(postManager.publications, id: \._id) { publication in
                    if publication.title != "" {
                        HStack(spacing: 10) {
                            NavigationLink {
                                PostDetailView(memoManager: memoManager, courseData: courseData, publication: publication)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(publication.favoriteTitle)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(publication.favoriteDateText.isEmpty ? String(localized: "time_unprovided") : publication.favoriteDateText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Button {
                                togglePublicationFavorite(publication)
                            } label: {
                                Image(systemName: studentImpactStore.isEventFavorite(id: publication.favoriteID) ? "star" : "star")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.yellow)
                                    .frame(width: 34, height: 34)
                                    .background(Color.yellow.opacity(0.14), in: Circle())
                        }
                            .buttonStyle(.plain)
                            .accessibilityLabel(studentImpactStore.isEventFavorite(id: publication.favoriteID) ? String(localized: "favorite_remove") : String(localized: "favorite_add"))
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
            .navigationTitle(String(localized: "school_announcements"))
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
    SchoolPostView(memoManager: MemoManager(), courseData: CourseData())
}
