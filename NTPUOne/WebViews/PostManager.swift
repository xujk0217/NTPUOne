//
//  PostManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/9/8.
//

import Foundation
import Combine

class PostManager: ObservableObject {
    @Published var publications: [Publication] = []
    
    // 發送 GraphQL 請求並更新 publications 數據
    func fetchPublications() {
        let publishAt = getCurrentISO8601String()
        let unPublishAt = getCurrentISO8601String() 
        
        let query = """
            {
                publicationsConnection(
                  where: {
                    isEvent: false
                    sitesApproved_in: "www_ntpu"
                    lang_ne: "english"
                    publishAt_lte: "\(publishAt)"
                    unPublishAt_gte: "\(unPublishAt)"
                  }
                ) {
                  aggregate {
                    count
                  }
                }
                publications(
                  sort: "publishAt:desc,createdAt:desc"
                  start: 0
                  limit: 20
                  where: {
                    isEvent: false
                    sitesApproved_in: "www_ntpu"
                    lang_ne: "english"
                    publishAt_lte: "\(publishAt)"
                    unPublishAt_gte: "\(unPublishAt)"
                  }
                ) {
                  _id
                  createdAt
                  title
                  content
                  title_en
                  content_en
                  tags
                  coverImage {
                    url
                  }
                  coverImageDesc
                  coverImageDesc_en
                  bannerLink
                  files {
                    url
                    name
                    mime
                  }
                  fileMeta
                  publishAt
                }
            }
            """
        
        guard let url = URL(string: "https://api-carrier.ntpu.edu.tw/strapi") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        //header
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["query": query]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let decodedResponse = try? JSONDecoder().decode(GraphQLResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.publications = decodedResponse.data.publications
                }
            } else {
                print("Failed to decode response")
            }
        }.resume()
    }
    
    func getCurrentISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let currentDate = Date()
        return formatter.string(from: currentDate)
    }
}

// 模型定義
struct GraphQLResponse: Codable {
    let data: DataResponse
}

struct DataResponse: Codable {
    let publications: [Publication]
}

struct Publication: Codable {
    let _id: String
    let createdAt: String?
    let title: String?
    let content: String?
    let title_en: String?
    let content_en: String?
    let tags: [String]?
    let coverImage: CoverImage?
    let bannerLink: String?
    let files: [File]?
}

struct CoverImage: Codable {
    let url: String?
}

struct File: Codable {
    let url: String
    let name: String
    let mime: String
}
