//
//  FManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/1.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift

class FManager: ObservableObject {
    @Published var Food: [FDetail]?
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var activeCollectionName: String?

    deinit {
        listener?.remove()
    }
    
    func loadF(whichDiet: String) {
        var collectName = ""
        if whichDiet == "B" {
            collectName = K.FStoreF.collectionNameB
        } else if whichDiet == "L" {
            collectName = K.FStoreF.collectionNamel
        } else if whichDiet == "D" {
            collectName = K.FStoreF.collectionNamed
        } else {
            collectName = K.FStoreF.collectionNamem
        }

        if activeCollectionName == collectName, listener != nil {
            return
        }

        listener?.remove()
        Food = nil
        activeCollectionName = collectName

        listener = db.collection(collectName)
            .order(by: K.FStoreF.starField, descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self else { return }
                guard self.activeCollectionName == collectName else { return }
                if let e = error {
                    print("There is an issue: \(e)")
                    DispatchQueue.main.async {
                        self.Food = []
                    }
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        print("success get order")
                        var newFoods = [FDetail]()
                        for doc in snapshotDocuments {
                            do {
                                var food = try doc.data(as: FDetail.self)
                                food.id = doc.documentID
                                newFoods.append(food)
                            } catch {
                                print("Error decoding document: \(error)")
                            }
                        }
                        DispatchQueue.main.async {
                            self.Food = newFoods
                        }
                    }
                }
            }
    }
    
    func getCollectionName(for diet: String) -> String {
        switch diet {
        case "B": return K.FStoreF.collectionNameB
        case "L": return K.FStoreF.collectionNamel
        case "D": return K.FStoreF.collectionNamed
        default:  return K.FStoreF.collectionNamem
        }
    }
    
    /// 原子遞增星數（支援 +/−，多人同時操作不會彼此覆蓋）
    func incrementStar(diet: String, id: String, delta: Double) {
        Self.incrementStar(collectionName: getCollectionName(for: diet), id: id, delta: delta)
    }

    static func incrementStar(
        collectionName: String,
        id: String,
        delta: Double,
        completion: ((Error?) -> Void)? = nil
    ) {
        Firestore.firestore().collection(collectionName).document(id).updateData([
            K.FStoreF.starField: FieldValue.increment(delta)
        ]) { err in
            if let err = err { print("incrementStar failed: \(err)") }
            completion?(err)
        }
    }

    /// 批次更新欄位（保留其他欄位）
    func updateFoodFields(diet: String, id: String, fields: [String: Any]) {
        let col = getCollectionName(for: diet)
        db.collection(col).document(id).updateData(fields) { err in
            if let err = err { print("updateFoodFields failed: \(err)") }
        }
    }

    /// 刪除指定餐廳
    func deleteFood(diet: String, id: String) {
        let col = getCollectionName(for: diet)
        db.collection(col).document(id).delete { err in
            if let err = err { print("deleteFood failed: \(err)") }
        }
    }

}

struct FDetail: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let store: String
    let time: String
    let url: String
    let address: String
    let phone: String
    var starNum: Double
    let lat: Double
    let lng: Double
    let check: Bool
}

enum FoodMealWindow: String, Equatable {
    case breakfast
    case lunch
    case dinner
    case midnightSnack

    var dietCode: String {
        switch self {
        case .breakfast: return "B"
        case .lunch: return "L"
        case .dinner: return "D"
        case .midnightSnack: return "M"
        }
    }

    var collectionName: String {
        switch self {
        case .breakfast: return K.FStoreF.collectionNameB
        case .lunch: return K.FStoreF.collectionNamel
        case .dinner: return K.FStoreF.collectionNamed
        case .midnightSnack: return K.FStoreF.collectionNamem
        }
    }

    var title: String {
        switch self {
        case .breakfast: return String(localized: "breakfast")
        case .lunch: return String(localized: "lunch")
        case .dinner: return String(localized: "dinner")
        case .midnightSnack: return String(localized: "late_night_snack")
        }
    }

    static func current(now: Date = Date(), calendar: Calendar = .current) -> FoodMealWindow {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .midnightSnack
        }
    }

    func cacheKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let adjustedDate: Date
        if self == .midnightSnack, calendar.component(.hour, from: now) < 4 {
            adjustedDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        } else {
            adjustedDate = now
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(rawValue)-\(formatter.string(from: adjustedDate))"
    }
}

