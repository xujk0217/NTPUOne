//
//  BackTrafficView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI
import SwiftData
import SafariServices
import FirebaseCore
import FirebaseFirestore
import GoogleMobileAds
import AppTrackingTransparency
import MapKit
import Firebase

struct BackTrafficView: View {
    @ObservedObject var bikeManager = UbikeManager()
    
    @State private var isExpanded = false
    var trafficTitle = "UBike in ntpu"
    
    
    var body: some View {
        NavigationStack {
            VStack {
                if let bikeDatas = bikeManager.bikeDatas {
                        List {
                            Section{
                                Text("升級至 IOS 17.0 以開啟地圖功能")
                            } header: {
                                Text("腳踏車地圖")
                                    .foregroundStyle(Color.black)
                            } footer: {
                                Text("名稱：站名-(腳踏車數/總數)")
                                    .foregroundStyle(Color.black)
                            }
                            Section {
                                DisclosureGroup("Ubike in NTPU", isExpanded: $isExpanded) {
                                    ForEach(bikeDatas.filter { isNTPU(sno: $0.sno) }) { stop in
                                        NavigationLink(destination: noMapBikeView(Bike: stop)) {
                                            HStack {
                                                Text(stop.tot)
                                                    .font(.title.bold())
                                                VStack {
                                                    HStack {
                                                        Text(stop.sna.substring(from: 11))
                                                        Spacer()
                                                    }
                                                    HStack {
                                                        Image(systemName: "bicycle")
                                                        Text(stop.sbi)
                                                        Spacer()
                                                        Image(systemName: "baseball.diamond.bases")
                                                        Text(stop.bemp)
                                                        Spacer()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Ubike in NTPU")
                                        .foregroundStyle(Color.black)
                                    Spacer()
                                    if isExpanded {
                                        NavigationLink(destination: MoreBikeView()) {
                                            Text("more")
                                                .font(.caption)
                                        }
                                    }
                                }
                            } footer: {
                                Text("更新頻率：每5分鐘")
                                    .foregroundStyle(Color.black)
                            }
                            // 廣告標記
                            Section {
                                BannerAdView()
                                        .frame(height: 50) // 橫幅廣告的高度通常是 50
                            } header: {
                                Text("廣告")
                            }
                        }
                        .navigationTitle("Traffic")
                        .toolbarBackground(.hidden, for: .navigationBar)
                } else {
                    VStack {
                        Text("Loading...")
                        ProgressView()
                            .onAppear {
                                bikeManager.fetchData()
                            }
                    }
                }
            }
        }
        .onAppear {
            bikeManager.fetchData()
        }
    }
    func isNTPU(sno: String) -> Bool{
        for i in K.Bike.NTPUBikeNum{
            if i == sno{
                return true
            }
        }
        return false
    }
}

#Preview {
   BackTrafficView()
}
