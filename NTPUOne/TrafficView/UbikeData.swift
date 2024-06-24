//
//  UbikeData.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation

struct UBResults: Decodable, Identifiable{
    var id: String {
        return sno
    }
    
    let sno: String
    
    let sna: String //name
    let snaen: String  //english name
    
    let lat: String
    let lng: String
    
    let tot: String //total space
    let sbi: String  //bikes
    let bemp: String  //Docks
}
