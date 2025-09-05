//
//  BugReport.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/9/6.
//


import FirebaseFirestoreSwift

struct BugReport: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var issue: String
    var detail: String
    var email: String
    var date: Double? // 可選（你目前沒寫入也OK）
}

struct FeatureRequest: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var issue: String
    var detail: String
    var email: String
    var date: Double?
}
