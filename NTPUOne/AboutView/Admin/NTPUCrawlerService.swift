//
//  NTPUCrawlerService.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/2/9.
//

import Foundation
import SwiftUI

/// 爬蟲抓取的原始資料
struct CrawledBanner: Identifiable, Equatable {
    let id = UUID()
    let imageURL: String      // 圖片網址
    let linkPath: String      // 相對連結路徑
    let altText: String       // 圖片 alt 文字（標題）
    
    /// 完整連結網址
    var fullURL: String {
        if linkPath.hasPrefix("http") {
            return linkPath
        }
        return "https://new.ntpu.edu.tw/\(linkPath)"
    }
    
    /// 轉換為備取 Order
    func toPendingOrder() -> PendingOrder {
        PendingOrder(
            message: "請更新至最新版本以查看新的公告類型",
            name: "北大好夥伴",
            url: fullURL,
            tag: "3",
            time: imageURL,        // time 存圖片網址
            email: imageURL,       // email 存圖片網址
            date: Date().timeIntervalSince1970,
            altText: altText
        )
    }
}

/// 備取 Order（尚未上傳到 Firebase）
struct PendingOrder: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var name: String
    var url: String
    var tag: String
    var time: String
    var email: String
    var date: Double
    var altText: String       // 爬蟲抓到的標題
    
    /// 是否為圖片型 Order（email 和 time 相同且是有效的圖片網址）
    var isImageOrder: Bool {
        !email.isEmpty && email == time && isValidImageURL(email)
    }
    
    private func isValidImageURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp"]
        let ext = url.pathExtension.lowercased()
        // 檢查副檔名或是否來自 NTPU CMS
        return imageExtensions.contains(ext) || urlString.contains("cms-carrier.ntpu.edu.tw")
    }
}

/// NTPU 網站爬蟲服務
class NTPUCrawlerService: ObservableObject {
    @Published var crawledBanners: [CrawledBanner] = []
    @Published var pendingOrders: [PendingOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCrawledDate: Date?
    
    private let baseURL = "https://new.ntpu.edu.tw/"
    
    /// 從 NTPU 網站爬取輪播圖資料
    func crawlBanners() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            guard let url = URL(string: baseURL) else {
                throw CrawlerError.invalidURL
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw CrawlerError.invalidResponse
            }
            
            guard let html = String(data: data, encoding: .utf8) else {
                throw CrawlerError.decodingError
            }
            
            let banners = parseHTML(html)
            
            await MainActor.run {
                self.crawledBanners = banners
                self.pendingOrders = banners.map { $0.toPendingOrder() }
                self.isLoading = false
                self.lastCrawledDate = Date()
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// 解析 HTML 抓取 swiper-slide 資料
    private func parseHTML(_ html: String) -> [CrawledBanner] {
        var banners: [CrawledBanner] = []
        
        // 使用正則表達式匹配 swiper-slide 區塊
        // 匹配模式：<div ... class="swiper-slide ..."> ... <img src="..." alt="..."> ... <a ... href="..."> ... </div>
        
        let slidePattern = #"<div[^>]*class=\"swiper-slide[^\"]*\"[^>]*>.*?<img[^>]*src=\"([^\"]+)\"[^>]*alt=\"([^\"]*)\".*?<a[^>]*href=\"([^\"]+)\".*?</div>"#
        
        do {
            let regex = try NSRegularExpression(pattern: slidePattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            for match in matches {
                guard match.numberOfRanges >= 4 else { continue }
                
                // 提取 src (圖片網址)
                guard let srcRange = Range(match.range(at: 1), in: html) else { continue }
                let imageURL = String(html[srcRange])
                
                // 提取 alt (標題)
                guard let altRange = Range(match.range(at: 2), in: html) else { continue }
                let altText = String(html[altRange])
                
                // 提取 href (連結)
                guard let hrefRange = Range(match.range(at: 3), in: html) else { continue }
                let linkPath = String(html[hrefRange])
                
                // 過濾掉非 CMS 圖片
                if imageURL.contains("cms-carrier.ntpu.edu.tw") {
                    let banner = CrawledBanner(
                        imageURL: imageURL,
                        linkPath: linkPath,
                        altText: altText
                    )
                    banners.append(banner)
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return banners
    }
    
    /// 移除備取 Order
    func removePendingOrder(_ order: PendingOrder) {
        pendingOrders.removeAll { $0.id == order.id }
    }
    
    /// 清空所有備取 Order
    func clearAllPendingOrders() {
        pendingOrders.removeAll()
    }
    
    enum CrawlerError: LocalizedError {
        case invalidURL
        case invalidResponse
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "無效的網址"
            case .invalidResponse: return "伺服器回應錯誤"
            case .decodingError: return "解析資料失敗"
            }
        }
    }
}
