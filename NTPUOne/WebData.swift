//
//  Item.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation
import SwiftData

struct WebData: Identifiable{
    var id: Int
    let title: String
    let url: String
}

class WebManager: ObservableObject{
    
    @Published var webDatas = [WebData]()
    
    func createData(){
        webDatas.append(WebData(id: 1, title: "NTPU", url: K.Web.NTPUurl))
    }
    
}
