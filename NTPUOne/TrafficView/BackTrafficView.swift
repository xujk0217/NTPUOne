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
    @StateObject private var bikeManager = UbikeManager()
    @EnvironmentObject var adFree: AdFreeService
    
    @State private var isExpanded = false
    var trafficTitle = "UBike in ntpu"
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    
    var body: some View {
        NavigationStack {
            VStack {
                if let bikeDatas = bikeManager.bikeDatas {
                        List {
                            BikeStatusView(manager: bikeManager)
                            Section{
                                Text(String(localized: "upgrade_ios_for_map"))
                            } header: {
                                Text(String(localized: "bike_map"))
                            } footer: {
                                Text(String(localized: "bike_station_format"))
                            }
                            Section {
                                DisclosureGroup("Ubike in NTPU", isExpanded: $isExpanded) {
                                    ForEach(bikeDatas.filter { isNTPU(sno: $0.sno) }) { stop in
                                        NavigationLink(destination: noMapBikeView(Bike: stop)) {
                                            HStack {
                                                Text(stop.tot_quantity)
                                                    .font(.title.bold())
                                                VStack {
                                                    HStack {
                                                        Text(stop.displayName)
                                                        Spacer()
                                                    }
                                                    HStack {
                                                        Image(systemName: "bicycle")
                                                        Text(stop.sbi_quantity)
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
                                    Spacer()
                                    if isExpanded {
                                        NavigationLink(destination: MoreBikeView()) {
                                            Text("more")
                                                .font(.caption)
                                        }
                                    }
                                }
                            } footer: {
                                Text(String(localized: "update_every_5_min"))
                            }
                        }
                        .refreshable { await bikeManager.refresh() }
                        .navigationTitle("Traffic")
                        .toolbarBackground(.hidden, for: .navigationBar)
                    if !adFree.isAdFree{
                        // Native 廣告
                        Section {
                            NativeAdSectionView(style: .compact)
                                .frame(height: 140)
                        }
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                } else {
                    VStack {
                        if bikeManager.errorMessage != nil {
                            BikeStatusView(manager: bikeManager)
                        } else {
                            ProgressView(String(localized: "loading"))
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
