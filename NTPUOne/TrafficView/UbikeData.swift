//
//  UbikeData.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation
import CoreLocation

struct UBResults: Decodable, Identifiable{
    var id: String {
        return sno
    }
    
    let sno: String
    
    let sna: String //name
    let snaen: String  //english name
    
    let lat: String
    let lng: String
    
    let tot_quantity: String  //total space
    let sbi_quantity: String  //bikes
    let bemp: String  //Docks
}


extension UBResults {
    /// Campus reference point; nearby means a 2 km straight-line radius.
    static let campusCenter = CLLocation(latitude: 24.944, longitude: 121.371)
    static let nearbyRadius: CLLocationDistance = 2_000

    var displayName: String {
        sna.replacingOccurrences(of: "YouBike2.0_", with: "")
    }

    var distanceFromNTPU: CLLocationDistance {
        guard let latitude = Double(lat), let longitude = Double(lng),
              (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            return .infinity
        }
        return CLLocation(latitude: latitude, longitude: longitude).distance(from: Self.campusCenter)
    }

    var isNearNTPU: Bool { distanceFromNTPU <= Self.nearbyRadius }
}
