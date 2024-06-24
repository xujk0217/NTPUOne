//
//  Item.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation
import SwiftData

struct WebsArray: Identifiable{
    let id: Int
    let title: String
    let webs: [WebData]
}

struct WebData: Identifiable{
    let id: Int
    let title: String
    let url: String
}

class WebManager: ObservableObject{
    
    @Published var websArray:[WebsArray] = [
        //first array
        WebsArray(id: 0, title: "主網站", webs: [
            WebData(id: 0, title: "NTPU", url: "https://new.ntpu.edu.tw/"),
        ]),
        //second array
        WebsArray(id: 1, title: "學生", webs: [
            WebData(id: 0, title: "學生資訊系統", url: "https://cof.ntpu.edu.tw/student_new.htm"),
            WebData(id: 1, title: "數位學院 3.0", url: "https://lms3.ntpu.edu.tw/"),
        ]),
        WebsArray(id: 2, title: "課程", webs: [
            WebData(id: 0, title: "課程查詢", url: "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.chi_main"),
            WebData(id: 2, title: "課程評價", url: "https://no21.ntpu.org/"),
            WebData(id: 3, title: "考古系系網", url: "https://kevin16021777.wixsite.com/my-site-4"),  //待更改
        ]),
        WebsArray(id: 3, title: "系網", webs: [
            
        ]),
        WebsArray(id: 4, title: "行事曆", webs: [
            WebData(id: 0, title: "113-1 行事曆", url: "https://cms-carrier.ntpu.edu.tw/uploads/113_1_4333c90118.pdf"),
            WebData(id: 0, title: "113-2 行事曆", url: "https://cms-carrier.ntpu.edu.tw/uploads/113_2_763a5c8df0.pdf")
        ]),
        WebsArray(id: 5, title: "學生會", webs: [
            WebData(id: 0, title: "學生會網站？", url: "https://linktr.ee/ntpusu"),
            WebData(id: 1, title: "投票網站", url: "https://ntpusu-vote.vercel.app/"),
        ]),
        WebsArray(id: 6, title: "其他", webs: [
            WebData(id: 0, title: "社團", url: "https://www.extracurricular-activities-section.com.tw/"),
            WebData(id: 1, title: "校務建言", url: "https://sea.cc.ntpu.edu.tw/pls/ntpu_cof/suggestion_login.html#2"),
            WebData(id: 2, title: "請假系統", url: "https://cof.ntpu.edu.tw/pls/acad2/leave_sys.html")
        ]),
    ]
    
    func createData(){
    }
    
}
