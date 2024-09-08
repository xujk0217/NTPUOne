//
//  SchoolPostView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/9/7.
//

import SwiftUI

struct SchoolPostView: View {
    
    @StateObject private var postManager = PostManager()
    
    var body: some View {
        NavigationStack{
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
            .onAppear {
                postManager.fetchPublications()
            }
            .navigationTitle("學校公告")
        }
    }
}

#Preview {
    SchoolPostView()
}
