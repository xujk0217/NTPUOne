//
//  SwiftUIView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import FirebaseFirestore

struct BreakfastView: View {
    @StateObject var fManager = FManager()
    @EnvironmentObject var adFree: AdFreeService
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    var body: some View {
        if let Food = fManager.Food {
            NavigationStack {
                List {
                    Section{
                        ForEach(fManager.Food!) { store in
                            if #available(iOS 17.0, *) {
                                NavigationLink(destination: dietView(store: store, currCollectName: K.FStoreF.collectionNameB)){
                                    HStack {
                                        HStack {
                                            Text("\(Int(store.starNum))")
                                                .font(.title.bold())
                                            Image(systemName: "star.fill")
                                        }
                                        Divider()
                                        VStack(alignment: .leading) {
                                            HStack {
                                                Text(store.store)
                                                    .font(.headline)
                                                Spacer()
                                            }
                                            HStack(alignment: .top) {
                                                Image(systemName: "house")
                                                Text(": \(store.address)")
                                                Spacer()
                                            }
                                            if !store.check{
                                                Text("未確認資料完整性")
                                                    .foregroundStyle(Color.red)
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Fallback on earlier versions
                                NavigationLink(destination: noMapDietView(store: store, currCollectName: K.FStoreF.collectionNameB)){
                                    HStack {
                                        HStack {
                                            Text("\(Int(store.starNum))")
                                                .font(.title.bold())
                                            Image(systemName: "star.fill")
                                        }
                                        Divider()
                                        VStack(alignment: .leading) {
                                            HStack {
                                                Text(store.store)
                                                    .font(.headline)
                                                Spacer()
                                            }
                                            HStack(alignment: .top) {
                                                Image(systemName: "house")
                                                Text(": \(store.address)")
                                                Spacer()
                                            }
                                            if !store.check{
                                                Text("未確認資料完整性")
                                                    .foregroundStyle(Color.red)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("\(Image(systemName: "star.fill")) 是人氣數")
                    }
//                    // 廣告標記
//                    Section {
//                        NativeAdBoxView(
//                            style: .compact(media: 120),
//                            height: $adHeight
//                        )
//                        .frame(height: adHeight)
//                        .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
//                        .listRowSeparator(.hidden)
//                        .listRowBackground(Color.white)
//                        .padding(.horizontal, 8)
//                    } header: {
//                        Text("廣告")
//                    }
                }.scrollContentBackground(.hidden)
                    .background(Color.gray.opacity(0.1))
                .navigationTitle("Breakfast")
                .toolbar{
                    ToolbarItem(placement: .primaryAction, content: {
                        NavigationLink {
                            AddStoreView(currCollectName: K.FStoreF.collectionNameB)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.blue)
                        }
                    })
                }
                if !adFree.isAdFree{
                    // 廣告標記
                    Section {
                        BannerAdView()
                            .frame(height: 50)
                    }
                }
                }.onAppear {
                fManager.loadF(whichDiet: "B")
            }
        }else{
            Text("Loading...")
                .onAppear {
                    fManager.loadF(whichDiet: "B")
                }
            ProgressView()
        }
    }
}

#Preview {
    BreakfastView()
}

