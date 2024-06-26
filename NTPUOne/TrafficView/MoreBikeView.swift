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
            NavigationStack{
                VStack {
                    List {
                        Section {
                            ForEach(bikeManager.bikeDatas) { stop in
                                if !(isNTPU(sno: stop.sno)){
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
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text("Ubike")
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("More ubike")
            }.onAppear(perform: {
                self.bikeManager.fetchData()
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }.edgesIgnoringSafeArea(.bottom)
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
