import Foundation

class WeatherManager: ObservableObject {
    @Published var weatherDatas: WeatherResults?

    func fetchData() {
        Task { @MainActor in
            do { weatherDatas = try await Self.loadObservation() }
            catch { /* Keep the last successful observation. */ }
        }
    }

    /// Returns observation data only; the service credential never enters AI context.
    static func loadObservation() async throws -> WeatherResults {
        guard let url = URL(string: "https://opendata.cwa.gov.tw/api/v1/rest/datastore/O-A0003-001?Authorization=CWA-0DC17557-999D-4A6F-949A-0F8418E1C095&StationId=72AI40") else { throw URLError(.badURL) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url?.host == url.host, data.count <= 2_097_152 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(WeatherResults.self, from: data)
    }
}
