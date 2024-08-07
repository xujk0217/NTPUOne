//
//  MoreBikeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI

struct MoreBikeView: View {
    
    @ObservedObject var bikeManager = UbikeManager()
    
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
                                                        Text(stop.tot)
                                                            .font(.title.bold())
                                                        VStack{
                                                            HStack {
                                                                Text(stop.sna.substring(from: 11))
                                                                Spacer()
                                                            }
                                                            HStack{
                                                                Image(systemName: "bicycle")
                                                                Text(stop.sbi)
                                                                Spacer()
                                                                Image(systemName: "baseball.diamond.bases")
                                                                Text(stop.bemp)
                                                                Spacer()
                                                            }
                                                        }
                                                    }
                                                }.listRowBackground(Color.white.opacity(0.7))
                                            } else {
                                                // Fallback on earlier versions
                                                NavigationLink(destination: noMapBikeView(Bike: stop)){
                                                    HStack{
                                                        Text(stop.tot)
                                                            .font(.title.bold())
                                                        VStack{
                                                            HStack {
                                                                Text(stop.sna.substring(from: 11))
                                                                Spacer()
                                                            }
                                                            HStack{
                                                                Image(systemName: "bicycle")
                                                                Text(stop.sbi)
                                                                Spacer()
                                                                Image(systemName: "baseball.diamond.bases")
                                                                Text(stop.bemp)
                                                                Spacer()
                                                            }
                                                        }
                                                    }
                                                }.listRowBackground(Color.white.opacity(0.7))
                                            }
                                        }
                                    }
                                } header: {
                                    HStack {
                                        Text("Ubike")
                                            .foregroundStyle(Color.black)
                                        Spacer()
                                    }
                                }
                            }.scrollContentBackground(.hidden)
//                            .background(.linearGradient(colors: [.white, .green], startPoint: .bottomLeading, endPoint: .topTrailing))
                                .background(Color.gray.opacity(0.1))
                        }
                        .navigationTitle("More ubike")
                        .onAppear {
                            bikeManager.fetchData()
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
