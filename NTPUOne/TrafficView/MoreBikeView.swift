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
                                // Native 廣告 Section
                                if !adFree.isAdFree {
                                    Section {
                                        NativeAdSectionView(style: .compact)
                                            .frame(height: 140)
                                    }
                                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                                }
                            }.scrollContentBackground(.hidden)
                                .background(Color.gray.opacity(0.1))
                        }
                        .navigationTitle("More ubike")
                        .onAppear {
                            bikeManager.fetchData()
                        }
                    }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
