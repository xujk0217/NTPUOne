//
//  File.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation

struct K{
//    static let
    struct Community {
        /// 交流區通知總開關（2026-08 暫停：推播函式已移除、本地 fallback 已停用）。
        /// 課表、備忘錄等本地通知不受影響。要重啟時改回 true 並重新部署 functions。
        static let notificationsEnabled = false
    }
    struct Web{
        static let NTPUurl = "https://new.ntpu.edu.tw/"
    }
    struct FStoreOr {
        static let collectionName = "order"
        static let emailField = "email"
        static let messageField = "message"
        static let nameField = "name"
        static let timeField = "time"
        static let urlField = "url"
        static let dateField = "date"
        static let tagField = "tag"
    }
    
    struct FStoreF {
        static let collectionNameB = "breakfast"
        static let collectionNamel = "lunch"
        static let collectionNamed = "dinner"
        static let collectionNamem = "MS"
        static let storeField = "store"
        static let openTimeField = "time"
        static let urlField = "url"
        static let phoneField = "phone"
        static let starField = "starNum"
        static let latField = "lat"
        static let lngField = "lng"
        static let addressField = "address"
        static let checkField = "check"
    }
    
    struct FStoreR {
        static let collectionNameBug = "bug"
        static let collectionNameFt = "feature"
        static let emailField = "email"
        static let detailField = "detail"
        static let issueField = "issue"
    }

    struct Bike{
        static let NTPUBikeNum = [
            "500205050",
            "500205051",
            "500205052",
            "500205053",
            "500205054",
            "500205055",
            "500205056",
            "500205057",
            "500205058",
            "500205059",
            "500205060",
            "500205012",
            "500205014",
            "500205015",
            "500205035",
            "500205036",
            "500205037",
            "500205061",
            "500205049",
        ]
    }
}