struct FoodRecommendation {
    static func recommendedRestaurant(from foods: [FDetail], cachedID: String?, now: Date = Date()) -> FDetail? {
        let checkedFoods = foods.filter(\.check)
        let basePool = checkedFoods.isEmpty ? foods : checkedFoods
        // 只推薦「確定營業中」的店家；時間格式不明（unknown）一律不推薦
        let openPool = basePool.filter { FoodFiltering.openingState(for: $0.time, now: now) == .open }
        guard !openPool.isEmpty else { return nil }

        if let cachedID, let cached = openPool.first(where: { $0.id == cachedID }) {
            return cached
        }

        return openPool.randomElement()
    }
}

enum FoodListFilter: String, CaseIterable, Identifiable {
    case popular
    case openNow
    case nearby

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popular: return String(localized: "food_filter_popular")
        case .openNow: return String(localized: "food_filter_open_now")
        case .nearby: return String(localized: "food_filter_nearby")
        }
    }
}

enum FoodOpeningState: Equatable {
    case open
    case closed
    case unknown
}

struct FoodFiltering {
    static func openingState(for time: String, now: Date = Date(), calendar: Calendar = .current) -> FoodOpeningState {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }
        if isAlwaysOpenText(trimmed) { return .open }

        let pairs = parseTimePairs(from: trimmed)
        guard !pairs.isEmpty else { return .unknown }

        let components = calendar.dateComponents([.hour, .minute], from: now)
        guard let hour = components.hour, let minute = components.minute else { return .unknown }
        let currentMinutes = hour * 60 + minute

        return pairs.contains(where: { isOpen(atMinutes: currentMinutes, in: $0) }) ? .open : .closed
    }

    static func filteredFoods(_ foods: [FDetail], filter: FoodListFilter, userLocation: CLLocation? = nil, now: Date = Date()) -> [FDetail] {
        switch filter {
        case .popular:
            return foods.sorted { $0.starNum > $1.starNum }
        case .openNow:
            return foods
                .filter { openingState(for: $0.time, now: now) != .closed }
                .sorted { $0.starNum > $1.starNum }
        case .nearby:
            guard let userLocation else { return foods }
            return foods.sorted { lhs, rhs in
                let lhsDistance = distance(from: userLocation, to: lhs)
                let rhsDistance = distance(from: userLocation, to: rhs)
                switch (lhsDistance, rhsDistance) {
                case let (lhs?, rhs?): return lhs < rhs
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.starNum > rhs.starNum
                }
            }
        }
    }

    static func lunchRecommendation(from foods: [FDetail], now: Date = Date()) -> FDetail? {
        let checkedFoods = foods.filter(\.check)
        let candidates = checkedFoods.filter { openingState(for: $0.time, now: now) != .closed }
        let recommendationPool = candidates.isEmpty ? checkedFoods : candidates
        let starred = recommendationPool.filter { $0.starNum > 0 }.sorted { $0.starNum > $1.starNum }

        if let best = starred.first {
            return best
        }
        return recommendationPool.randomElement()
    }

    // 解析字串內所有「HH:MM」並依出現順序兩兩配對成營業時段，
    // 支援多時段（11:00-14:00、17:00-22:00）與跨午夜（20:00-02:00）
    static func parseTimePairs(from text: String) -> [(start: Int, end: Int)] {
        let pattern = #"(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        let minutesList = matches.compactMap { minutes(from: $0, in: text) }

        var pairs: [(start: Int, end: Int)] = []
        var index = 0
        while index + 1 < minutesList.count {
            pairs.append((minutesList[index], minutesList[index + 1]))
            index += 2
        }
        return pairs
    }

    private static func isOpen(atMinutes minute: Int, in pair: (start: Int, end: Int)) -> Bool {
        if pair.start == pair.end { return true }
        if pair.start < pair.end { return minute >= pair.start && minute < pair.end }
        // 跨午夜：20:00-02:00 = 20:00 之後或 02:00 之前
        return minute >= pair.start || minute < pair.end
    }

    private static func isAlwaysOpenText(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let keywords = ["24小時", "24 小時", "24hr", "24 hr", "24小", "全天", "全年無休"]
        return keywords.contains { lowered.contains($0.lowercased()) }
    }

    private static func minutes(from match: NSTextCheckingResult, in text: String) -> Int? {
        guard match.numberOfRanges >= 3,
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hour = Int(text[hourRange]),
              let minute = Int(text[minuteRange]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return hour * 60 + minute
    }

    private static func distance(from userLocation: CLLocation, to food: FDetail) -> CLLocationDistance? {
        guard food.lat != 0, food.lng != 0 else { return nil }
        return userLocation.distance(from: CLLocation(latitude: food.lat, longitude: food.lng))
    }
}
