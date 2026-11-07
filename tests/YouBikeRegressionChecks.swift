import Foundation

final class StationURLProtocol: URLProtocol {
    static var responder: (URLRequest) -> (Int, Data) = { _ in (500, Data()) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.responder(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
enum YouBikeRegressionChecks {
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StationURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        func station(_ id: String, lat: String = "24.944", lng: String = "121.371") -> [String: String] {
            ["sno": id, "sna": "YouBike2.0_測試站", "snaen": "Test", "lat": lat, "lng": lng,
             "tot_quantity": "20", "sbi_quantity": "10", "bemp": "10"]
        }
        let first = try JSONSerialization.data(withJSONObject: [station("A")])
        let second = try JSONSerialization.data(withJSONObject: [station("A"), station("B")])
        var pages: [Int] = []
        StationURLProtocol.responder = { request in
            let page = Int(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
                .queryItems!.first { $0.name == "page" }!.value!)!
            pages.append(page)
            return (200, page == 0 ? first : page == 1 ? second : Data("[]".utf8))
        }
        let results = try await UbikeManager.fetchAllStations(session: session)
        precondition(Set(results.map(\.sno)) == ["A", "B"] && pages == [0, 1, 2],
                     "Must fetch until an empty page, even when a page is smaller than requested; deduplicate IDs")
        precondition(results.allSatisfy(\.isNearNTPU))
        precondition(results[0].displayName == "測試站")
        let far = try JSONDecoder().decode([UBResults].self, from: JSONSerialization.data(withJSONObject: [
            station("far", lat: "25.1", lng: "121.5"), station("invalid", lat: "invalid")
        ]))
        precondition(far.allSatisfy { !$0.isNearNTPU })

        StationURLProtocol.responder = { _ in (500, Data("[]".utf8)) }
        do {
            _ = try await UbikeManager.fetchAllStations(session: session)
            preconditionFailure("HTTP errors must be surfaced")
        } catch is URLError { }
        StationURLProtocol.responder = { _ in (200, first) }
        do {
            _ = try await UbikeManager.fetchAllStations(session: session)
            preconditionFailure("Repeated pages must stop with an error")
        } catch is URLError { }
        StationURLProtocol.responder = { _ in (200, Data("[]".utf8)) }
        do {
            _ = try await UbikeManager.fetchAllStations(session: session)
            preconditionFailure("An entirely empty feed must not look like a successful update")
        } catch is URLError { }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        func time(_ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: hour))!
        }
        let preferences = YouBikeHomePreferences(defaultStationID: "fallback", rules: [
            .init(stationID: "night", startMinute: 22 * 60, endMinute: 2 * 60),
            .init(stationID: "morning", startMinute: 60, endMinute: 3 * 60)
        ])
        precondition(preferences.station(at: time(23), calendar: calendar) == "night")
        precondition(preferences.station(at: time(1), calendar: calendar) == "night", "First matching rule wins an overlap")
        precondition(preferences.station(at: time(2), calendar: calendar) == "morning", "End time is exclusive")
        precondition(preferences.station(at: time(3), calendar: calendar) == "fallback")
        let allDay = YouBikeHomePreferences(rules: [.init(stationID: "all-day", startMinute: 60, endMinute: 60)])
        precondition(allDay.station(at: time(12), calendar: calendar) == "all-day")
        let encodedPreferences = try JSONEncoder().encode(preferences)
        precondition(YouBikeHomePreferences.decode(encodedPreferences) == preferences)
        precondition(YouBikeHomePreferences.decode(Data("invalid".utf8)).station(at: time(12), calendar: calendar) == nil)
        print("PASS: pagination, ID deduplication, campus radius, network failures, empty feed, midnight schedules, rule priority and preferences recovery")
    }
}
