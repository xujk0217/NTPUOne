//
//  Item.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseFirestoreSwift

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
    private var db = Firestore.firestore()
    
    @Published var Calendar: [WebData]?
    
    @Published var websArray:[WebsArray] = [
        WebsArray(id: 0, title: "主網站", webs: [
            WebData(id: "0", title: "NTPU", image: "graduationcap", url: "https://new.ntpu.edu.tw/"),
        ]),
        WebsArray(id: 1, title: "學生", webs: [
            WebData(id: "1", title: "學生資訊系統", image: "chart.bar.doc.horizontal", url: "https://cof.ntpu.edu.tw/student_new.htm"),
            WebData(id: "2", title: "數位學院 3.0", image: "graduationcap.circle", url: "https://lms3.ntpu.edu.tw/"),
        ]),
        WebsArray(id: 2, title: "課程", webs: [
            WebData(id: "3", title: "課程查詢", image: "magnifyingglass", url: "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.chi_main"),
            WebData(id: "4", title: "課程評價", image: "ellipsis.message.fill", url: "https://no21.ntpu.org/"),
            WebData(id: "5", title: "考古系系網", image: "folder.badge.questionmark", url: "https://past-exam.ntpu.cc"),
        ]),
        WebsArray(id: 3, title: "系網", webs: [
            WebData(id: "6", title: "法律學院", image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/law"),
            WebData(id: "7", title: "商學院", image: "macwindow.on.rectangle", url: "https://www.aacsb.ntpu.edu.tw/"),
            WebData(id: "8", title: "公共事務學院", image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/public-affairs"),
            WebData(id: "9", title: "社會科學學院", image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/social-sciences"),
            WebData(id: "10", title: "人文學院", image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/humanities"),
            WebData(id: "11", title: "電機資訊學院", image: "macwindow.on.rectangle", url: "https://new.ntpu.edu.tw/computer-science"),
            WebData(id: "12", title: "法律系", image: "macwindow.on.rectangle", url: "https://www.law.ntpu.edu.tw/"),
            WebData(id: "13", title: "企管系", image: "macwindow.on.rectangle", url: "https://dba.ntpu.edu.tw"),
            WebData(id: "14", title: "金融系", image: "macwindow.on.rectangle", url: "https://coop.ntpu.edu.tw/"),
            WebData(id: "15", title: "會計系", image: "macwindow.on.rectangle", url: "https://www.acc.ntpu.edu.tw/"),
            WebData(id: "16", title: "統計系", image: "macwindow.on.rectangle", url: "https://www.stat.ntpu.edu.tw/"),
            WebData(id: "17", title: "休運系", image: "macwindow.on.rectangle", url: "https://lsm.ntpu.edu.tw/"),
            WebData(id: "18", title: "公行系", image: "macwindow.on.rectangle", url: "https://pa.ntpu.edu.tw/"),
            WebData(id: "19", title: "財政系", image: "macwindow.on.rectangle", url: "https://finc.ntpu.edu.tw/"),
            WebData(id: "20", title: "不動產系", image: "macwindow.on.rectangle", url: "http://www.rebe.ntpu.edu.tw"),
            WebData(id: "21", title: "經濟系", image: "macwindow.on.rectangle", url: "https://econ.ntpu.edu.tw/"),
            WebData(id: "22", title: "社會系", image: "macwindow.on.rectangle", url: "https://sociology.ntpu.edu.tw/"),
            WebData(id: "23", title: "社工系", image: "macwindow.on.rectangle", url: "https://www.sw.ntpu.edu.tw/"),
            WebData(id: "24", title: "中文系", image: "macwindow.on.rectangle", url: "https://www.cl.ntpu.edu.tw/"),
            WebData(id: "25", title: "應外系", image: "macwindow.on.rectangle", url: "http://dafl.ntpu.edu.tw/main.php"),
            WebData(id: "26", title: "歷史系", image: "macwindow.on.rectangle", url: "https://history.ntpu.edu.tw/"),
            WebData(id: "27", title: "資工系", image: "macwindow.on.rectangle", url: "https://www.csie.ntpu.edu.tw/"),
            WebData(id: "28", title: "資工系（偽）", image: "macwindow.on.rectangle", url: "https://ntpucsie.vercel.app/"),
            WebData(id: "29", title: "電機系", image: "macwindow.on.rectangle", url: "https://ee.ntpu.edu.tw/"),
            WebData(id: "30", title: "通訊系", image: "macwindow.on.rectangle", url: "https://www.ce.ntpu.edu.tw/"),
            WebData(id: "31", title: "資管研", image: "macwindow.on.rectangle", url: "https://www.mis.ntpu.edu.tw/"),
            WebData(id: "32", title: "國企研", image: "macwindow.on.rectangle", url: "https://giib.ntpu.edu.tw/"),
            WebData(id: "33", title: "都計研", image: "macwindow.on.rectangle", url: "https://urbanplanning.ntpu.edu.tw/"),
            WebData(id: "34", title: "犯罪研", image: "macwindow.on.rectangle", url: "https://crm.ntpu.edu.tw/"),
        ]),
        WebsArray(id: 4, title: "行事曆", webs: []),
        WebsArray(id: 5, title: "學生會", webs: [
            WebData(id: "37", title: "學生會 linktree", image: "macwindow", url: "https://linktr.ee/ntpusu"),
            WebData(id: "38", title: "投票網站", image: "person.crop.square.filled.and.at.rectangle", url: "https://ntpusu-vote.vercel.app/"),
        ]),
        WebsArray(id: 6, title: "其他", webs: [
            WebData(id: "39", title: "社團", image: "suit.club.fill", url: "https://www.extracurricular-activities-section.com.tw/"),
            WebData(id: "40", title: "校園聯絡簿", image: "phone.bubble", url: "https://sea.cc.ntpu.edu.tw/pls/ld/campus_dir_m.main"),
            WebData(id: "41", title: "校務建言", image: "captions.bubble.fill", url: "https://sea.cc.ntpu.edu.tw/pls/ntpu_cof/suggestion_login.html#2"),
            WebData(id: "42", title: "請假系統", image: "figure.mind.and.body", url: "https://cof.ntpu.edu.tw/pls/acad2/leave_sys.html"),
        ]),
    ]
    
    func createData(){
        var collectName = "calendar"

        db.collection(collectName)
            .order(by: "id")
            .addSnapshotListener { querySnapshot, error in
                if let e = error {
                    print("There is an issue: \(e)")
                } else {
                    if let snapshotDocuments = querySnapshot?.documents {
                        print("success get calender")
                        var newCal = [WebData]()
                        for doc in snapshotDocuments {
                            do {
                                var cald = try doc.data(as: WebData.self)
                                newCal.append(cald)
                            } catch {
                                print("Error decoding document: \(error)")
                            }
                        }
                        DispatchQueue.main.async {
                            self.Calendar = newCal
                        }
                    }
                }
            }
    }
}
