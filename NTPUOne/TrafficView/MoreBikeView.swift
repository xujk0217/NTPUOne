//
//  MoreBikeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI

struct MoreBikeView: View {
    
    @StateObject var bikeManager = UbikeManager()
    @EnvironmentObject var adFree: AdFreeService
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    var body: some View {
        VStack {
            if let bikeDatas = bikeManager.bikeDatas {
                NavigationStack{
                        VStack {
                            List {
                                Section {
                                    ForEach(bikeManager.bikeDatas!) { stop in
                                        if !(isNTPU(sno: stop.sno)){
                                            if #available(iOS 17.0, *) {
                                                NavigationLink(destination: bikeView(Bike: stop)){
                                                    HStack{
                                                        Text(stop.tot_quantity)
                                                            .font(.title.bold())
                                                        VStack{
                                                            HStack {
                                                                Text(stop.sna.substring(from: 11))
                                                                Spacer()
                                                            }
                                                            HStack{
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
                                            } else {
                                                // Fallback on earlier versions
                                                NavigationLink(destination: noMapBikeView(Bike: stop)){
                                                    HStack{
                                                        Text(stop.tot_quantity)
                                                            .font(.title.bold())
                                                        VStack{
                                                            HStack {
                                                                Text(stop.sna.substring(from: 11))
                                                                Spacer()
                                                            }
                                                            HStack{
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
                                    }
                                } header: {
                                    HStack {
                                        Text("Ubike")
                                        Spacer()
                                    }
                                }
//                                // 廣告標記
//                                Section {
//                                    NativeAdBoxView(
//                                        style: .compact(media: 120),
//                                        height: $adHeight
//                                    )
//                                    .frame(height: adHeight)
//                                    .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
//                                    .listRowSeparator(.hidden)
//                                    .listRowBackground(Color.white)
//                                    .padding(.horizontal, 8)
//                                } header: {
//                                    Text("廣告")
//                                }
                            }.scrollContentBackground(.hidden)
//                            .background(.linearGradient(colors: [.white, .green], startPoint: .bottomLeading, endPoint: .topTrailing))
                                .background(Color.gray.opacity(0.1))
                        }
                        .navigationTitle("More ubike")
                        .onAppear {
                            bikeManager.fetchData()
                        }
                    if !adFree.isAdFree{
                        // 廣告標記
                        Section {
                            BannerAdView()
                                .frame(height: 50)
                        }
                    }
                    }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }else{
                Text("Loading...")
                    .onAppear {
                        bikeManager.fetchData()
                    }
                ProgressView()
            }
        }.onAppear {
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
    MoreBikeView()
}
