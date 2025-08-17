//
//  TrafficView.swift
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

@available(iOS 17.0, *)
struct TrafficView: View {
    @ObservedObject var bikeManager = UbikeManager()
    
    @State private var isExpanded = false
    var trafficTitle = "UBike in ntpu"
    
    @State var position: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 24.942406, longitude: 121.368198), distance: 1500)
    )
    @State var selectionResult: MKMapItem?
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                if let bikeDatas = bikeManager.bikeDatas {
                        List {
                            Section {
                                VStack {
                                    if let bikeDatas = bikeManager.bikeDatas {
                                        Map(position: $position, selection: $selectionResult) {
                                            ForEach(bikeDatas) { stop in
                                                let title = stop.sna.substring(from: 11)
                                                let coordinate = CLLocationCoordinate2D(latitude: Double(stop.lat)!, longitude: Double(stop.lng)!)
                                                Marker("\(title)-(\(stop.sbi)/\(stop.tot))", systemImage: "bicycle", coordinate: coordinate)
                                            }
                                        }
                                        .mapStyle(.standard(elevation: .realistic))
                                    }
                                }
                                .frame(height: 300)
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
                                        NavigationLink(destination: bikeView(Bike: stop)) {
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
                                NativeAdBoxView(
                                    style: .compact(media: 120),
                                    height: $adHeight
                                )
                                .frame(height: adHeight)
                                .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.white)
                                .padding(.horizontal, 8)
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
    if #available(iOS 17.0, *) {
        TrafficView()
    } else {
        BackTrafficView()
    }
}
