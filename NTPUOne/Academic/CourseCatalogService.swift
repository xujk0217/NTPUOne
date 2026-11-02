import Foundation
import SwiftSoup

enum CourseCatalogService {
    static let endpoint = URL(string: "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.queryByKeyword")!

    static func request(year: String, term: String, code: String, keyword: String = "") -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = ["qYear": year, "qTerm": term, "courseno": code, "cour": keyword, "teach": "", "week": "", "seq1": "A", "seq2": "M"]
            .sorted(by: { $0.key < $1.key }).map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = body.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        return request
    }

    static func decode(_ data: Data) throws -> String {
        let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))
        guard let html = NSString(data: data, encoding: encoding) as String? else { throw AcademicError.invalidResponse }
        return html
    }

    static func search(year: String, term: String, code: String, keyword: String = "") async throws -> [CourseG] {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request(year: year, term: term, code: code, keyword: keyword))
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url?.host == endpoint.host, data.count <= 2_097_152 else { throw AcademicError.invalidResponse }
        return try parse(try decode(data))
    }

    /// Shared by manual search and academic import; no HTML logging or UI side effects.
    static func parse(_ html: String) throws -> [CourseG] {
        let document = try SwiftSoup.parse(html)
        guard try document.select("table#example").first() != nil else { throw AcademicError.invalidResponse }
        return try document.select("table#example tbody tr").compactMap { row in
            let columns = try row.select("td")
            guard columns.count >= 15 else { return nil }
            let code = try columns[3].text()
            let title = try columns[7].select("a").first()?.text() ?? columns[7].text()
            let text = try columns[13].text()
            let components = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            let scheduleHTML = try columns[13].html().replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            // Preserve line breaks before stripping tags, unlike Element.text().
            let schedule = try scheduleHTML.components(separatedBy: "\n").map { try SwiftSoup.parseBodyFragment($0).text() }.joined(separator: "\n")
            return CourseG(courseno: code, courseName: title, teacher: try columns[8].text(),
                           time: components.first ?? "", location: components.dropFirst().joined(separator: " "), scheduleText: schedule)
        }
    }
}
