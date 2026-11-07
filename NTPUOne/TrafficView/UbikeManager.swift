import Foundation
import SwiftUI

class UbikeManager: ObservableObject {
    @Published var bikeDatas: [UBResults]?
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?

    private var task: Task<Void, Never>?

    /// Fetch every page before filtering. Station positions in the feed are not stable.
    func fetchData() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isLoading = false }
            do {
                let stations = try await Self.fetchAllStations()
                self.bikeDatas = stations.filter { $0.isNearNTPU }
                    .sorted { $0.distanceFromNTPU < $1.distanceFromNTPU }
                self.lastUpdated = Date()
            } catch {
                // Keep the last successful snapshot when a refresh fails.
                self.errorMessage = "YouBike 資料更新失敗：\(error.localizedDescription)"
            }
        }
    }

    @MainActor
    func refresh() async {
        fetchData()
        await task?.value
    }

    static func fetchAllStations(session: URLSession = .shared) async throws -> [UBResults] {
        let pageSize = 500
        var stations: [String: UBResults] = [:]
        // A bound also prevents a malformed API that repeats pages from looping forever.
        for page in 0..<100 {
            let url = URL(string: "https://data.ntpc.gov.tw/api/datasets/010E5B15-3823-4B20-B401-B1CF000550C5/json?page=\(page)&size=\(pageSize)")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let batch = try JSONDecoder().decode([UBResults].self, from: data)
            if batch.isEmpty {
                guard !stations.isEmpty else { throw URLError(.cannotParseResponse) }
                return Array(stations.values)
            }
            let previousCount = stations.count
            for station in batch { stations[station.sno] = station }
            guard stations.count > previousCount else { throw URLError(.cannotParseResponse) }
        }
        throw URLError(.dataLengthExceedsMaximum)
    }
}


struct BikeStatusView: View {
    @ObservedObject var manager: UbikeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = manager.errorMessage {
                Text(message).foregroundStyle(.secondary)
                Button("重新載入") { manager.fetchData() }
                    .disabled(manager.isLoading)
            } else if manager.isLoading {
                ProgressView("更新站點資料中…")
            }
            if let updated = manager.lastUpdated {
                Text("更新時間：\(updated.formatted(date: .omitted, time: .shortened))・校區中心 2 公里內")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct YouBikeHomePreferences: Codable, Equatable {
    static let storageKey = "youBikeHomePreferences"

    struct Rule: Codable, Equatable, Identifiable {
        var id = UUID()
        var stationID: String
        var startMinute = 7 * 60
        var endMinute = 10 * 60

        func includes(_ minute: Int) -> Bool {
            if startMinute == endMinute { return true }
            if startMinute < endMinute { return (startMinute..<endMinute).contains(minute) }
            return minute >= startMinute || minute < endMinute
        }
    }

    var defaultStationID = ""
    var rules: [Rule] = []

    static func decode(_ data: Data) -> Self {
        (try? JSONDecoder().decode(Self.self, from: data)) ?? Self()
    }

    func station(at date: Date, calendar: Calendar = .current) -> String? {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return rules.first { !$0.stationID.isEmpty && $0.includes(minute) }?.stationID
            ?? (defaultStationID.isEmpty ? nil : defaultStationID)
    }
}

#if os(iOS)
struct YouBikeHomeSettings: View {
    let stations: [UBResults]
    @AppStorage(YouBikeHomePreferences.storageKey) private var stored: Data = Data()
    @State private var preferences = YouBikeHomePreferences()

    var body: some View {
        Form {
            Section("預設站點") {
                stationPicker("站點", selection: $preferences.defaultStationID)
            }

            Section {
                ForEach($preferences.rules) { $rule in
                    VStack(alignment: .leading, spacing: 8) {
                        stationPicker("站點", selection: $rule.stationID)
                        DatePicker("開始", selection: timeBinding($rule.startMinute), displayedComponents: .hourAndMinute)
                        DatePicker("結束", selection: timeBinding($rule.endMinute), displayedComponents: .hourAndMinute)
                    }
                }
                .onDelete { preferences.rules.remove(atOffsets: $0) }
                .onMove { preferences.rules.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    let station = preferences.defaultStationID.isEmpty ? stations.first?.id ?? "" : preferences.defaultStationID
                    preferences.rules.append(.init(stationID: station))
                } label: {
                    Label("新增時段", systemImage: "plus")
                }
                .disabled(stations.isEmpty)
            } header: {
                Text("每日時段")
            } footer: {
                Text("時段重疊時以上方規則優先。結束早於開始表示跨午夜，時間相同表示全天。")
            }
        }
        .navigationTitle("首頁 YouBike")
        .toolbar { EditButton() }
        .onAppear { preferences = .decode(stored) }
        .onChange(of: preferences) { value in
            if let data = try? JSONEncoder().encode(value) { stored = data }
        }
    }

    private func stationPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(selection: selection) {
            Text("未選擇").tag("")
            if !selection.wrappedValue.isEmpty, !stations.contains(where: { $0.id == selection.wrappedValue }) {
                Text("站點暫無資料").tag(selection.wrappedValue)
            }
            ForEach(stations) { station in
                Text(station.displayName).tag(station.id)
            }
        } label: {
            Text(title)
        }
    }

    private func timeBinding(_ minute: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minute.wrappedValue / 60, minute: minute.wrappedValue % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minute.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}
#endif
