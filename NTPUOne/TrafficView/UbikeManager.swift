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
