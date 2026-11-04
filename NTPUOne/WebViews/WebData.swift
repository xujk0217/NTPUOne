//
//  Item.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation
import SwiftData
import FirebaseFirestore

struct WebsArray: Identifiable{
    let id: Int
    let title: String
    let webs: [WebData]
}

struct WebData: Identifiable, Decodable{
    var id: String
    let title: String
    let image: String
    let url: String
}

class WebManager: ObservableObject{
    static let officialCalendar = WebData(
        id: "official-calendar", title: "臺北大學官方行事曆（最新版本）", image: "calendar",
        url: "https://new.ntpu.edu.tw/oaa/files?descent=true&inline=1&tag=%E8%A1%8C%E4%BA%8B%E6%9B%86"
    )
    private static var cachedCalendar: [WebData]?
    private static var cacheDate: Date?

    private var db = Firestore.firestore()
    private var isLoadingCalendar = false
    
    @Published var Calendar: [WebData]? = [WebManager.officialCalendar]
    @Published private(set) var calendarErrorMessage: String?
    
    @Published var websArray:[WebsArray] = [
        WebsArray(id: 0, title: String(localized: "web_main_site"), webs: [
            WebData(id: "0", title: "NTPU", image: "graduationcap", url: "https://new.ntpu.edu.tw/"),
        ]),
        WebsArray(id: 1, title: String(localized: "web_student"), webs: [
            WebData(id: "1", title: String(localized: "web_student_info"), image: "chart.bar.doc.horizontal", url: "https://cof.ntpu.edu.tw/student_new.htm"),
            WebData(id: "2", title: String(localized: "web_lms"), image: "graduationcap.circle", url: "https://lms3.ntpu.edu.tw/"),
        ]),
        WebsArray(id: 2, title: String(localized: "web_course"), webs: [
            WebData(id: "3", title: String(localized: "web_course_search"), image: "magnifyingglass", url: "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.chi_main"),
            WebData(id: "4", title: String(localized: "web_course_review"), image: "ellipsis.message", url: "https://no21.ntpu.org/"),
            WebData(id: "5", title: String(localized: "web_past_exam"), image: "folder.badge.questionmark", url: "https://past-exam.ntpu.cc"),
        ]),
        WebsArray(id: 3, title: String(localized: "web_departments"), webs: [
            WebData(id: "6", title: String(localized: "web_law_college"), image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/law"),
            WebData(id: "7", title: String(localized: "web_business_college"), image: "macwindow.on.rectangle", url: "https://www.aacsb.ntpu.edu.tw/"),
            WebData(id: "8", title: String(localized: "web_public_affairs_college"), image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/public-affairs"),
            WebData(id: "9", title: String(localized: "web_social_science_college"), image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/social-sciences"),
            WebData(id: "10", title: String(localized: "web_humanities_college"), image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/humanities"),
            WebData(id: "11", title: String(localized: "web_eecs_college"), image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/computer-science"),
            WebData(id: "12", title: String(localized: "web_law_dept"), image: "macwindow.on.rectangle", url: "https://www.law.ntpu.edu.tw/"),
            WebData(id: "13", title: String(localized: "web_ba_dept"), image: "macwindow.on.rectangle", url: "https://dba.ntpu.edu.tw"),
            WebData(id: "14", title: String(localized: "web_finance_dept"), image: "macwindow.on.rectangle", url: "https://coop.ntpu.edu.tw/"),
            WebData(id: "15", title: String(localized: "web_accounting_dept"), image: "macwindow.on.rectangle", url: "https://www.acc.ntpu.edu.tw/"),
            WebData(id: "16", title: String(localized: "web_statistics_dept"), image: "macwindow.on.rectangle", url: "https://www.stat.ntpu.edu.tw/"),
            WebData(id: "17", title: String(localized: "web_leisure_dept"), image: "macwindow.on.rectangle", url: "https://lsm.ntpu.edu.tw/"),
            WebData(id: "18", title: String(localized: "web_pa_dept"), image: "macwindow.on.rectangle", url: "https://pa.ntpu.edu.tw/"),
            WebData(id: "19", title: String(localized: "web_pf_dept"), image: "macwindow.on.rectangle", url: "https://finc.ntpu.edu.tw/"),
            WebData(id: "20", title: String(localized: "web_realestate_dept"), image: "macwindow.on.rectangle", url: "http://www.rebe.ntpu.edu.tw"),
            WebData(id: "21", title: String(localized: "web_econ_dept"), image: "macwindow.on.rectangle", url: "https://econ.ntpu.edu.tw/"),
            WebData(id: "22", title: String(localized: "web_sociology_dept"), image: "macwindow.on.rectangle", url: "https://sociology.ntpu.edu.tw/"),
            WebData(id: "23", title: String(localized: "web_sw_dept"), image: "macwindow.on.rectangle", url: "https://www.sw.ntpu.edu.tw/"),
            WebData(id: "24", title: String(localized: "web_chinese_dept"), image: "macwindow.on.rectangle", url: "https://www.cl.ntpu.edu.tw/"),
            WebData(id: "25", title: String(localized: "web_foreign_lang_dept"), image: "macwindow.on.rectangle", url: "http://dafl.ntpu.edu.tw/main.php"),
            WebData(id: "26", title: String(localized: "web_history_dept"), image: "macwindow.on.rectangle", url: "https://history.ntpu.edu.tw/"),
            WebData(id: "27", title: String(localized: "web_csie_dept"), image: "macwindow.on.rectangle", url: "https://www.csie.ntpu.edu.tw/"),
            WebData(id: "28", title: String(localized: "web_csie_unofficial"), image: "macwindow.on.rectangle", url: "https://ntpucsie.vercel.app/"),
            WebData(id: "29", title: String(localized: "web_ee_dept"), image: "macwindow.on.rectangle", url: "https://ee.ntpu.edu.tw/"),
            WebData(id: "30", title: String(localized: "web_comm_dept"), image: "macwindow.on.rectangle", url: "https://www.ce.ntpu.edu.tw/"),
            WebData(id: "31", title: String(localized: "web_mis_grad"), image: "macwindow.on.rectangle", url: "https://www.mis.ntpu.edu.tw/"),
            WebData(id: "32", title: String(localized: "web_ib_grad"), image: "macwindow.on.rectangle", url: "https://giib.ntpu.edu.tw/"),
            WebData(id: "33", title: String(localized: "web_urban_grad"), image: "macwindow.on.rectangle", url: "https://urbanplanning.ntpu.edu.tw/"),
            WebData(id: "34", title: String(localized: "web_crim_grad"), image: "macwindow.on.rectangle", url: "https://crm.ntpu.edu.tw/"),
        ]),
        WebsArray(id: 4, title: String(localized: "web_calendar"), webs: []),
        WebsArray(id: 5, title: String(localized: "web_student_union"), webs: [
            WebData(id: "37", title: String(localized: "web_su_linktree"), image: "macwindow", url: "https://linktr.ee/ntpusu"),
            WebData(id: "38", title: String(localized: "web_vote_site"), image: "person.crop.square", url: "https://ntpusu-vote.vercel.app/"),
        ]),
        WebsArray(id: 6, title: String(localized: "web_others"), webs: [
            WebData(id: "39", title: String(localized: "web_clubs"), image: "suit.club", url: "https://www.extracurricular-activities-section.com.tw/"),
            WebData(id: "40", title: String(localized: "web_campus_directory"), image: "phone.bubble", url: "https://sea.cc.ntpu.edu.tw/pls/ld/campus_dir_m.main"),
            WebData(id: "41", title: String(localized: "web_suggestion"), image: "captions.bubble", url: "https://sea.cc.ntpu.edu.tw/pls/ntpu_cof/suggestion_login.html#2"),
            WebData(id: "42", title: String(localized: "web_library_login"), image: "book.closed", url: "https://library.ntpu.edu.tw/masses/showMassesLogin"),
            WebData(id: "43", title: String(localized: "web_leave_system"), image: "figure.mind.and.body", url: "https://cof.ntpu.edu.tw/pls/acad2/leave_sys.html"),
        ]),
    ]
    
    func createData() { loadCalendar(forceRefresh: false) }
    func refreshCalendar() { loadCalendar(forceRefresh: true) }

    private func loadCalendar(forceRefresh: Bool) {
        if !forceRefresh, let cached = Self.cachedCalendar, let date = Self.cacheDate,
           Date().timeIntervalSince(date) < 300 {
            Calendar = cached
            return
        }
        guard !isLoadingCalendar else { return }
        isLoadingCalendar = true
        calendarErrorMessage = nil

        db.collection("calendar").getDocuments(source: .server) { [weak self] snapshot, error in
            guard let self else { return }
            let links = snapshot?.documents.compactMap { doc -> WebData? in
                let fields = doc.data()
                guard let title = fields["title"] as? String, !title.isEmpty,
                      let rawURL = fields["url"] as? String,
                      let url = URL(string: rawURL),
                      url.scheme?.lowercased() == "https", url.host != nil else { return nil }
                let id = (fields["id"] as? String)
                    ?? (fields["id"] as? NSNumber)?.stringValue ?? doc.documentID
                return WebData(id: id, title: title, image: fields["image"] as? String ?? "calendar", url: rawURL)
            }.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending } ?? []

            DispatchQueue.main.async {
                self.isLoadingCalendar = false
                if error != nil || links.isEmpty {
                    // Never leave an endless spinner or an empty calendar section.
                    self.Calendar = Self.cachedCalendar ?? [Self.officialCalendar]
                    self.calendarErrorMessage = "行事曆清單暫時無法更新，可先開啟官方行事曆。"
                } else {
                    var uniqueURLs = Set<String>()
                    let result = (links + [Self.officialCalendar]).filter { uniqueURLs.insert($0.url).inserted }
                    Self.cachedCalendar = result
                    Self.cacheDate = Date()
                    self.Calendar = result
                    self.calendarErrorMessage = nil
                }
            }
        }
    }
}
